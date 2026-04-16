const { createServer } = require("http");
const { Server } = require("socket.io");
const Client = require("socket.io-client");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const { initializeSocket } = require("../services/socketService");

// Mocks
jest.mock("../models/UserAuth");
jest.mock("../models/UserProfile");
jest.mock("../models/Group");
jest.mock("../models/CallLog");
jest.mock("../utils/logger"); // Silence logs
jest.mock("../utils/notificationHandler");

const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const CallLog = require("../models/CallLog");

describe("Socket.io Integration Tests", () => {
  let io, server, clientSocketA, clientSocketB;
  let tokenA, tokenB;
  const PORT = 5003; // Changed port to avoid conflicts
  const TEST_SECRET = "test_secret_key_123";

  // Test Data
  const userA = {
    _id: new mongoose.Types.ObjectId().toString(),
    name: "Alice",
  };
  const userB = { _id: new mongoose.Types.ObjectId().toString(), name: "Bob" };

  beforeAll((done) => {
    process.env.JWT_SECRET = TEST_SECRET;
    process.env.USE_REDIS = "false";

    tokenA = jwt.sign({ _id: userA._id }, TEST_SECRET);
    tokenB = jwt.sign({ _id: userB._id }, TEST_SECRET);

    server = createServer();
    initializeSocket(server).then((instance) => {
      io = instance;
      server.listen(PORT, () => {
        done();
      });
    });
  });

  afterAll((done) => {
    io.close();
    server.close(done);
  });

  // ✅ CRITICAL FIX: Reset and Setup Mocks before EVERY test
  beforeEach(() => {
    jest.clearAllMocks();

    // 1. Mock UserAuth.findByIdAndUpdate to return a Promise (fix for .catch error)
    UserAuth.findByIdAndUpdate.mockResolvedValue({});

    // 2. Mock UserProfile.findOne with chaining (.select)
    UserProfile.findOne.mockReturnValue({
      select: jest.fn().mockResolvedValue({
        fullName: "Test User",
        profilePicture: "pic.jpg",
      }),
    });

    // 3. Mock CallLog functions
    CallLog.create.mockImplementation((data) =>
      Promise.resolve({
        ...data,
        _id: new mongoose.Types.ObjectId().toString(),
      }),
    );
    CallLog.findById.mockResolvedValue({ status: "ringing" });
    CallLog.findByIdAndUpdate.mockResolvedValue({});
    CallLog.findOne.mockResolvedValue(null); // Not busy
  });

  afterEach(() => {
    if (clientSocketA && clientSocketA.connected) clientSocketA.disconnect();
    if (clientSocketB && clientSocketB.connected) clientSocketB.disconnect();
  });

  const connectClient = (token) => {
    return new Promise((resolve, reject) => {
      const client = new Client(`http://localhost:${PORT}`, {
        auth: { token },
        transports: ["websocket"],
        "force new connection": true,
      });
      client.on("connect", () => resolve(client));
      client.on("connect_error", (err) => reject(err));
    });
  };

  test("should authenticate and connect successfully", async () => {
    clientSocketA = await connectClient(tokenA);
    expect(clientSocketA.connected).toBe(true);
  });

  test("should broadcast user_status_update when user comes online", (done) => {
    connectClient(tokenB).then((socketB) => {
      clientSocketB = socketB;

      socketB.on("user_status_update", (data) => {
        try {
          if (data.userId === userA._id && data.isOnline === true) {
            done();
          }
        } catch (error) {
          done(error);
        }
      });

      connectClient(tokenA).then((sock) => {
        clientSocketA = sock;
      });
    });
  }, 10000);

  describe("Call Signaling Flow", () => {
    beforeEach(async () => {
      clientSocketA = await connectClient(tokenA);
      clientSocketB = await connectClient(tokenB);
    });

    test("User A calls User B -> User B receives 'call_made'", (done) => {
      const callPayload = {
        userToCall: userB._id,
        offer: { sdp: "dummy_sdp", type: "offer" },
      };

      clientSocketB.on("call_made", (data) => {
        try {
          expect(data.callerId).toBe(userA._id);
          expect(data.offer).toEqual(callPayload.offer);
          expect(data.callLogId).toBeDefined();
          done();
        } catch (error) {
          done(error);
        }
      });

      clientSocketA.emit("call_user", callPayload);
    });

    test("User B answers -> User A receives 'answer_made'", (done) => {
      const answerPayload = {
        to: userA._id,
        answer: { sdp: "answer_sdp", type: "answer" },
        callLogId: "mock_log_id",
      };

      clientSocketA.on("answer_made", (data) => {
        try {
          expect(data.answer).toEqual(answerPayload.answer);
          done();
        } catch (e) {
          done(e);
        }
      });

      clientSocketB.emit("make_answer", answerPayload);
    });

    test("ICE Candidates are exchanged", (done) => {
      const icePayload = { to: userB._id, candidate: "candidate:1234" };

      clientSocketB.on("ice_candidate_received", (data) => {
        try {
          expect(data.candidate).toBe(icePayload.candidate);
          done();
        } catch (e) {
          done(e);
        }
      });

      clientSocketA.emit("ice_candidate", icePayload);
    });
  });
});

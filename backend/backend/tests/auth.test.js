const { generateAlumniId } = require("../utils/idGenerator");
const Counter = require("../models/Counter");

// ✅ Mock the Mongoose Counter model
jest.mock("../models/Counter");

describe("Alumni ID Generation Logic", () => {
  beforeEach(() => {
    // Clear mocks before each test
    jest.clearAllMocks();
  });

  it("should generate a correctly formatted ID for the current year", async () => {
    // Mock the DB response
    Counter.findByIdAndUpdate.mockResolvedValue({ seq: 42 });

    const id = await generateAlumniId(2025);

    expect(id).toBe("ASC/2025/0042");
    expect(Counter.findByIdAndUpdate).toHaveBeenCalledWith(
      "alumni_id_2025",
      { $inc: { seq: 1 } },
      expect.any(Object)
    );
  });

  it("should increment sequence numbers correctly (simulation)", async () => {
    // Simulate first call returning 10, second returning 11
    Counter.findByIdAndUpdate
      .mockResolvedValueOnce({ seq: 10 })
      .mockResolvedValueOnce({ seq: 11 });

    const id1 = await generateAlumniId(2025);
    const id2 = await generateAlumniId(2025);

    expect(id1).toBe("ASC/2025/0010");
    expect(id2).toBe("ASC/2025/0011");
  });

  it("should fallback if database fails repeatedly", async () => {
    // Mock DB error
    Counter.findByIdAndUpdate.mockRejectedValue(new Error("DB Down"));

    // Suppress console.error for this test case to keep output clean
    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const id = await generateAlumniId(2025);

    // Should return the Fallback ID format
    expect(id).toMatch(/^ASC\/2025\/FALLBACK-[0-9A-F]+$/);

    // Ensure it tried 3 times before giving up
    expect(Counter.findByIdAndUpdate).toHaveBeenCalledTimes(3);

    consoleSpy.mockRestore();
  });
});

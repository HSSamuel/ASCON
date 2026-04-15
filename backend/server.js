const path = require("path");
const express = require("express");
const mongoose = require("mongoose");
const dotenv = require("dotenv");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const compression = require("compression");
const swaggerJsDoc = require("swagger-jsdoc");
const swaggerUi = require("swagger-ui-express");
const http = require("http");

const UserAuth = require("./models/UserAuth");
const CallLog = require("./models/CallLog"); // ✅ NEW: Import CallLog
const validateEnv = require("./utils/validateEnv");
const errorHandler = require("./utils/errorMiddleware");
const logger = require("./utils/logger");

const { initializeSocket, closeSocket } = require("./services/socketService");

// 1. Initialize the App
const app = express();
const server = http.createServer(app);

app.set("trust proxy", 1);
dotenv.config();
validateEnv();

// ==========================================
// 🛡️ MIDDLEWARE
// ==========================================
app.use(compression());
app.use(helmet());

// ✅ UPDATED: Morgan Logger with a 'skip' filter for noisy browser requests
app.use(
  morgan("combined", {
    skip: (req, res) => {
      // Ignore favicon and Chrome devtools background requests
      const noisyRoutes = ['/favicon.ico', '/.well-known/'];
      return noisyRoutes.some(route => req.url.includes(route));
    },
    stream: { write: (message) => logger.info(message.trim()) },
  }),
);

// ==========================================
// 🛡️ RATE LIMITING
// ==========================================
// 1. Global API Rate Limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 150, // Limit each IP to 150 requests per window
  message: {
    error: "Too many requests from this IP, please try again after 15 minutes.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// 2. Stricter Limiter for Authentication Routes
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // Limit each IP to 20 auth attempts per window
  message: {
    error: "Too many authentication attempts, please try again later.",
  },
});

// ==========================================
// 📖 API DOCUMENTATION
// ==========================================
const swaggerOptions = {
  swaggerDefinition: {
    openapi: "3.0.0",
    info: {
      title: "ASCON Alumni API",
      version: "2.0.0",
      description: "Official API documentation for the ASCON Alumni Platform",
    },
    servers: [
      {
        url:
          process.env.NODE_ENV === "production"
            ? "https://ascon.onrender.com"
            : `http://localhost:${process.env.PORT || 5000}`,
      },
    ],
  },
  apis: [path.join(__dirname, "routes", "*.js")],
};
const swaggerDocs = swaggerJsDoc(swaggerOptions);
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocs));

// ==========================================
// 2. CONFIGURATION & ROUTES
// ==========================================

const getOrigins = () => {
  const envOrigins = process.env.ALLOWED_ORIGINS;
  if (envOrigins) {
    return envOrigins.split(",").map((origin) => origin.trim());
  }
  if (process.env.NODE_ENV !== "production") {
    return ["http://localhost:3000", "http://localhost:5000"];
  }
  return [];
};

const allowedOrigins = getOrigins();

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin) return callback(null, true);

      if (allowedOrigins.indexOf(origin) !== -1) {
        return callback(null, true);
      } else {
        logger.warn(`🚫 Blocked CORS request from: ${origin}`);
        return callback(new Error("Not allowed by CORS"));
      }
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth-token"],
    credentials: true,
  }),
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const ioPromise = initializeSocket(server);

app.use(async (req, res, next) => {
  req.io = await ioPromise;
  next();
});

// ==========================================
// 3. ROUTES
// ==========================================
app.use("/api/", apiLimiter);
app.use("/api/auth", authLimiter);
app.use("/api/auth", require("./routes/auth"));
app.use("/api/directory", require("./routes/directory"));
app.use("/api/admin", require("./routes/admin"));
app.use("/api/profile", require("./routes/profile"));
app.use("/api/events", require("./routes/events"));
app.use("/api/programme-interest", require("./routes/programmeInterest"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/event-registration", require("./routes/eventRegistration"));
app.use("/api/chat", require("./routes/chat"));
app.use("/api/documents", require("./routes/documents"));
app.use("/api/mentorship", require("./routes/mentorship"));
app.use("/api/updates", require("./routes/updates"));
app.use("/api/polls", require("./routes/polls"));
app.use("/api/groups", require("./routes/groups"));
app.use("/api/calls", require("./routes/callLogs"));
app.use("/api/agora", require("./routes/agora"));

app.use(errorHandler);

// ==========================================
// 4. SERVER START
// ==========================================
const PORT = process.env.PORT || 5000;

logger.info("⏳ Attempting to connect to MongoDB...");

mongoose
  .connect(process.env.DB_CONNECT)
  .then(async () => {
    logger.info("✅ Connected to MongoDB Successfully!");

    try {
      // 2. ✅ NEW: Reset Stuck Calls
      const stuckCalls = await CallLog.updateMany(
        { status: { $in: ["ringing", "ongoing", "initiated"] } },
        { $set: { status: "ended", endTime: new Date() } },
      );
      logger.info(`📞 Cleaned up ${stuckCalls.modifiedCount} stuck calls.`);
    } catch (err) {
      logger.error("⚠️ Failed to run startup cleanup:", err);
    }

    app.get("/", (req, res) => {
      res.status(200).send("ASCON Server is Awake! 🚀");
    });

    server.listen(PORT, () => {
      logger.info(`🚀 Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    logger.error("❌ Database Connection Failed:", err);
  });

// ==========================================
// 5. GRACEFUL SHUTDOWN HANDLING
// ==========================================
const gracefulShutdown = async (signal) => {
  logger.info(`\n⚠️ ${signal} received. Initiating graceful shutdown...`);

  // 1. Stop accepting new HTTP requests
  server.close(async () => {
    logger.info("🛑 HTTP server stopped accepting new requests.");

    try {
      // 2. Close Socket.io & Redis connections
      if (typeof closeSocket === "function") {
        await closeSocket();
      }

      // 3. Close MongoDB connection cleanly
      if (mongoose.connection.readyState === 1) {
        await mongoose.connection.close(false);
        logger.info("🛑 MongoDB connection cleanly closed.");
      }

      logger.info("✅ Graceful shutdown completed. Exiting process.");
      process.exit(0);
    } catch (error) {
      logger.error("❌ Error occurred during graceful shutdown:", error);
      process.exit(1);
    }
  });

  // Force shutdown if it takes longer than 10 seconds
  setTimeout(() => {
    logger.error("⏳ Graceful shutdown timed out. Forcing exit.");
    process.exit(1);
  }, 10000);
};

// Listen for termination signals from OS / Hosting platform (Render/Heroku/Docker)
process.on("SIGINT", () => gracefulShutdown("SIGINT")); // Ctrl+C in terminal
process.on("SIGTERM", () => gracefulShutdown("SIGTERM")); // Docker/Server termination

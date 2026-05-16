const logger = require("./logger");

const validateEnv = () => {
  const requiredEnv = [
    "PORT",
    "DB_CONNECT",
    "JWT_SECRET",
    "REFRESH_SECRET",
    "GOOGLE_CLIENT_ID",
    "NODE_ENV",
    "FIREBASE_SERVICE_ACCOUNT",
    "CLIENT_URL",
    "FIREBASE_VAPID_KEY",
    "AGORA_APP_ID",
    "AGORA_APP_CERTIFICATE",
    "MAILERSEND_API_KEY",
    "EMAIL_FROM"
  ];

  const missing = requiredEnv.filter((env) => !process.env[env]);

  if (missing.length > 0) {
    logger.error(
      `❌ CRITICAL ERROR: Missing environment variables: ${missing.join(", ")}`,
    );
    process.exit(1);
  }

  // ✅ Redis Validation
  if (process.env.USE_REDIS === "true" && !process.env.REDIS_URL) {
    logger.warn(
      "⚠️  WARNING: Redis is enabled (USE_REDIS=true) but REDIS_URL is missing. Defaulting to localhost.",
    );
  }

  logger.info(`🌍 Mode: ${process.env.NODE_ENV || "development"}`);
  logger.info("✅ Environment Variables Validated");
};

module.exports = validateEnv;

const jwt = require("jsonwebtoken");

module.exports = function (req, res, next) {
  const token =
    req.header("auth-token") || req.header("Authorization")?.split(" ")[1];

  // 1. Missing Token -> 401 (Access Denied)
  if (!token) return res.status(401).json({ message: "Access Denied" });

  try {
    const verified = jwt.verify(token, process.env.JWT_SECRET);
    req.user = verified;
    next();
  } catch (err) {
    // ✅ FIX: Send 401 (Unauthorized) instead of 400
    // This tells the mobile app "Force Logout Now"
    res.status(401).json({ message: "Invalid or Expired Token" });
  }
};

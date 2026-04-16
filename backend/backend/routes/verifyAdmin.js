module.exports = function (req, res, next) {
  // 1. Check if the user exists in the request (added by verifyToken)
  // 2. Check if the isAdmin flag is true
  if (!req.user || !req.user.isAdmin) {
    return res.status(403).json({ message: "Access Denied. Admins only." });
  }
  next(); // Access granted
};

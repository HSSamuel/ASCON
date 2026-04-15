// ✅ Simple wrapper to catch async errors and pass them to errorMiddleware
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;

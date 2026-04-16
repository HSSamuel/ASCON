const express = require("express");
const router = express.Router();
const verify = require("./verifyToken"); // Ensures only logged-in users can get tokens
const { generateToken } = require("../controllers/agoraController");

// POST /api/agora/token
router.post("/token", verify, generateToken);

module.exports = router;

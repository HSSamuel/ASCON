const { RtcTokenBuilder, RtcRole } = require("agora-access-token");

exports.generateToken = (req, res) => {
  // We expect the Flutter app to send a unique channelName (like "call_123_456")
  const { channelName, uid } = req.body;

  if (!channelName) {
    return res.status(400).json({ error: "channelName is required" });
  }

  // Get keys from your .env file
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  // Set role to Publisher (they can send and receive audio)
  const role = RtcRole.PUBLISHER;

  // ⏱️ COST SAFEGUARD: Set Max Call Duration to 45 minutes (2700 seconds)
  const expirationTimeInSeconds = 2700;
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  try {
    // Build the secure token
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid || 0, // 0 tells Agora to assign a random UID automatically
      role,
      privilegeExpiredTs,
    );

    // Send the token back to the Flutter app!
    res.json({ token, channelName, maxDurationSecs: expirationTimeInSeconds });
  } catch (error) {
    console.error("Agora Token Error:", error);
    res.status(500).json({ error: "Failed to generate token" });
  }
};

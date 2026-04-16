const mongoose = require("mongoose");
const UserAuth = require("../models/UserAuth");
const UserProfile = require("../models/UserProfile");
const UserSettings = require("../models/UserSettings");
const Group = require("../models/Group");

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { OAuth2Client } = require("google-auth-library");
const Joi = require("joi");
const axios = require("axios"); // ✅ Using Axios for HTTP Requests
const nodemailer = require("nodemailer"); // ✅ Used ONLY for formatting the email content
const asyncHandler = require("../utils/asyncHandler");
const AppError = require("../utils/AppError");

// ✅ IMPORT NOTIFICATION HANDLER
const { sendPersonalNotification } = require("../utils/notificationHandler");

// --------------------------------------------------------------------------
// 1. AUTH CLIENT (For Verifying User Logins)
// --------------------------------------------------------------------------
// This uses the OLD Client ID linked to your Mobile App/Frontend
const authClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// --------------------------------------------------------------------------
// 2. MAILER CLIENT (For Sending Emails via Gmail API)
// --------------------------------------------------------------------------
// This uses the NEW Client ID & Secret you just added to Render
const mailClient = new OAuth2Client(
  process.env.MAILER_CLIENT_ID,
  process.env.MAILER_CLIENT_SECRET,
);

// Set credentials for the mailer (SERVER-SIDE SENDER)
mailClient.setCredentials({
  refresh_token: process.env.MAILER_REFRESH_TOKEN,
});

// --------------------------------------------------------------------------
// ✅ HELPER: SEND EMAIL VIA GMAIL REST API (HTTP Port 443)
// --------------------------------------------------------------------------
const sendEmailViaGmailAPI = async (toEmail, toName, subject, htmlContent) => {
  if (!process.env.MAILER_REFRESH_TOKEN) {
    console.warn("⚠️ Email Skipped: MAILER_REFRESH_TOKEN is missing.");
    return;
  }

  try {
    // 1. Refresh the Access Token automatically using the Refresh Token
    const { token: accessToken } = await mailClient.getAccessToken();

    // 2. Build the Raw Email using Nodemailer (Stream Transport)
    const mailGenerator = nodemailer.createTransport({
      streamTransport: true,
      newline: "windows",
    });

    const mailOptions = {
      from: `"ASCON Alumni" <${process.env.EMAIL_USER}>`,
      to: toEmail,
      subject: subject,
      html: htmlContent,
    };

    const info = await mailGenerator.sendMail(mailOptions);

    // 3. Convert stream to a Base64URL string required by Gmail API
    const rawEmail = await new Promise((resolve, reject) => {
      let buffer = Buffer.alloc(0);
      info.message.on("data", (chunk) => {
        buffer = Buffer.concat([buffer, chunk]);
      });
      info.message.on("end", () => {
        resolve(buffer.toString("base64"));
      });
      info.message.on("error", reject);
    });

    // 4. Send via Gmail HTTP API (Port 443)
    const response = await axios.post(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/send`,
      {
        raw: rawEmail,
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      },
    );

    console.log(`✅ Gmail API: Sent to ${toEmail} (ID: ${response.data.id})`);
    return response.data;
  } catch (error) {
    console.error(
      "❌ Gmail API Error:",
      error.response ? error.response.data : error.message,
    );
    // Don't throw here to prevent crashing the auth flow
  }
};

// --------------------------------------------------------------------------
// VALIDATION SCHEMAS
// --------------------------------------------------------------------------
const registerSchema = Joi.object({
  fullName: Joi.string().min(6).required(),
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  phoneNumber: Joi.string().required(),
  programmeTitle: Joi.string().optional().allow(""),
  yearOfAttendance: Joi.alternatives()
    .try(Joi.string(), Joi.number())
    .optional()
    .allow(null, ""),
  customProgramme: Joi.string().optional().allow(""),
  city: Joi.string().optional().allow(""),
  googleToken: Joi.string().optional().allow(null, ""),
  fcmToken: Joi.string().optional().allow(null, ""),
  dateOfBirth: Joi.string().isoDate().optional().allow(null, ""),
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  fcmToken: Joi.string().optional().allow("", null),
});

// ✅ HELPER: Manage Tokens in the Auth Schema (Cap at 5)
const manageFcmToken = async (userId, token) => {
  if (!token) return;
  await UserAuth.findByIdAndUpdate(userId, {
    $pull: { fcmTokens: token },
  });
  await UserAuth.findByIdAndUpdate(userId, {
    $push: {
      fcmTokens: {
        $each: [token],
        $position: 0,
        $slice: 5,
      },
    },
  });
};

// --------------------------------------------------------------------------
// 1. REGISTER (Atomic Transaction Implemented)
// --------------------------------------------------------------------------
exports.register = asyncHandler(async (req, res) => {
  const { error } = registerSchema.validate(req.body);
  if (error) {
    throw new AppError(error.details[0].message, 400);
  }

  const { fullName, email, password, phoneNumber, fcmToken, dateOfBirth } =
    req.body;

  const emailExist = await UserAuth.findOne({ email });
  if (emailExist) {
    throw new AppError("Email already registered. Please Login.", 400);
  }

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // STEP 1: Create Auth
    const newUserAuth = new UserAuth({
      email,
      password: hashedPassword,
      isVerified: true,
      provider: "local",
      fcmTokens: fcmToken ? [fcmToken] : [],
      isOnline: true,
    });
    const savedAuth = await newUserAuth.save({ session });

    // STEP 2: Create Profile (Minimal Data)
    const newUserProfile = new UserProfile({
      userId: savedAuth._id,
      fullName,
      phoneNumber,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined,
    });
    await newUserProfile.save({ session });

    // STEP 3: Create Settings
    const newUserSettings = new UserSettings({
      userId: savedAuth._id,
      hasSeenWelcome: false,
      isEmailVisible: true,
      isPhoneVisible: false,
      isBirthdayVisible: true,
    });
    await newUserSettings.save({ session });

    await session.commitTransaction();
    session.endSession();

    // ==========================================
    // 🔔 SEND WELCOME EMAIL (VIA GMAIL API)
    // ==========================================
    await sendEmailViaGmailAPI(
      email,
      fullName,
      "Welcome to ASCON Alumni Connect! 🚀",
      `
      <div style="font-family: Arial, sans-serif; color: #333;">
        <div style="background-color: #0F3621; padding: 20px; text-align: center;">
          <h2 style="color: #fff; margin: 0;">Welcome to ASCON Connect</h2>
        </div>
        <div style="padding: 20px; border: 1px solid #ddd; border-top: none;">
          <h3>Hello ${fullName},</h3>
          <p>We are thrilled to have you join the ASCON Alumni Network!</p>
          <p>With this platform, you can:</p>
          <ul>
            <li>Reconnect with your class set.</li>
            <li>Find mentors and professional opportunities.</li>
            <li>Stay updated with ASCON events and news.</li>
          </ul>
          <p>To get the best experience, please take a moment to <strong>complete your profile</strong>.</p>
          <br/>
          <p>Warm Regards,<br/><strong>The ASCON Alumni Team</strong></p>
        </div>
      </div>
      `,
    );

    try {
      if (req.io) {
        req.io.emit("admin_stats_update", { type: "NEW_USER" });
        req.io.emit("user_status_update", {
          userId: savedAuth._id,
          isOnline: true,
          lastSeen: new Date(),
        });
      }
    } catch (notifyErr) {
      console.error("Post-registration notification error:", notifyErr);
    }

    const token = jwt.sign(
      { _id: savedAuth._id, isAdmin: false, canEdit: false },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    const refreshToken = jwt.sign(
      { _id: savedAuth._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" },
    );

    res.status(201).json({
      message: "Registration successful!",
      token: token,
      refreshToken: refreshToken,
      user: {
        id: savedAuth._id,
        fullName: newUserProfile.fullName,
        email: savedAuth.email,
        alumniId: null,
        hasSeenWelcome: false,
        phoneNumber: newUserProfile.phoneNumber,
        dateOfBirth: newUserProfile.dateOfBirth
          ? newUserProfile.dateOfBirth.toISOString()
          : null,
      },
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }
});

// --------------------------------------------------------------------------
// 2. LOGIN
// --------------------------------------------------------------------------
exports.login = asyncHandler(async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) {
    throw new AppError(error.details[0].message, 400);
  }

  const { email, password, fcmToken } = req.body;

  let userAuth = await UserAuth.findOne({ email });
  if (!userAuth) {
    throw new AppError("Invalid email or password.", 401);
  }

  const validPass = await bcrypt.compare(password, userAuth.password);
  if (!validPass) {
    throw new AppError("Invalid email or password.", 401);
  }

  if (userAuth.isVerified === false) {
    throw new AppError("Account pending approval by administrator.", 403);
  }

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });
  const userSettings = await UserSettings.findOne({ userId: userAuth._id });

  if (fcmToken) {
    await manageFcmToken(userAuth._id, fcmToken);
  }

  userAuth.isOnline = true;
  userAuth.lastSeen = new Date();
  await userAuth.save();

  if (req.io) {
    req.io.emit("user_status_update", {
      userId: userAuth._id,
      isOnline: true,
      lastSeen: userAuth.lastSeen,
    });
  }

  const token = jwt.sign(
    { _id: userAuth._id, isAdmin: userAuth.isAdmin, canEdit: userAuth.canEdit },
    process.env.JWT_SECRET,
    { expiresIn: "2h" },
  );

  const refreshToken = jwt.sign(
    { _id: userAuth._id },
    process.env.REFRESH_SECRET,
    { expiresIn: "30d" },
  );

  res.json({
    token,
    refreshToken,
    user: {
      id: userAuth._id,
      fullName: userProfile.fullName,
      email: userAuth.email,
      isAdmin: userAuth.isAdmin,
      canEdit: userAuth.canEdit,
      profilePicture: userProfile.profilePicture,
      hasSeenWelcome: userSettings.hasSeenWelcome || false,
      alumniId: userProfile.alumniId,
      yearOfAttendance: userProfile.yearOfAttendance,
      phoneNumber: userProfile.phoneNumber,
      dateOfBirth: userProfile.dateOfBirth
        ? userProfile.dateOfBirth.toISOString()
        : null,
    },
  });
});

// --------------------------------------------------------------------------
// 3. GOOGLE LOGIN
// --------------------------------------------------------------------------
exports.googleLogin = asyncHandler(async (req, res) => {
  const { token, fcmToken } = req.body;
  let name, email, picture;

  const isIdToken = token.split(".").length === 3;
  if (isIdToken) {
    const ticket = await authClient.verifyIdToken({
      // ✅ Use authClient here
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    name = payload.name;
    email = payload.email;
    picture = payload.picture;
  } else {
    const response = await axios.get(
      "https://www.googleapis.com/oauth2/v3/userinfo",
      { headers: { Authorization: `Bearer ${token}` } },
    );
    name = response.data.name;
    email = response.data.email;
    picture = response.data.picture;
  }

  let userAuth = await UserAuth.findOne({ email });
  let userProfile, userSettings;

  if (!userAuth) {
    const randomPassword = crypto.randomBytes(16).toString("hex");
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(randomPassword, salt);

    userAuth = new UserAuth({
      email: email,
      password: hashedPassword,
      isVerified: true,
      provider: "google",
      fcmTokens: fcmToken ? [fcmToken] : [],
      isOnline: true,
    });
    await userAuth.save();

    userProfile = new UserProfile({
      userId: userAuth._id,
      fullName: name,
      profilePicture: picture,
    });
    await userProfile.save();

    userSettings = new UserSettings({
      userId: userAuth._id,
      hasSeenWelcome: false,
    });
    await userSettings.save();

    if (req.io) req.io.emit("admin_stats_update", { type: "NEW_USER" });

    // Send Welcome via Gmail API
    await sendEmailViaGmailAPI(
      email,
      name,
      "Welcome to ASCON Alumni Connect! 🚀",
      `<p>Welcome to the platform, ${name}!</p>`,
    );
  } else {
    userProfile = await UserProfile.findOne({ userId: userAuth._id });
    userSettings = await UserSettings.findOne({ userId: userAuth._id });
  }

  if (!userAuth.isVerified) {
    throw new AppError("Account pending approval.", 403);
  }

  if (fcmToken) {
    await manageFcmToken(userAuth._id, fcmToken);
  }

  userAuth.isOnline = true;
  userAuth.lastSeen = new Date();
  await userAuth.save();

  if (req.io) {
    req.io.emit("user_status_update", {
      userId: userAuth._id,
      isOnline: true,
      lastSeen: userAuth.lastSeen,
    });
  }

  const authToken = jwt.sign(
    { _id: userAuth._id, isAdmin: userAuth.isAdmin, canEdit: userAuth.canEdit },
    process.env.JWT_SECRET,
    { expiresIn: "2h" },
  );

  const refreshToken = jwt.sign(
    { _id: userAuth._id },
    process.env.REFRESH_SECRET,
    { expiresIn: "30d" },
  );

  return res.json({
    token: authToken,
    refreshToken: refreshToken,
    user: {
      id: userAuth._id,
      fullName: userProfile.fullName,
      email: userAuth.email,
      isAdmin: userAuth.isAdmin,
      canEdit: userAuth.canEdit,
      profilePicture: userProfile.profilePicture,
      hasSeenWelcome: userSettings.hasSeenWelcome || false,
      alumniId: userProfile.alumniId,
      yearOfAttendance: userProfile.yearOfAttendance,
      phoneNumber: userProfile.phoneNumber,
      dateOfBirth: userProfile.dateOfBirth
        ? userProfile.dateOfBirth.toISOString()
        : null,
    },
  });
});

// --------------------------------------------------------------------------
// 4. REFRESH TOKEN
// --------------------------------------------------------------------------
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    throw new AppError("Refresh Token Required", 401);
  }

  try {
    const verified = jwt.verify(refreshToken, process.env.REFRESH_SECRET);
    const userAuth = await UserAuth.findById(verified._id);

    const newAccessToken = jwt.sign(
      {
        _id: userAuth._id,
        isAdmin: userAuth.isAdmin,
        canEdit: userAuth.canEdit,
      },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    res.json({ token: newAccessToken });
  } catch (err) {
    throw new AppError("Invalid Refresh Token", 403);
  }
});

// --------------------------------------------------------------------------
// 5. FORGOT PASSWORD (Using Gmail API)
// --------------------------------------------------------------------------
exports.forgotPassword = asyncHandler(async (req, res) => {
  if (!req.body.email) {
    throw new AppError("Email is required", 400);
  }

  const userAuth = await UserAuth.findOne({ email: req.body.email });
  if (!userAuth) {
    throw new AppError("Email not found", 404);
  }

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });
  const userName = userProfile ? userProfile.fullName : "Alumni";

  const token = crypto.randomBytes(20).toString("hex");
  userAuth.resetPasswordToken = token;
  userAuth.resetPasswordExpires = Date.now() + 3600000; // 1 hour
  await userAuth.save();

  const clientUrl = process.env.CLIENT_URL || "https://asconalumni.netlify.app";
  const resetUrl = `${clientUrl}/reset-password?token=${token}`;

  try {
    await sendEmailViaGmailAPI(
      userAuth.email,
      userName,
      "ASCON Alumni - Password Reset",
      `
      <h3>Password Reset Request</h3>
      <p>Hello ${userName},</p>
      <p>You requested a password reset. Click the link below:</p>
      <p><a href="${resetUrl}">Reset Password</a></p>
      `,
    );

    res.json({ message: "Reset link sent to your email!" });
  } catch (error) {
    // Rollback token if email fails
    userAuth.resetPasswordToken = undefined;
    userAuth.resetPasswordExpires = undefined;
    await userAuth.save();

    throw new AppError("Email could not be sent. Please try again later.", 500);
  }
});

// --------------------------------------------------------------------------
// 6. RESET PASSWORD EXECUTE
// --------------------------------------------------------------------------
exports.resetPassword = asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) {
    throw new AppError("Password too short.", 400);
  }

  const userAuth = await UserAuth.findOne({
    resetPasswordToken: token,
    resetPasswordExpires: { $gt: Date.now() },
  });
  if (!userAuth) {
    throw new AppError("Invalid or expired token.", 400);
  }

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(newPassword, salt);

  userAuth.password = hashedPassword;
  userAuth.resetPasswordToken = undefined;
  userAuth.resetPasswordExpires = undefined;

  await userAuth.save();
  res.json({ message: "Password updated successfully! Please login." });
});

// --------------------------------------------------------------------------
// 7. LOGOUT
// --------------------------------------------------------------------------
exports.logout = asyncHandler(async (req, res) => {
  const { userId, fcmToken } = req.body;
  if (userId && fcmToken) {
    await UserAuth.updateOne(
      { _id: userId },
      { $pull: { fcmTokens: fcmToken } },
    );
  }
  res.status(200).json({ message: "Logged out successfully" });
});

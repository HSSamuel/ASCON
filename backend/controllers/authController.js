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
const axios = require("axios");
const nodemailer = require("nodemailer");
const asyncHandler = require("../utils/asyncHandler");
const AppError = require("../utils/AppError");

// ✅ ID Generator & Notifications
const { generateAlumniId } = require("../utils/idGenerator");
const {
  sendPersonalNotification,
  notifyPeersOfNewUser,
} = require("../utils/notificationHandler");

// --------------------------------------------------------------------------
// 1. AUTH & MAILER CLIENTS
// --------------------------------------------------------------------------
const authClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const mailClient = new OAuth2Client(
  process.env.MAILER_CLIENT_ID,
  process.env.MAILER_CLIENT_SECRET,
);
mailClient.setCredentials({ refresh_token: process.env.MAILER_REFRESH_TOKEN });

const sendEmailViaGmailAPI = async (toEmail, toName, subject, htmlContent) => {
  if (!process.env.MAILER_REFRESH_TOKEN) {
    console.warn(
      `⚠️ Email Service Not Configured: MAILER_REFRESH_TOKEN is missing.`,
    );
    throw new Error("Email Service Not Configured");
  }

  try {
    const { token: accessToken } = await mailClient.getAccessToken();
    const mailGenerator = nodemailer.createTransport({
      streamTransport: true,
      newline: "windows",
    });
    const senderEmail = process.env.EMAIL_USER || "noreply@ascon.org";

    const mailOptions = {
      from: `"ASCON Alumni" <${senderEmail}>`,
      to: toEmail,
      subject: subject,
      html: htmlContent,
    };
    const info = await mailGenerator.sendMail(mailOptions);

    const rawEmail = await new Promise((resolve, reject) => {
      let buffer = Buffer.alloc(0);
      info.message.on(
        "data",
        (chunk) => (buffer = Buffer.concat([buffer, chunk])),
      );
      info.message.on("end", () => resolve(buffer.toString("base64")));
      info.message.on("error", reject);
    });

    const response = await axios.post(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/send`,
      { raw: rawEmail },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
      },
    );
    return response.data;
  } catch (error) {
    throw error;
  }
};

// --------------------------------------------------------------------------
// 2. VALIDATION SCHEMAS
// --------------------------------------------------------------------------
// ✅ UPDATED: Removed phoneNumber completely
const registerSchema = Joi.object({
  fullName: Joi.string().min(6).required(),
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  programmeTitle: Joi.string().required(),
  yearOfAttendance: Joi.alternatives()
    .try(Joi.string(), Joi.number())
    .required(),
  customProgramme: Joi.string().optional().allow(""),
  jobTitle: Joi.string().optional().allow(""),
  organization: Joi.string().optional().allow(""),
  bio: Joi.string().optional().allow(""),
  googleToken: Joi.string().optional().allow(null, ""),
  fcmToken: Joi.string().optional().allow(null, ""),
});

const loginSchema = Joi.object({
  email: Joi.string().min(6).required().email(),
  password: Joi.string().min(6).required(),
  fcmToken: Joi.string().optional().allow("", null),
});

const manageFcmToken = async (userId, token) => {
  if (!token || token.trim() === "") return;
  await UserAuth.findByIdAndUpdate(userId, { $pull: { fcmTokens: token } });
  await UserAuth.findByIdAndUpdate(userId, {
    $push: { fcmTokens: { $each: [token], $position: 0, $slice: 5 } },
  });
};

// --------------------------------------------------------------------------
// 3. REGISTER
// --------------------------------------------------------------------------
exports.register = asyncHandler(async (req, res) => {
  const { error } = registerSchema.validate(req.body);
  if (error) throw new AppError(error.details[0].message, 400);

  const email = req.body.email.toLowerCase().trim();
  const {
    fullName,
    password,
    fcmToken,
    programmeTitle,
    yearOfAttendance,
    customProgramme,
    jobTitle,
    organization,
    bio,
  } = req.body;

  const emailExist = await UserAuth.findOne({ email });
  if (emailExist)
    throw new AppError("Email already registered. Please Login.", 400);

  const generatedAlumniId = await generateAlumniId(yearOfAttendance);

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newAuthId = new mongoose.Types.ObjectId();
    const refreshToken = jwt.sign(
      { _id: newAuthId },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" },
    );
    const safeFcmTokens = fcmToken && fcmToken.trim() !== "" ? [fcmToken] : [];

    const newUserAuth = new UserAuth({
      _id: newAuthId,
      email: email,
      password: hashedPassword,
      isVerified: true,
      provider: "local",
      fcmTokens: safeFcmTokens,
      refreshTokens: [refreshToken],
      isOnline: true,
    });
    const savedAuth = await newUserAuth.save({ session });

    // ✅ UPDATED: Removed phoneNumber
    const newUserProfile = new UserProfile({
      userId: savedAuth._id,
      fullName,
      programmeTitle,
      yearOfAttendance,
      customProgramme,
      jobTitle,
      organization,
      bio,
      alumniId: generatedAlumniId,
    });
    await newUserProfile.save({ session });

    const newUserSettings = new UserSettings({
      userId: savedAuth._id,
      hasSeenWelcome: false,
    });
    await newUserSettings.save({ session });

    await session.commitTransaction();
    session.endSession();

    const newGroupName = `Class of ${yearOfAttendance}`;
    Group.findOneAndUpdate(
      { name: newGroupName, type: "Class" },
      {
        $addToSet: { members: savedAuth._id },
        $setOnInsert: { description: `Official group for the ${newGroupName}` },
      },
      { upsert: true, new: true },
    ).catch((e) => console.error("Group Sync Error:", e));

    try {
      await sendEmailViaGmailAPI(
        email,
        fullName,
        "Welcome to ASCON Alumni Connect! 🚀",
        `<h3>Hello ${fullName},</h3><p>Welcome to the ASCON Alumni Network! Your official Alumni ID is <strong>${generatedAlumniId}</strong>.</p>`,
      );
    } catch (emailError) {
      console.error("Non-fatal: Welcome email failed to send.");
    }

    notifyPeersOfNewUser(newUserProfile).catch((e) => console.error(e));

    const token = jwt.sign(
      { _id: savedAuth._id, isAdmin: false, canEdit: false },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    res.status(201).json({
      message: "Registration successful!",
      token: token,
      refreshToken: refreshToken,
      user: {
        id: savedAuth._id,
        fullName: newUserProfile.fullName,
        email: savedAuth.email,
        hasSeenWelcome: false,
        yearOfAttendance: newUserProfile.yearOfAttendance,
        alumniId: generatedAlumniId,
      },
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    throw err;
  }
});

// --------------------------------------------------------------------------
// 4. LOGIN
// --------------------------------------------------------------------------
exports.login = asyncHandler(async (req, res) => {
  const { error } = loginSchema.validate(req.body);
  if (error) throw new AppError(error.details[0].message, 400);

  const email = req.body.email.toLowerCase().trim();
  const { password, fcmToken } = req.body;

  let userAuth = await UserAuth.findOne({ email });
  if (!userAuth) throw new AppError("Invalid email or password.", 401);

  const validPass = await bcrypt.compare(password, userAuth.password);
  if (!validPass) throw new AppError("Invalid email or password.", 401);
  if (userAuth.isVerified === false)
    throw new AppError("Account pending approval.", 403);

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });
  const userSettings = await UserSettings.findOne({ userId: userAuth._id });

  if (fcmToken) await manageFcmToken(userAuth._id, fcmToken);

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

  const currentTokens = userAuth.refreshTokens || [];
  userAuth.refreshTokens = [...currentTokens, refreshToken].slice(-5);
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

  // ✅ UPDATED: Removed phoneNumber from response
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
    },
  });
});

// --------------------------------------------------------------------------
// 5. GOOGLE LOGIN
// --------------------------------------------------------------------------
exports.googleLogin = asyncHandler(async (req, res) => {
  const { token, fcmToken } = req.body;
  let name, rawEmail, picture;

  const isIdToken = token.split(".").length === 3;
  if (isIdToken) {
    const ticket = await authClient.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    name = payload.name;
    rawEmail = payload.email;
    picture = payload.picture;
  } else {
    const response = await axios.get(
      "https://www.googleapis.com/oauth2/v3/userinfo",
      { headers: { Authorization: `Bearer ${token}` } },
    );
    name = response.data.name;
    rawEmail = response.data.email;
    picture = response.data.picture;
  }

  const email = rawEmail.toLowerCase().trim();
  let userAuth = await UserAuth.findOne({ email });
  let userProfile, userSettings;

  if (!userAuth) {
    const randomPassword = crypto.randomBytes(16).toString("hex");
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(randomPassword, salt);

    const safeFcmTokens = fcmToken && fcmToken.trim() !== "" ? [fcmToken] : [];

    userAuth = new UserAuth({
      email: email,
      password: hashedPassword,
      isVerified: true,
      provider: "google",
      fcmTokens: safeFcmTokens,
      isOnline: true,
      refreshTokens: [],
    });
    await userAuth.save();

    let safePicture = picture;
    if (
      picture &&
      (picture.includes("profile/picture") || picture.includes("default-user"))
    ) {
      safePicture = null;
    }

    userProfile = new UserProfile({
      userId: userAuth._id,
      fullName: name,
      profilePicture: safePicture,
    });
    await userProfile.save();

    userSettings = new UserSettings({
      userId: userAuth._id,
      hasSeenWelcome: false,
    });
    await userSettings.save();

    if (req.io) req.io.emit("admin_stats_update", { type: "NEW_USER" });

    try {
      await sendEmailViaGmailAPI(
        email,
        name,
        "Welcome to ASCON Alumni Connect! 🚀",
        `<p>Welcome to the platform, ${name}!</p>`,
      );
    } catch (emailError) {}
  } else {
    userProfile = await UserProfile.findOne({ userId: userAuth._id });
    userSettings = await UserSettings.findOne({ userId: userAuth._id });
  }

  if (!userAuth.isVerified)
    throw new AppError("Account pending approval.", 403);
  if (fcmToken) await manageFcmToken(userAuth._id, fcmToken);

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

  const currentTokens = userAuth.refreshTokens || [];
  userAuth.refreshTokens = [...currentTokens, refreshToken].slice(-5);
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

  // ✅ UPDATED: Removed phoneNumber
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
    },
  });
});

// --------------------------------------------------------------------------
// 6. REFRESH TOKEN
// --------------------------------------------------------------------------
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw new AppError("Refresh Token Required", 401);

  try {
    const verified = jwt.verify(refreshToken, process.env.REFRESH_SECRET);
    const userAuth = await UserAuth.findById(verified._id);

    if (!userAuth || !userAuth.refreshTokens.includes(refreshToken)) {
      throw new AppError("Invalid, Stolen, or Expired Refresh Token", 403);
    }

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
// 7. FORGOT PASSWORD
// --------------------------------------------------------------------------
exports.forgotPassword = asyncHandler(async (req, res) => {
  if (!req.body.email) throw new AppError("Email is required", 400);

  const email = req.body.email.toLowerCase().trim();
  const userAuth = await UserAuth.findOne({ email: email });
  if (!userAuth) throw new AppError("Email not found", 404);

  const userProfile = await UserProfile.findOne({ userId: userAuth._id });
  const userName = userProfile ? userProfile.fullName : "Alumni";

  const token = crypto.randomBytes(20).toString("hex");
  userAuth.resetPasswordToken = token;
  userAuth.resetPasswordExpires = Date.now() + 3600000;
  await userAuth.save();

  const clientUrl = process.env.CLIENT_URL || "https://asconalumni.org";
  const resetUrl = `${clientUrl}/reset-password?token=${token}`;

  try {
    await sendEmailViaGmailAPI(
      userAuth.email,
      userName,
      "ASCON Alumni - Password Reset",
      `<h3>Password Reset Request</h3><p>Hello ${userName},</p><p>You requested a password reset. Click the link below:</p><p><a href="${resetUrl}">Reset Password</a></p>`,
    );
    res.json({ message: "Reset link sent to your email!" });
  } catch (error) {
    userAuth.resetPasswordToken = undefined;
    userAuth.resetPasswordExpires = undefined;
    await userAuth.save();
    throw new AppError("Email could not be sent. Please try again later.", 500);
  }
});

// --------------------------------------------------------------------------
// 8. RESET PASSWORD EXECUTE
// --------------------------------------------------------------------------
exports.resetPassword = asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  if (!newPassword || newPassword.length < 6)
    throw new AppError("Password too short.", 400);

  const userAuth = await UserAuth.findOne({
    resetPasswordToken: token,
    resetPasswordExpires: { $gt: Date.now() },
  });
  if (!userAuth) throw new AppError("Invalid or expired token.", 400);

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(newPassword, salt);

  userAuth.password = hashedPassword;
  userAuth.resetPasswordToken = undefined;
  userAuth.resetPasswordExpires = undefined;
  userAuth.refreshTokens = []; // Log out from all devices

  await userAuth.save();
  res.json({ message: "Password updated successfully! Please login." });
});

// --------------------------------------------------------------------------
// 9. LOGOUT
// --------------------------------------------------------------------------
exports.logout = asyncHandler(async (req, res) => {
  const { userId, fcmToken, refreshToken } = req.body;

  if (userId) {
    await UserAuth.updateOne(
      { _id: userId },
      { $pull: { fcmTokens: fcmToken, refreshTokens: refreshToken } },
    );
  }
  res.status(200).json({ message: "Logged out successfully" });
});

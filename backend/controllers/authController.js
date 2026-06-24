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
const { MailerSend, EmailParams, Sender, Recipient } = require("mailersend");
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

const mailerSend = new MailerSend({
  apiKey: process.env.MAILERSEND_API_KEY,
});

const sendEmailViaMailerSend = async (
  toEmail,
  toName,
  subject,
  htmlContent,
) => {
  if (!process.env.MAILERSEND_API_KEY) {
    console.warn(
      `⚠️ Email Service Not Configured: MAILERSEND_API_KEY is missing.`,
    );
    throw new Error("Email Service Not Configured");
  }

  try {
    const sentFrom = new Sender(
      process.env.EMAIL_FROM || "alerts@asconalumni.org",
      "ASCON Alumni",
    );
    const recipients = [new Recipient(toEmail, toName)];

    const emailParams = new EmailParams()
      .setFrom(sentFrom)
      .setTo(recipients)
      .setSubject(subject)
      .setHtml(htmlContent)
      .setText(htmlContent.replace(/<[^>]*>?/gm, ""));

    const response = await mailerSend.email.send(emailParams);
    return response;
  } catch (error) {
    console.error("MailerSend Error:", error);
    throw error;
  }
};

// --------------------------------------------------------------------------
// 2. VALIDATION SCHEMAS
// --------------------------------------------------------------------------
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
      { expiresIn: "30d" }, // ✅ Extended to 30 days
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

    const profilePicUrl = req.file ? req.file.path : "";

    const newUserProfile = new UserProfile({
      userId: savedAuth._id,
      fullName,
      programmeTitle,
      yearOfAttendance,
      customProgramme,
      jobTitle,
      organization,
      bio,
      profilePicture: profilePicUrl,
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
      const emailHtmlContent = `
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 25px; border: 1px solid #eaeaea; border-radius: 12px; background-color: #ffffff;">
          <div style="text-align: center; margin-bottom: 25px;">
              <h2 style="color: #1B5E3A; margin: 0; font-size: 24px; letter-spacing: -0.5px;">ASCON Alumni Connect</h2>
          </div>
          
          <h3 style="color: #333333; font-size: 20px;">Hello ${fullName},</h3>
          
          <p style="color: #555555; line-height: 1.6; font-size: 15px;">
              Welcome to the official digital platform for the <a href="https://ascon.gov.ng" target="_blank" style="color: #1B5E3A; text-decoration: none;"><strong>Administrative Staff College of Nigeria (ASCON)</strong></a> Alumni! We are thrilled to have you join our growing network of esteemed professionals and public administrators.
          </p>

          <div style="background-color: #F4F7F6; padding: 20px; border-radius: 8px; text-align: center; margin: 25px 0; border: 1px solid #e0e6ed;">
              <p style="margin: 0; color: #666666; font-size: 13px; text-transform: uppercase; font-weight: bold; letter-spacing: 1px;">Your Official Alumni ID</p>
              <h1 style="color: #1B5E3A; margin: 10px 0 0 0; letter-spacing: 2px; font-size: 28px;">${generatedAlumniId}</h1>
          </div>

          <p style="color: #555555; line-height: 1.6; font-size: 15px;">
              As a registered member, your account is now active. You have exclusive access to:
          </p>

          <ul style="color: #555555; line-height: 1.6; font-size: 15px; padding-left: 20px;">
              <li style="margin-bottom: 8px;"><strong>Smart Networking:</strong> Connect with peers based on shared skills and industries.</li>
              <li style="margin-bottom: 8px;"><strong>Real-Time Communication:</strong> Engage in seamless chat and voice calls with other alumni.</li>
              <li style="margin-bottom: 8px;"><strong>Digital Identity:</strong> Access and share your verifiable digital ID card instantly.</li>
              <li style="margin-bottom: 8px;"><strong>Exclusive Updates:</strong> Stay informed about upcoming events and programme highlights.</li>
          </ul>

          <p style="color: #888888; font-size: 12px; border-top: 1px solid #eaeaea; padding-top: 20px; text-align: center; line-height: 1.5; margin-top: 35px;">
              If you have any questions or need assistance, please contact the administrative team at <a href="mailto:info@ascon.gov.ng" style="color: #1B5E3A; text-decoration: none; font-weight: bold;">info@ascon.gov.ng</a>.<br>
              &copy; ${new Date().getFullYear()} <a href="https://ascon.gov.ng" target="_blank" style="color: #888888; text-decoration: none;">Administrative Staff College of Nigeria (ASCON)</a>.
          </p>
      </div>
      `;

      await sendEmailViaMailerSend(
        email,
        fullName,
        "Welcome to ASCON Alumni Connect! 🚀",
        emailHtmlContent,
      );
    } catch (emailError) {
      console.error("Non-fatal: Welcome email failed to send.", emailError);
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
        profilePicture: newUserProfile.profilePicture,
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
    { expiresIn: "30d" }, // ✅ Extended to 30 days
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
      await sendEmailViaMailerSend(
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
    { expiresIn: "30d" }, // ✅ Extended to 30 days
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
// 6. REFRESH TOKEN (WITH ROTATION)
// --------------------------------------------------------------------------
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw new AppError("Refresh Token Required", 401);

  try {
    // 1. Verify the incoming token
    const verified = jwt.verify(refreshToken, process.env.REFRESH_SECRET);
    const userAuth = await UserAuth.findById(verified._id);

    // 2. Check if the token exists in the user's active array
    if (!userAuth || !userAuth.refreshTokens.includes(refreshToken)) {
      throw new AppError("Invalid, Stolen, or Expired Refresh Token", 403);
    }

    // 3. ROTATION: Remove the used refresh token
    userAuth.refreshTokens = userAuth.refreshTokens.filter(rt => rt !== refreshToken);

    // 4. Generate a NEW Access Token
    const newAccessToken = jwt.sign(
      {
        _id: userAuth._id,
        isAdmin: userAuth.isAdmin,
        canEdit: userAuth.canEdit,
      },
      process.env.JWT_SECRET,
      { expiresIn: "2h" },
    );

    // 5. Generate a NEW Refresh Token (30 Days)
    const newRefreshToken = jwt.sign(
      { _id: userAuth._id },
      process.env.REFRESH_SECRET,
      { expiresIn: "30d" }, // ✅ Extended to 30 days
    );

    // 6. Add the new refresh token to the array and save
    userAuth.refreshTokens.push(newRefreshToken);
    await userAuth.save();

    // 7. Send BOTH tokens back to the client
    res.json({ token: newAccessToken, refreshToken: newRefreshToken });
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
  // ✅ FIX: Hash the token before storing it in the database
  const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

  userAuth.resetPasswordToken = hashedToken;
  userAuth.resetPasswordExpires = Date.now() + 3600000;
  await userAuth.save();

  const clientUrl = process.env.CLIENT_URL || "https://asconalumni.org";
  // ✅ FIX: Email the unhashed original token to the user
  const resetUrl = `${clientUrl}/reset-password?token=${token}`;

  try {
    await sendEmailViaMailerSend(
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

  // ✅ FIX: Hash the incoming token to match what is stored in the database
  const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

  const userAuth = await UserAuth.findOne({
    resetPasswordToken: hashedToken,
    resetPasswordExpires: { $gt: Date.now() },
  });
  if (!userAuth) throw new AppError("Invalid or expired token.", 400);

  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(newPassword, salt);

  userAuth.password = hashedPassword;
  userAuth.resetPasswordToken = undefined;
  userAuth.resetPasswordExpires = undefined;
  userAuth.refreshTokens = [];

  await userAuth.save();
  res.json({ message: "Password updated successfully! Please login." });
});

// --------------------------------------------------------------------------
// 9. LOGOUT
// --------------------------------------------------------------------------
exports.logout = asyncHandler(async (req, res) => {
  const { userId, fcmToken, refreshToken, logoutAllDevices } = req.body;

  if (userId) {
    if (logoutAllDevices) {
      await UserAuth.updateOne(
        { _id: userId },
        { $set: { fcmTokens: [], refreshTokens: [] } },
      );
    } else {
      if (fcmToken) {
        await UserAuth.updateOne(
          { _id: userId },
          { $pull: { fcmTokens: fcmToken, refreshTokens: refreshToken } },
        );
      } else {
        await UserAuth.updateOne(
          { _id: userId },
          { $set: { fcmTokens: [] }, $pull: { refreshTokens: refreshToken } },
        );
      }
    }
  }

  res.status(200).json({ message: "Logged out successfully" });
});

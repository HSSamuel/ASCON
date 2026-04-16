const cloudinary = require("cloudinary").v2;
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const multer = require("multer");
const dotenv = require("dotenv");

dotenv.config();

// 1. Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// 2. Configure Storage
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "ascon_alumni_profiles", // The folder in your cloud
    allowed_formats: ["jpg", "png", "jpeg"],
  },
});

// 3. Export the Upload Tool
const upload = multer({ storage: storage });

// ✅ FIX: Attach the configured cloudinary object so other files (like chat.js) can use it
upload.cloudinary = cloudinary;

module.exports = upload;

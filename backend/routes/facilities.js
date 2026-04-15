const router = require("express").Router();
const Facility = require("../models/Facility");
const verify = require("./verifyToken"); // Security Middleware

// ✅ 1. IMPORT NOTIFICATION HANDLER
const { sendBroadcastNotification } = require("../utils/notificationHandler");

// 1. GET ALL FACILITIES (Public)
router.get("/", async (req, res) => {
  try {
    const facilities = await Facility.find({ isActive: true });
    res.json({ success: true, data: facilities });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 2. ADD A FACILITY (Admin Only)
router.post("/", verify, async (req, res) => {
  if (!req.user.isAdmin)
    return res.status(403).json({ message: "Access Denied" });

  const facility = new Facility({
    name: req.body.name,
    image: req.body.image,
    description: req.body.description,
    paymentUrl: req.body.paymentUrl,
    rates: req.body.rates,
  });

  try {
    const savedFacility = await facility.save();

    // ✅ 2. TRIGGER BROADCAST NOTIFICATION
    await sendBroadcastNotification(
      `New Facility: ${savedFacility.name}`,
      `Available for booking! ${savedFacility.description.substring(0, 50)}...`,
      {
        route: "facility_detail", // Needs to be handled in Mobile App routing if deep linking is required
        id: savedFacility._id.toString(),
      }
    );

    res.json({ success: true, data: savedFacility });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// 3. UPDATE A FACILITY (Admin Only)
router.put("/:id", verify, async (req, res) => {
  if (!req.user.isAdmin)
    return res.status(403).json({ message: "Access Denied" });

  try {
    const updatedFacility = await Facility.findByIdAndUpdate(
      req.params.id,
      {
        $set: {
          name: req.body.name,
          image: req.body.image,
          description: req.body.description,
          paymentUrl: req.body.paymentUrl,
          rates: req.body.rates,
          isActive: req.body.isActive, // Allow toggling status
        },
      },
      { new: true }
    );
    res.json({ success: true, data: updatedFacility });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// 4. DELETE A FACILITY (Admin Only)
router.delete("/:id", verify, async (req, res) => {
  if (!req.user.isAdmin)
    return res.status(403).json({ message: "Access Denied" });

  try {
    await Facility.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: "Facility deleted" });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

module.exports = router;

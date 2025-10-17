const express = require("express");
const router = express.Router();
const Login = require("../models/login");

// Register a new user
router.post("/register", async (req, res) => {
  try {
    // Log for debugging
    console.log("[POST /api/auth/register] body=", req.body);
    let { email, password, name, phoneNumber, address, role } = req.body;
    // Allow alternative key 'phone'
    if (!phoneNumber && req.body.phone) phoneNumber = req.body.phone;

    const missing = [];
    if (!email) missing.push("email");
    if (!password) missing.push("password");
    if (!name) missing.push("name");
    if (!phoneNumber) missing.push("phoneNumber");
    if (!address) missing.push("address");
    if (address) {
      if (!address.houseNumber) missing.push("address.houseNumber");
      if (!address.ward) missing.push("address.ward");
      if (!address.city) missing.push("address.city");
    }
    if (missing.length > 0) {
      return res.status(400).json({ error: "Missing fields", details: missing });
    }

    // NOTE: For production you MUST hash passwords (bcrypt) and validate inputs.
    const existing = await Login.findOne({ email });
    if (existing)
      return res.status(409).json({ error: "Email already registered" });

    const user = new Login({ email, password, name, phoneNumber, address, role: role || 'user' });
    await user.save();
    res.status(201).json({ message: "User created", userId: user._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// Simple login (plaintext check)
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password)
      return res.status(400).json({ error: "Missing fields" });

    const user = await Login.findOne({ email });
    if (!user) return res.status(401).json({ error: "Invalid credentials" });

    // Replace with bcrypt.compare in real app
    if (user.password !== password)
      return res.status(401).json({ error: "Invalid credentials" });

    res.json({
      message: "Login successful",
      user: { id: user._id, email: user.email, name: user.name, phoneNumber: user.phoneNumber, role: user.role },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;

// Extra endpoints for reading user profile (demo)
// GET /api/auth/users/:id -> get user by id
router.get("/users/:id", async (req, res) => {
  try {
    const user = await Login.findById(req.params.id).lean();
    if (!user) return res.status(404).json({ error: "User not found" });
    res.json({
      id: user._id,
      email: user.email,
      name: user.name,
      phoneNumber: user.phoneNumber,
      address: user.address,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// PUT /api/auth/users/:id -> update basic profile fields
router.put("/users/:id", async (req, res) => {
  try {
    const updates = {};
    const allowed = ["name", "email", "phoneNumber", "address"];
    for (const key of allowed) {
      if (req.body && Object.prototype.hasOwnProperty.call(req.body, key)) {
        updates[key] = req.body[key];
      }
    }
    const updated = await Login.findByIdAndUpdate(req.params.id, updates, { new: true });
    if (!updated) return res.status(404).json({ error: "User not found" });
    res.json({
      id: updated._id,
      email: updated.email,
      name: updated.name,
      phoneNumber: updated.phoneNumber,
      address: updated.address,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// GET /api/auth/profile -> return the first user (for demo when no auth persisted)
router.get("/profile", async (req, res) => {
  try {
    const user = await Login.findOne({}).lean();
    if (!user) return res.status(404).json({ error: "No users" });
    res.json({
      id: user._id,
      email: user.email,
      name: user.name,
      phoneNumber: user.phoneNumber,
      address: user.address,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

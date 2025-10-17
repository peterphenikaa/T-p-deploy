const express = require("express");
const router = express.Router();
const { client } = require("../redisClient");

// POST /api/location
// Body: { userId, lat, lng, timestamp }
router.post("/", async (req, res) => {
  try {
    const { userId, lat, lng, timestamp } = req.body;
    if (!userId || lat == null || lng == null) {
      return res
        .status(400)
        .json({ error: "Missing fields (userId, lat, lng required)" });
    }

    const item = {
      userId,
      lat: Number(lat),
      lng: Number(lng),
      timestamp: timestamp || Date.now(),
    };

    // Store per-user list: locations:<userId>
    const key = `locations:${userId}`;
    await client.rPush(key, JSON.stringify(item));

    // Optionally trim list to last N items (e.g., 100)
    await client.lTrim(key, -100, -1);

    res.json({ message: "Location saved", item });
  } catch (err) {
    console.error("Error saving location", err);
    res.status(500).json({ error: "Server error" });
  }
});

// GET /api/location/:userId/latest
// Trả về vị trí mới nhất lưu trong Redis cho user
router.get("/:userId/latest", async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!userId) return res.status(400).json({ error: "Missing userId" });

    const key = `locations:${userId}`;
    // lấy phần tử cuối cùng (mới nhất) trong list
    const items = await client.lRange(key, -1, -1);
    if (!items || items.length === 0) {
      return res.status(404).json({ error: "No location found" });
    }

    let item;
    try {
      item = JSON.parse(items[0]);
    } catch (_) {
      // nếu không parse được, trả về raw
      return res.json({ raw: items[0] });
    }

    return res.json(item);
  } catch (err) {
    console.error("Error reading latest location", err);
    res.status(500).json({ error: "Server error" });
  }
});

module.exports = router;

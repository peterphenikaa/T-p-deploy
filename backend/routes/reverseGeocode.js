const express = require("express");
const fetch = require("node-fetch");
const router = express.Router();

// GET /api/reverse-geocode?lat=...&lon=...
router.get("/", async (req, res) => {
  const lat = req.query.lat;
  const lon = req.query.lon;
  if (!lat || !lon)
    return res.status(400).json({ error: "lat and lon required" });

  const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${encodeURIComponent(
    lat
  )}&lon=${encodeURIComponent(lon)}&zoom=18&addressdetails=1`;
  try {
    const r = await fetch(url, {
      headers: {
        // Replace with your app name and contact details per Nominatim policy
        "User-Agent":
          process.env.NOMINATIM_USER_AGENT ||
          "food_delivery_app/1.0 (+https://example.com)",
      },
      timeout: 8000,
    });
    if (!r.ok) {
      return res
        .status(r.status)
        .json({ error: "Nominatim error", statusText: r.statusText });
    }
    const data = await r.json();
    // Prevent browsers and intermediate caches (CDNs) from returning 304 Not Modified
    // so the frontend always receives a fresh 200 response with the body.
    res.set({
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
      Pragma: "no-cache",
      Expires: "0",
      "Surrogate-Control": "no-store",
    });
    res.status(200).json(data);
  } catch (err) {
    console.error("Reverse geocode proxy error:", err);
    res.status(500).json({ error: "Proxy failed" });
  }
});

module.exports = router;

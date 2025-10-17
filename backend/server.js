require("dotenv").config();
// Nó nạp (load) toàn bộ biến môi trường từ file .env vào process.env của Node.js.
const express = require("express");
const cors = require("cors");
// Nó giúp server cho phép (hoặc chặn) client từ domain khác gọi API của bạn.
const mongoose = require("mongoose");
const foodRoute = require("./routes/foodRoute");
const loginRoute = require("./routes/login");
const locationRoute = require("./routes/location");
const { connectRedis } = require("./redisClient");
const addressRoute = require("./routes/addressRoute");
const restaurantRoute = require("./routes/restaurantRoute");
const orderRoute = require("./routes/orderRoute");
const userManagementRoute = require("./routes/userManagementRoute");
const reverseGeocodeRoute = require("./routes/reverseGeocode");

// Read connection values from environment (see .env or .env.example)
const MONGO_URL =
  process.env.MONGO_URL ||
  process.env.MONGO ||
  "mongodb://localhost:27017/FoodDeliveryApp";

mongoose
  .connect(MONGO_URL, {
    useNewUrlParser: true,
    // useNewUrlParser: true buộc nó dùng parser mới và ổn định hơn
    useUnifiedTopology: true,
  })
  .then(() => console.log("Connected to MongoDB"))
  .catch((err) => console.error("Failed to connect to MongoDB", err));

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());

app.use("/api/foods", foodRoute);
app.use("/api/auth", loginRoute);
app.use("/api/location", locationRoute);
app.use("/api/addresses", addressRoute);
app.use("/api", restaurantRoute);
app.use("/api/orders", orderRoute);
app.use("/api/users", userManagementRoute);
app.use("/api/reverse-geocode", reverseGeocodeRoute);

// Hello World route
app.get("/", (req, res) => {
  res.json({
    message: "Hello World from Food Delivery Backend!",
    status: "success",
    timestamp: new Date().toISOString(),
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  // Connect to Redis (best-effort)
  connectRedis().catch((err) =>
    console.error("Failed to connect to Redis", err)
  );
});

module.exports = app;

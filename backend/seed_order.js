require("dotenv").config();
const mongoose = require("mongoose");
const Order = require("./models/order");
const Food = require("./models/food");
const Login = require("./models/login");

const MONGO =
  process.env.MONGO_URL || process.env.MONGO || "mongodb://localhost:27017/FoodDeliveryApp";

function makeItem(food, qty) {
  const unit = Number(food.price) || 0;
  const quantity = qty;
  const totalPrice = unit * quantity;
  return {
    foodId: food._id,
    name: food.name,
    image: food.image || null,
    size: 'M',
    quantity,
    price: unit,
    totalPrice,
  };
}

async function run() {
  await mongoose.connect(MONGO, { useNewUrlParser: true, useUnifiedTopology: true });
  console.log("Connected to", MONGO);

  const users = await Login.find({}).limit(2);
  if (users.length === 0) throw new Error("No users found. Run seed.js first");

  const foods = await Food.find({}).limit(6);
  if (foods.length < 2) throw new Error("Not enough foods. Run seed_food.js first");

  // Get restaurant info for orders
  const Restaurant = require("./models/restaurant");
  const restaurants = await Restaurant.find({});
  if (restaurants.length === 0) throw new Error("No restaurants found. Run seed_restaurant.js first");

  await Order.deleteMany({});

  const addressStr = (u) => {
    const a = u.address || {};
    return `${a.houseNumber || '1'}, ${a.ward || 'Ward 1'}, ${a.city || 'Ho Chi Minh'}`;
  };

  const now = new Date();
  function shiftDays(d, n) {
    const x = new Date(d);
    x.setDate(x.getDate() + n);
    return x;
  }

  function buildOrder({ user, items, status, note, createdShiftDays = 0 }) {
    const subtotal = items.reduce((s, it) => s + (it.totalPrice || 0), 0);
    const deliveryFee = 15000;
    const serviceFee = Math.round(subtotal * 0.10); // 10% phí dịch vụ giống ví dụ
    const total = subtotal + deliveryFee + serviceFee;
    
    // Get restaurant info from the first food item's restaurantId
    const firstFood = items[0];
    const restaurant = restaurants.find(r => r._id.toString() === firstFood.foodId.toString()) || restaurants[0];
    
    return {
      orderId: `ORD-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      userId: String(user._id),
      userName: user.name,
      userPhone: user.phoneNumber || '0900000000',
      items,
      subtotal,
      deliveryFee,
      serviceFee,
      total,
      totalAmount: total, // phục vụ API doanh thu hiện tại
      paymentStatus: 'paid',
      deliveryAddress: addressStr(user),
      estimatedDeliveryTime: '20-30 phút',
      restaurantName: restaurant.name,
      restaurantAddress: restaurant.address,
      restaurantId: restaurant._id,
      note,
      status,
      createdAt: shiftDays(now, -createdShiftDays),
      updatedAt: shiftDays(now, -createdShiftDays),
    };
  }

  const docs = [
    buildOrder({
      user: users[0],
      items: [makeItem(foods[0], 2), makeItem(foods[1], 1)],
      status: 'requested',
      note: 'Không cay, thêm tương cà',
      createdShiftDays: 1,
    }),
    buildOrder({
      user: users[0],
      items: [makeItem(foods[2], 1)],
      status: 'preparing',
      note: 'Giao nhanh giúp mình',
      createdShiftDays: 0,
    }),
    buildOrder({
      user: users[1] || users[0],
      items: [makeItem(foods[3] || foods[0], 2)],
      status: 'completed',
      note: '',
      createdShiftDays: 3,
    }),
    buildOrder({
      user: users[1] || users[0],
      items: [makeItem(foods[4] || foods[1], 1), makeItem(foods[5] || foods[2], 1)],
      status: 'delivering',
      note: 'Gọi trước khi tới',
      createdShiftDays: 2,
    }),
  ];

  // Use raw collection insert to bypass Mongoose validation/strict, so we can
  // store fields like totalAmount and lowercase status that backend routes expect.
  const result = await Order.collection.insertMany(docs, { ordered: true });
  console.log("Inserted orders:", Object.values(result.insertedIds).length);

  await mongoose.disconnect();
  console.log("Disconnected");
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});



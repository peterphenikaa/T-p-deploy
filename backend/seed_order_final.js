require("dotenv").config();
const mongoose = require("mongoose");
const Order = require("./models/order");
const Food = require("./models/food");
const Restaurant = require("./models/restaurant");

const MONGO =
  process.env.MONGO_URL || process.env.MONGO || "mongodb://localhost:27017/FoodDeliveryApp";

async function run() {
  await mongoose.connect(MONGO, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  });
  console.log("Connected to", MONGO);

  // Get foods and restaurants
  const foods = await Food.find({}).populate('restaurantId');
  const restaurants = await Restaurant.find({});
  
  if (foods.length < 2) throw new Error("Not enough foods. Run seed_food.js first");
  if (restaurants.length === 0) throw new Error("No restaurants found. Run seed_food.js first");

  await Order.deleteMany({});

  const now = new Date();
  function shiftDays(d, n) {
    const x = new Date(d);
    x.setDate(x.getDate() + n);
    return x;
  }

  // Find specific foods by name
  const burgerClassic = foods.find(f => f.name === "Burger Classic");
  const hotDogSpecial = foods.find(f => f.name === "Hot Dog Special");
  const pepperoniPizza = foods.find(f => f.name === "Pepperoni Pizza");
  const caesarSalad = foods.find(f => f.name === "Caesar Salad");

  const orders = [
    // Order from Burger Heaven
    {
      orderId: `ORD${Date.now()}${Math.random().toString(36).substr(2, 9).toUpperCase()}`,
      userId: "user123",
      userName: "John Doe",
      userPhone: "0123456789",
      items: [
        {
          foodId: burgerClassic._id,
          name: burgerClassic.name,
          image: burgerClassic.image,
          size: "M",
          quantity: 2,
          price: burgerClassic.price,
          totalPrice: burgerClassic.price * 2,
        },
        {
          foodId: hotDogSpecial._id,
          name: hotDogSpecial.name,
          image: hotDogSpecial.image,
          size: "L",
          quantity: 1,
          price: hotDogSpecial.price,
          totalPrice: hotDogSpecial.price * 1,
        }
      ],
      subtotal: burgerClassic.price * 2 + hotDogSpecial.price * 1,
      deliveryFee: 15000,
      serviceFee: Math.round((burgerClassic.price * 2 + hotDogSpecial.price * 1) * 0.1),
      total: burgerClassic.price * 2 + hotDogSpecial.price * 1 + 15000 + Math.round((burgerClassic.price * 2 + hotDogSpecial.price * 1) * 0.1),
      deliveryAddress: "123 Main Street, Ward 1, District 1, Ho Chi Minh City",
      note: "Không cay, thêm tương cà",
      status: "PENDING",
      estimatedDeliveryTime: "20-30 phút",
      restaurantName: burgerClassic.restaurantId.name,
      restaurantAddress: burgerClassic.restaurantId.address,
      createdAt: shiftDays(now, -1),
      updatedAt: shiftDays(now, -1),
    },
    // Order from The Pizza Place
    {
      orderId: `ORD${Date.now() + 1}${Math.random().toString(36).substr(2, 9).toUpperCase()}`,
      userId: "user456",
      userName: "Jane Smith",
      userPhone: "0987654321",
      items: [
        {
          foodId: pepperoniPizza._id,
          name: pepperoniPizza.name,
          image: pepperoniPizza.image,
          size: "L",
          quantity: 1,
          price: pepperoniPizza.price,
          totalPrice: pepperoniPizza.price * 1,
        },
        {
          foodId: caesarSalad._id,
          name: caesarSalad.name,
          image: caesarSalad.image,
          size: "M",
          quantity: 2,
          price: caesarSalad.price,
          totalPrice: caesarSalad.price * 2,
        }
      ],
      subtotal: pepperoniPizza.price * 1 + caesarSalad.price * 2,
      deliveryFee: 15000,
      serviceFee: Math.round((pepperoniPizza.price * 1 + caesarSalad.price * 2) * 0.1),
      total: pepperoniPizza.price * 1 + caesarSalad.price * 2 + 15000 + Math.round((pepperoniPizza.price * 1 + caesarSalad.price * 2) * 0.1),
      deliveryAddress: "456 Oak Avenue, Ward 2, District 3, Ho Chi Minh City",
      note: "Giao nhanh giúp mình",
      status: "ASSIGNED",
      estimatedDeliveryTime: "15-25 phút",
      restaurantName: pepperoniPizza.restaurantId.name,
      restaurantAddress: pepperoniPizza.restaurantId.address,
      shipperId: new mongoose.Types.ObjectId(),
      shipperName: "Shipper Name",
      createdAt: shiftDays(now, 0),
      updatedAt: shiftDays(now, 0),
    },
    // Another order from Burger Heaven
    {
      orderId: `ORD${Date.now() + 2}${Math.random().toString(36).substr(2, 9).toUpperCase()}`,
      userId: "user789",
      userName: "Bob Johnson",
      userPhone: "0555666777",
      items: [
        {
          foodId: hotDogSpecial._id,
          name: hotDogSpecial.name,
          image: hotDogSpecial.image,
          size: "M",
          quantity: 3,
          price: hotDogSpecial.price,
          totalPrice: hotDogSpecial.price * 3,
        }
      ],
      subtotal: hotDogSpecial.price * 3,
      deliveryFee: 15000,
      serviceFee: Math.round(hotDogSpecial.price * 3 * 0.1),
      total: hotDogSpecial.price * 3 + 15000 + Math.round(hotDogSpecial.price * 3 * 0.1),
      deliveryAddress: "789 Pine Street, Ward 3, District 5, Ho Chi Minh City",
      note: "Giao vào buổi tối",
      status: "DELIVERED",
      estimatedDeliveryTime: "30-40 phút",
      restaurantName: hotDogSpecial.restaurantId.name,
      restaurantAddress: hotDogSpecial.restaurantId.address,
      shipperId: new mongoose.Types.ObjectId(),
      shipperName: "Another Shipper",
      createdAt: shiftDays(now, -2),
      updatedAt: shiftDays(now, -1),
    }
  ];

  const createdOrders = await Order.insertMany(orders);
  console.log("Inserted orders:", createdOrders.map(o => o.orderId));
  console.log("Orders with restaurants:");
  createdOrders.forEach(order => {
    console.log(`- ${order.orderId}: ${order.restaurantName} (${order.restaurantAddress})`);
  });

  await mongoose.disconnect();
  console.log("Disconnected");
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});

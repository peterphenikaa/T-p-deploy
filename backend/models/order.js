const mongoose = require('mongoose');

const OrderItemSchema = new mongoose.Schema({
  foodId: { type: mongoose.Schema.Types.ObjectId, ref: 'Food' },
  name: { type: String, required: true },  
  image: String,

  size: String,   

  quantity: { type: Number, required: true },  
  price: { type: Number, required: true }, 
  totalPrice: { type: Number, required: true },  
});

const OrderSchema = new mongoose.Schema({
  orderId: { type: String, unique: true, required: true },

  userId: { type: String, required: true },  
  userName: { type: String, required: true },  
  userPhone: { type: String, required: true },  

  items: [OrderItemSchema],
  subtotal: { type: Number, required: true },
  deliveryFee: { type: Number, default: 15000 },
  serviceFee: { type: Number, default: 0 },
  total: { type: Number, required: true },
  deliveryAddress: { type: String, required: true },
  note: String,
  status: {
    type: String,
    enum: ['PENDING', 'ASSIGNED', 'PICKED_UP', 'DELIVERING', 'DELIVERED', 'CANCELLED'],
    default: 'PENDING'
  },
  shipperId: { type: mongoose.Schema.Types.ObjectId, ref: 'Login' },
  shipperName: String,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
  estimatedDeliveryTime: String,

  
  restaurantName: String,
  restaurantAddress: String,

}, { timestamps: true });

module.exports = mongoose.model('Order', OrderSchema);


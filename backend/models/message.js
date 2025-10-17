const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  orderId: { type: String, required: true }, // business orderId (e.g., ORD...)
  senderId: { type: String, required: true },
  senderRole: { type: String, enum: ['USER', 'SHIPPER', 'ADMIN'], required: true },
  content: { type: String, required: true },
}, { timestamps: true });

module.exports = mongoose.model('Message', MessageSchema);



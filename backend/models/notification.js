const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  orderId: { type: String, required: true, index: true },
  status: { type: String, required: true },
  message: { type: String, required: true },
  read: { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.model('Notification', NotificationSchema);



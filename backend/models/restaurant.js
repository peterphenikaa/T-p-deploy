const mongoose = require('mongoose');

const ReviewSchema = new mongoose.Schema({
  user: { type: String, required: true },
  rating: { type: Number, required: true, min: 1, max: 5 },
  comment: { type: String, required: true },
}, { timestamps: true });


const RestaurantSchema = new mongoose.Schema({
    name: { type: String, required: true },
    address: { type: String, required: true },
    description: String,
    image: String,
    rating: { type: Number, default: 4.7 },
    deliveryTime: { type: Number, default: 20 },
    categories: [String],
    reviews: [ReviewSchema],
}, { timestamps: true });

module.exports = mongoose.model('Restaurant', RestaurantSchema);

const express = require('express');
const router = express.Router();
const Restaurant = require('../models/restaurant');

router.get('/restaurants', async (req, res) => {
    try {
        const restaurants = await Restaurant.find();
        res.json(restaurants);
    } catch (err) {
        console.error('Error fetching restaurants:', err);
        res.status(500).json({ error: 'Server error khi lấy danh sách nhà hàng' });
    }
});

// Tạo nhà hàng mới
router.post('/restaurants', async (req, res) => {
    try {
        const { name, address, description, image, deliveryTime, categories } = req.body;
        if (!name || !address) {
            return res.status(400).json({ error: 'Thiếu name hoặc address' });
        }
        const r = await Restaurant.create({
            name,
            address,
            description,
            image,
            deliveryTime: deliveryTime || 20,
            categories: Array.isArray(categories) ? categories : [],
        });
        res.status(201).json(r);
    } catch (err) {
        console.error('Error creating restaurant:', err);
        res.status(400).json({ error: 'Lỗi khi tạo nhà hàng' });
    }
});

router.get('/restaurants/:id', async (req, res) => {
    try {
        const restaurant = await Restaurant.findById(req.params.id);
        if (!restaurant) {
            return res.status(404).json({ error: 'Không tìm thấy nhà hàng' });
        }
        res.json(restaurant);
    } catch (err) {
        console.error('Error fetching restaurant details:', err);
        res.status(500).json({ error: 'Server error khi lấy thông tin nhà hàng' });
    }
});

router.get('/restaurants/:id/reviews', async (req, res) => {
    try {
        const restaurant = await Restaurant.findById(req.params.id);
        if (!restaurant) {
            return res.status(404).json({ error: 'Không tìm thấy nhà hàng' });
        }
        
        const reviews = restaurant.reviews.sort((a, b) => 
            new Date(b.createdAt) - new Date(a.createdAt)
        );
        
        res.json(reviews);
    } catch (err) {
        console.error('Error fetching reviews:', err);
        res.status(500).json({ error: 'Server error khi lấy reviews' });
    }
});

router.post('/restaurants/:id/reviews', async (req, res) => {
    try {
        const { user, rating, comment } = req.body;
        
        if (!user || !rating || !comment) {
            return res.status(400).json({ error: 'Thiếu thông tin user, rating hoặc comment' });
        }
        
        if (rating < 1 || rating > 5) {
            return res.status(400).json({ error: 'Rating phải từ 1 đến 5' });
        }

        const restaurant = await Restaurant.findById(req.params.id);
        if (!restaurant) {
            return res.status(404).json({ error: 'Không tìm thấy nhà hàng' });
        }

        restaurant.reviews.push({ user, rating, comment });
        
        const totalRating = restaurant.reviews.reduce((sum, r) => sum + r.rating, 0);
        restaurant.rating = Number((totalRating / restaurant.reviews.length).toFixed(1));
        
        await restaurant.save();
        
        const addedReview = restaurant.reviews[restaurant.reviews.length - 1];
        
        res.status(201).json(addedReview);
    } catch (err) {
        console.error('Error posting review:', err);
        res.status(400).json({ error: 'Lỗi khi thêm đánh giá' });
    }
});

module.exports = router;
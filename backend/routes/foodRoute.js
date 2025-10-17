const express = require('express');
const router = express.Router();
const Food = require('../models/food');

// Escape special regex characters in user input
function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

router.get('/', async (req, res) => {
  try {
    const { category, search, restaurantId } = req.query;

    const filter = {};

    if (category && category.trim() && category.trim().toLowerCase() !== 'tất cả danh mục') {
      // Case-insensitive exact match on category
      filter.category = new RegExp('^' + escapeRegex(category.trim()) + '$', 'i');
    }

    if (search && search.trim()) {
      const q = escapeRegex(search.trim());
      filter.$or = [
        { name: { $regex: q, $options: 'i' } },
        { description: { $regex: q, $options: 'i' } },
        { category: { $regex: q, $options: 'i' } },
      ];
    }

    // Filter by restaurantId if provided
    if (restaurantId && restaurantId.trim()) {
      filter.restaurantId = restaurantId.trim();
    }

    // Debug logs to trace filtering behavior
    console.log('[GET /api/foods] query =', req.query);
    console.log('[GET /api/foods] filter =', JSON.stringify(filter));

    const foods = await Food.find(filter);
    res.json(foods);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const payload = { ...req.body };
    // Tạm thời cho phép thiếu restaurantId vì chỉ có 1 nhà hàng
    if (!payload.restaurantId) {
      delete payload.restaurantId;
    }
    const newFood = new Food(payload);
    await newFood.save();
    res.status(201).json(newFood);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Cập nhật món ăn
router.put('/:id', async (req, res) => {
  try {
    const updated = await Food.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!updated) return res.status(404).json({ error: 'Không tìm thấy món ăn' });
    res.json(updated);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Xóa món ăn
router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Food.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Không tìm thấy món ăn' });
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// GET /api/foods/:id - Get single food item
router.get('/:id', async (req, res) => {
  try {
    const food = await Food.findById(req.params.id);
    if (!food) {
      return res.status(404).json({ error: 'Food not found' });
    }
    res.json(food);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Lấy tất cả review của món ăn
router.get('/:id/reviews', async (req, res) => {
  try {
    const food = await Food.findById(req.params.id);
    if (!food) {
      return res.status(404).json({ error: 'Không tìm thấy món ăn' });
    }
    res.json(food.reviews || []);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Thêm review mới cho món ăn
router.post('/:id/reviews', async (req, res) => {
  try {
    console.log('[POST /api/foods/:id/reviews] incoming body =', req.body);
    const { user, rating, comment } = req.body;
    if (!user || !rating || !comment) {
      return res.status(400).json({ error: 'Thiếu dữ liệu review' });
    }
    const food = await Food.findById(req.params.id);
    if (!food) {
      return res.status(404).json({ error: 'Không tìm thấy món ăn' });
    }
    const review = { user, rating, comment };
    food.reviews = food.reviews || [];
    food.reviews.unshift(review);
    await food.save();
    console.log('[POST /api/foods/:id/reviews] saved review for food', req.params.id);
    res.status(201).json(review);
  } catch (error) {
    console.error('[POST /api/foods/:id/reviews] error=', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

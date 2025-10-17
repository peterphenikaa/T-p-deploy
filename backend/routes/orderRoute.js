const express = require("express");
const router = express.Router();
const mongoose = require('mongoose');
const Order = require('../models/order');
const Food = require('../models/food');
const Restaurant = require('../models/restaurant');
const Notification = require("../models/notification");

// POST /api/orders - Create new order
router.post('/', async (req, res) => {
  try {
    const { userId, userName, userPhone, items, subtotal, deliveryFee, serviceFee, total, deliveryAddress, note, estimatedDeliveryTime } = req.body;
    
    // Validate only the truly required fields; allow optional phone
    if (!userId || !userName || !Array.isArray(items) || items.length === 0 || typeof total !== 'number' || !deliveryAddress) {
      return res.status(400).json({ error: 'Missing required fields (need userId, userName, items[], total, deliveryAddress)' });
    }

    // Get restaurant info from the first food item's restaurantId
    let restaurantName = 'Unknown Restaurant';
    let restaurantAddress = 'Unknown Address';

    if (items && items.length > 0) {
      try {
        // Get the first food item to find restaurantId
        const firstItem = items[0];
        if (firstItem.foodId) {
          const food = await Food.findById(firstItem.foodId);
          if (food && food.restaurantId) {
            const restaurant = await Restaurant.findById(food.restaurantId);
            if (restaurant) {
              restaurantName = restaurant.name;
              restaurantAddress = restaurant.address;
            }
          }
        }
      } catch (err) {
        console.error('Error fetching restaurant info:', err);
        // Use default values if restaurant lookup fails
      }
    }

    const orderId = `ORD${Date.now()}${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
    
    const order = new Order({
      orderId,
      userId,
      userName,
      userPhone,
      items,
      subtotal,
      deliveryFee: deliveryFee || 15000,
      serviceFee: serviceFee || 0,
      total,
      deliveryAddress,
      note,
      status: 'PENDING',
      estimatedDeliveryTime: estimatedDeliveryTime || '20-30 phút',
      restaurantName,
      restaurantAddress,
    });

  await order.save();
    // Notify: order has been created and is waiting for acceptance
    try {
      await createStatusNotification(order, order.status || 'PENDING');
      console.log(`[NOTIFY] Created notification for new order ${order.orderId}`);
    } catch (e) {
      console.error('[NOTIFY] Failed to create notification:', e);
    }
  // Include top-level orderId for compatibility with older frontends
  res.status(201).json({ message: 'Order created', order, orderId: order.orderId });
  } catch (err) {
    console.error('Error creating order:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/orders - Get all orders (with optional status filter)
router.get('/', async (req, res) => {
  try {
    const { status, shipperId, restaurantId, userId } = req.query;
    const baseFilter = {};
    if (status) baseFilter.status = status;
    if (shipperId) baseFilter.shipperId = shipperId;
    if (userId) baseFilter.userId = userId;

    // If restaurantId is provided, orders collection doesn't store restaurantId directly.
    // We need to fetch and filter by items' food.restaurantId similar to other endpoints.
    if (restaurantId) {
      const all = await Order.find(baseFilter).sort({ createdAt: -1 });
      const out = [];
      for (const order of all) {
        if (!order.items || order.items.length === 0) continue;
        let belongs = false;
        for (const item of order.items) {
          if (!item.foodId) continue;
          try {
            const food = await Food.findById(item.foodId).select('restaurantId');
            if (food && food.restaurantId && food.restaurantId.toString() === restaurantId) {
              belongs = true;
              break;
            }
          } catch (_) {}
        }
        if (belongs) out.push(order);
      }
      return res.json(out);
    }

    const orders = await Order.find(baseFilter).sort({ createdAt: -1 });
    res.json(orders);
  } catch (err) {
    console.error('Error fetching orders:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// IMPORTANT: notifications route must come BEFORE '/:id' route
// GET /api/orders/notifications
router.get('/notifications', async (req, res) => {
  try {
    const rows = await Notification.find({}).sort({ createdAt: -1 }).limit(50);
    console.log(`[NOTIFY] Returning ${rows.length} notifications`);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/orders/notifications - clear all notifications
router.delete('/notifications', async (req, res) => {
  try {
    await Notification.deleteMany({});
    res.status(204).send();
  } catch (err) {
    console.error('[NOTIFY] Failed to clear notifications:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/orders/notifications/:id - delete single notification
router.delete('/notifications/:id', async (req, res) => {
  try {
    const deleted = await Notification.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Not found' });
    res.status(204).send();
  } catch (err) {
    console.error('[NOTIFY] Failed to delete notification:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// Chat messages endpoints (must come BEFORE '/:id')
// GET /api/orders/:id/messages?since=ISO
router.get('/:id/messages', async (req, res) => {
  try {
    const orderId = req.params.id;
    const since = req.query.since ? new Date(req.query.since) : null;
    const filter = { orderId };
    if (since && !isNaN(since.getTime())) {
      filter.createdAt = { $gt: since };
    }
    const rows = await require('../models/message')
      .find(filter)
      .sort({ createdAt: 1 })
      .limit(200);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching messages:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/orders/:id/messages
router.post('/:id/messages', async (req, res) => {
  try {
    const orderId = req.params.id;
    const { senderId, senderRole, content } = req.body || {};
    if (!senderId || !senderRole || !content || !content.trim()) {
      return res.status(400).json({ error: 'Missing senderId/senderRole/content' });
    }
    const Message = require('../models/message');
    const doc = await Message.create({ orderId, senderId, senderRole, content: content.trim() });
    res.status(201).json(doc);
  } catch (err) {
    console.error('Error creating message:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/orders/:id - Get order by ID
router.get('/:id', async (req, res) => {
  try {
    const order = await Order.findOne({ orderId: req.params.id });
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json(order);
  } catch (err) {
    console.error('Error fetching order:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

  // PUT /api/orders/:id/assign - Assign shipper to order
router.put('/:id/assign', async (req, res) => {
  try {
    const { shipperId, shipperName } = req.body;
    if (!shipperId || !shipperName) {
      return res.status(400).json({ error: 'Missing shipperId or shipperName' });
    }

    const order = await Order.findOne({ orderId: req.params.id });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    // New flow: restaurant completes -> ASSIGNED; shipper accepts -> PICKED_UP
    if (order.status !== 'ASSIGNED') {
      return res.status(400).json({ error: 'Order must be ASSIGNED before shipper can pick it up' });
    }

    if (!mongoose.Types.ObjectId.isValid(shipperId)) {
      return res.status(400).json({ error: 'Invalid shipperId format' });
    }

    order.shipperId = new mongoose.Types.ObjectId(shipperId);
    order.shipperName = shipperName;
    order.status = 'PICKED_UP';
    order.updatedAt = Date.now();
    await order.save();

    // send notification
    try { await createStatusNotification(order, 'PICKED_UP'); } catch (_) {}
    res.json({ message: 'Order picked up by shipper', order });
  } catch (err) {
    console.error('Error assigning order:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT /api/orders/:id/status - Update order status
router.put('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    if (!status) return res.status(400).json({ error: 'Missing status' });

    const order = await Order.findOne({ orderId: req.params.id });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    // Enforce valid state transitions
    const current = order.status;
    const next = status;
    const can = () => {
      switch (next) {
        case 'ASSIGNED':
          // restaurant completes preparing; only from PENDING
          return current === 'PENDING';
        case 'PICKED_UP':
          // handled by /assign; block direct set here
          return false;
        case 'DELIVERING':
          // only after shipper picked up
          return current === 'PICKED_UP';
        case 'DELIVERED':
          return current === 'DELIVERING';
        case 'CANCELLED':
          return ['PENDING','ASSIGNED','PICKED_UP','DELIVERING'].includes(current);
        default:
          return false;
      }
    };
    if (!can()) {
      return res.status(400).json({ error: `Invalid transition ${current} -> ${next}` });
    }

    order.status = next;
    order.updatedAt = Date.now();
    await order.save();

    // Send notification based on new status
    try {
      await createStatusNotification(order, status);
    } catch (_) {}
    res.json({ message: 'Status updated', order });
  } catch (err) {
    console.error('Error updating status:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// PUT /api/orders/:id/cancel - Cancel order (by user/shipper)
router.put('/:id/cancel', async (req, res) => {
  try {
    const order = await Order.findOne({ orderId: req.params.id });
    if (!order) return res.status(404).json({ error: 'Order not found' });

    order.status = 'CANCELLED';
    order.shipperId = undefined;
    order.shipperName = undefined;
    order.updatedAt = Date.now();
    await order.save();

    res.json({ message: 'Order cancelled', order });
  } catch (err) {
    console.error('Error cancelling order:', err);
    res.status(500).json({ error: 'Server error' });
  }
});
// GET /api/orders/stats/counters
// running = status "ASSIGNED" or "DELIVERING"; requests = status "PENDING"
router.get("/stats/counters", async (req, res) => {
  try {
    const restaurantId = req.query.restaurantId;
    const base = {};
    if (restaurantId) {
      // Find orders by restaurant through food items
      const orders = await Order.find({});
      const filteredOrders = [];
      
      for (const order of orders) {
        if (!order.items || order.items.length === 0) continue;
        
        // Check if any item belongs to the restaurant
        for (const item of order.items) {
          if (item.foodId) {
            const food = await Food.findById(item.foodId);
            if (food && food.restaurantId && food.restaurantId.toString() === restaurantId) {
              filteredOrders.push(order);
              break; // Found a match, no need to check other items
            }
          }
        }
      }
      
      // Đơn đang chạy: chỉ tính ASSIGNED theo yêu cầu dashboard admin
      const running = filteredOrders.filter(order => {
        const s = (order.status || '').toUpperCase();
        return s === 'ASSIGNED';
      }).length;
      
      const requests = filteredOrders.filter(order => {
        const s = (order.status || '').toUpperCase();
        return s === 'PENDING';
      }).length;
      
      return res.json({ running, requests });
    }
    
    const [running, requests] = await Promise.all([
      // Chỉ tính đơn đang chuẩn bị (ASSIGNED)
      Order.countDocuments({ ...base, status: { $in: ["ASSIGNED"] } }),
      Order.countDocuments({ ...base, status: "PENDING" }),
    ]);
    res.json({ running, requests });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// GET /api/orders/stats/revenue
// Query: granularity = daily|weekly|monthly (default daily)
//        days/weeks/months = number of recent periods to include (default 7 for daily)
//        paidOnly = true|false (default true)
router.get("/stats/revenue", async (req, res) => {
  try {
    console.log(`[REVENUE API] Request received: granularity=${req.query.granularity}, restaurantId=${req.query.restaurantId}`);
    
    // Ensure database connection is ready
    if (mongoose.connection.readyState !== 1) {
      console.log(`[REVENUE API] Database not ready, state: ${mongoose.connection.readyState}`);
      // Wait a bit and try again
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    const granularity = (req.query.granularity || "daily").toLowerCase();
    const paidOnly = (req.query.paidOnly || "true").toLowerCase() === "true";

    const match = {};
    // Remove paymentStatus filter since orders don't have this field
    // All orders are considered "paid" by default
    const restaurantId = req.query.restaurantId;
    
    // If restaurantId is provided, we need to filter orders by restaurant through food items
    let ordersToProcess = [];
    if (restaurantId) {
      // For restaurant filtering, get all orders first, then filter by paymentStatus later
      const allOrders = await Order.find({});
      ordersToProcess = [];
      
      for (const order of allOrders) {
        if (!order.items || order.items.length === 0) continue;
        
        // Check if any item belongs to the restaurant
        for (const item of order.items) {
          if (item.foodId) {
            const food = await Food.findById(item.foodId);
            if (food && food.restaurantId && food.restaurantId.toString() === restaurantId) {
              // Include all orders for now (ignore paymentStatus)
              ordersToProcess.push(order);
              break; // Found a match, no need to check other items
            }
          }
        }
      }
    }

    // Get actual date range from orders in database
    let dateRange = { min: null, max: null };
    
    if (restaurantId && ordersToProcess.length > 0) {
      // Use filtered orders for restaurant
      const dates = ordersToProcess.map(order => new Date(order.createdAt));
      dateRange.min = new Date(Math.min(...dates));
      dateRange.max = new Date(Math.max(...dates));
      console.log(`[REVENUE API] Using restaurant filtered data: ${ordersToProcess.length} orders`);
    } else {
      // Get date range from all orders
      const dateAgg = await Order.aggregate([
        { $group: { _id: null, minDate: { $min: "$createdAt" }, maxDate: { $max: "$createdAt" } } }
      ]);
      if (dateAgg.length > 0) {
        dateRange.min = dateAgg[0].minDate;
        dateRange.max = dateAgg[0].maxDate;
        console.log(`[REVENUE API] Date range from DB: ${dateRange.min?.toISOString()} to ${dateRange.max?.toISOString()}`);
      } else {
        console.log(`[REVENUE API] No orders found in database`);
      }
    }

    // If no orders found, use current date
    if (!dateRange.min || !dateRange.max) {
      const now = new Date();
      dateRange.min = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6, 0, 0, 0, 0);
      dateRange.max = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);
      console.log(`[REVENUE API] No orders found, using current date range: ${dateRange.min.toISOString()} to ${dateRange.max.toISOString()}`);
    }

    if (granularity === "daily") {
      // Get the last 7 days from the actual data range
      const labels = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
      const out = [];
      
      // Start from the most recent date in data
      const endDate = new Date(dateRange.max);
      endDate.setHours(23, 59, 59, 999); // End of day
      
      for (let i = 6; i >= 0; i--) {
        const d0 = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate() - i, 0, 0, 0, 0);
        const d1 = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate() - i + 1, 0, 0, 0, 0);
        let sum = 0;
        if (restaurantId && ordersToProcess.length > 0) {
          // Calculate sum from filtered orders
          sum = ordersToProcess
            .filter(order => {
              const orderDate = new Date(order.createdAt);
              // Proper date comparison - check if order date is within the day range
              return orderDate >= d0 && orderDate < d1;
            })
            .reduce((total, order) => total + (order.totalAmount || order.total || 0), 0);
        } else {
          const sumRows = await Order.aggregate([
            { $match: { createdAt: { $gte: d0, $lt: d1 } } },
            { $group: { _id: null, totalAmount: { $sum: "$total" } } },
          ]);
          sum = sumRows.length ? sumRows[0].totalAmount : 0;
        }
        const tooltip = `${String(d0.getDate()).padStart(2, "0")}/${String(d0.getMonth() + 1).padStart(2, "0")}/${d0.getFullYear()}`;
        out.push({ period: labels[i], total: sum, tooltip });
      }
      console.log(`[REVENUE API] Daily result:`, out.map(item => `${item.period}: ${item.total}`).join(', '));
      return res.json({ series: out });
    }

    if (granularity === "weekly") {
      // Use the month containing the most recent order
      const firstOfMonth = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth(), 1, 0, 0, 0, 0);
      const nextMonth = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth() + 1, 1, 0, 0, 0, 0);
      const out = [];
      let cursor = new Date(firstOfMonth);
      // align to Monday of the week containing the 1st
      const day = cursor.getDay();
      const diffToMon = (day + 6) % 7; // 0=>Mon
      cursor.setDate(cursor.getDate() - diffToMon);
      for (let idx = 0; idx < 4; idx++) {
        const weekStart = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate(), 0, 0, 0, 0);
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekStart.getDate() + 7); // exclusive end
        const startClamped = new Date(Math.max(weekStart.getTime(), firstOfMonth.getTime()));
        const endClampedExclusive = new Date(Math.min(weekEnd.getTime(), nextMonth.getTime()));

        let sum = 0;
        if (restaurantId && ordersToProcess.length > 0) {
          // Calculate sum from filtered orders
          sum = ordersToProcess
            .filter(order => {
              const orderDate = new Date(order.createdAt);
              return orderDate >= startClamped && orderDate < endClampedExclusive;
            })
            .reduce((total, order) => total + (order.totalAmount || order.total || 0), 0);
        } else {
          const sumRows = await Order.aggregate([
            { $match: { createdAt: { $gte: startClamped, $lt: endClampedExclusive } } },
            { $group: { _id: null, totalAmount: { $sum: "$total" } } },
          ]);
          sum = sumRows.length ? sumRows[0].totalAmount : 0;
        }

        const endInclusive = new Date(endClampedExclusive.getTime() - 24 * 60 * 60 * 1000);
        const tooltip = `${String(startClamped.getDate()).padStart(2, "0")} - ${String(endInclusive.getDate()).padStart(2, "0")}/${String(endInclusive.getMonth() + 1).padStart(2, "0")}/${endInclusive.getFullYear()}`;
        out.push({ period: `Tuần ${idx + 1}`, total: sum, tooltip });
        cursor.setDate(cursor.getDate() + 7);
        if (cursor >= nextMonth) break;
      }
      return res.json({ series: out });
    }

    // monthly: last 6 months from the most recent order
    const startMonth = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth() - 4, 1, 0, 0, 0, 0); // last 5 months
    const out = [];
    
    if (restaurantId && ordersToProcess.length > 0) {
      // Use filtered orders for restaurant
      for (let i = 4; i >= 0; i--) {
        const m = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth() - i, 1, 0, 0, 0, 0);
        const nextMonth = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth() - i + 1, 1, 0, 0, 0, 0);
        
        const sum = ordersToProcess
          .filter(order => {
            const orderDate = new Date(order.createdAt);
            return orderDate >= m && orderDate < nextMonth;
          })
          .reduce((total, order) => total + (order.totalAmount || order.total || 0), 0);
        
        const label = `${String(m.getMonth() + 1).padStart(2, "0")}/${m.getFullYear()}`;
        const tooltip = label; // mm/yyyy
        out.push({ period: label, total: sum, tooltip });
      }
    } else {
      // Use aggregation for general case
      const pipeline = [
        { $match: { createdAt: { $gte: startMonth } } },
        { $addFields: { month: { $dateTrunc: { date: "$createdAt", unit: "month" } } } },
        { $group: { _id: "$month", totalAmount: { $sum: "$total" } } },
        { $sort: { _id: 1 } },
      ];
      const rows = await Order.aggregate(pipeline);
      
      for (let i = 4; i >= 0; i--) {
        const m = new Date(dateRange.max.getFullYear(), dateRange.max.getMonth() - i, 1);
        const found = rows.find((r) => {
          const d = new Date(r._id);
          return d.getFullYear() === m.getFullYear() && d.getMonth() === m.getMonth();
        });
        const label = `${String(m.getMonth() + 1).padStart(2, "0")}/${m.getFullYear()}`;
        const tooltip = label; // mm/yyyy
        out.push({ period: label, total: found ? found.totalAmount : 0, tooltip });
      }
    }
    return res.json({ series: out });
  } catch (err) {
    console.error(`[REVENUE API] Error:`, err);
    
    // Return empty data structure instead of error to prevent frontend issues
    const emptyResponse = {
      series: [
        { period: "T2", total: 0, tooltip: "Không có dữ liệu" },
        { period: "T3", total: 0, tooltip: "Không có dữ liệu" },
        { period: "T4", total: 0, tooltip: "Không có dữ liệu" },
        { period: "T5", total: 0, tooltip: "Không có dữ liệu" },
        { period: "T6", total: 0, tooltip: "Không có dữ liệu" },
        { period: "T7", total: 0, tooltip: "Không có dữ liệu" },
        { period: "CN", total: 0, tooltip: "Không có dữ liệu" }
      ]
    };
    
    res.status(200).json(emptyResponse);
  }
});

// GET /api/orders/stats/top-foods?limit=3
// Returns top N foods by aggregated ordered quantity from PAID orders
router.get("/stats/top-foods", async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(parseInt(req.query.limit) || 3, 10));
    const restaurantId = req.query.restaurantId;
    
    if (restaurantId) {
      // Filter orders by restaurant through food items
      const allOrders = await Order.find({});
      const filteredOrders = [];
      
      for (const order of allOrders) {
        if (!order.items || order.items.length === 0) continue;
        
        // Check if any item belongs to the restaurant
        for (const item of order.items) {
          if (item.foodId) {
            const food = await Food.findById(item.foodId);
            if (food && food.restaurantId && food.restaurantId.toString() === restaurantId) {
              // Include all orders for now
              filteredOrders.push(order);
              break; // Found a match, no need to check other items
            }
          }
        }
      }
      
      // Count food quantities
      const foodCounts = {};
      filteredOrders.forEach(order => {
        order.items.forEach(item => {
          if (item.foodId) {
            const foodId = item.foodId.toString();
            foodCounts[foodId] = (foodCounts[foodId] || 0) + item.quantity;
          }
        });
      });
      
      // Get top foods
      const sortedFoods = Object.entries(foodCounts)
        .sort(([,a], [,b]) => b - a)
        .slice(0, limit);
      
      // Get food details
      const result = [];
      for (const [foodId, totalQuantity] of sortedFoods) {
        const food = await Food.findById(foodId);
        if (food) {
          result.push({
            id: food._id,
            name: food.name,
            image: food.image,
            price: food.price,
            category: food.category,
            restaurantId: food.restaurantId,
            totalQuantity
          });
        }
      }
      
      return res.json(result);
    }
    
    // Original logic for all restaurants
    const pipeline = [
      { $match: {} }, // Remove paymentStatus filter
      { $unwind: "$items" },
      { $group: { _id: { $ifNull: ["$items.food", "$items.foodId"] }, totalQuantity: { $sum: "$items.quantity" } } },
      { $sort: { totalQuantity: -1 } },
      { $limit: limit },
      {
        $lookup: {
          from: "foods",
          localField: "_id",
          foreignField: "_id",
          as: "food"
        }
      },
      { $unwind: "$food" },
      {
        $project: {
          _id: 0,
          id: "$food._id",
          name: "$food.name",
          image: "$food.image",
          price: "$food.price",
          category: "$food.category",
          restaurantId: "$food.restaurantId",
          totalQuantity: 1
        }
      }
    ];
    const rows = await Order.aggregate(pipeline);
    return res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});
// Simple endpoints to list notifications
// GET /api/orders/notifications
// moved earlier

// Helper to create notification when an order status changes
async function createStatusNotification(order, newStatus) {
  try {
    // Human-readable messages per status
    let message = '';
    switch (newStatus) {
      case 'PENDING':
        message = `Đơn ${order.orderId} đã được đặt và đang chờ chấp nhận`;
        break;
      case 'ASSIGNED':
        message = `Đã chấp nhận đơn ${order.orderId}, nhà hàng đang chuẩn bị`;
        break;
      case 'PICKED_UP':
        message = `Shipper đã nhận đơn ${order.orderId} tại nhà hàng`;
        break;
      case 'DELIVERING':
        message = `Đơn ${order.orderId} đã hoàn thành chuẩn bị và bàn giao cho shipper`;
        break;
      case 'DELIVERED':
        message = `Đơn ${order.orderId} đã giao thành công`;
        break;
      case 'CANCELLED':
        message = `Đơn ${order.orderId} đã bị hủy`;
        break;
      default:
        message = `Đơn ${order.orderId} đã chuyển sang trạng thái ${newStatus}`;
    }
    await Notification.create({ orderId: order.orderId, status: newStatus, message });
  } catch (_) {}
}

module.exports = router;

const mongoose = require('mongoose');
const Restaurant = require('./models/restaurant'); // đúng tên file restaurant.js

mongoose.connect('mongodb://localhost:27017/FoodDeliveryApp')
  .then(async () => {
    // Danh sách 4 nhà hàng mẫu, mỗi nhà hàng có 1-2 review
    const restaurants = [
      {
        name: 'The Pizza Place',
        address: '123 Main St',
        description: 'Pizza ngon nổi tiếng với công thức độc quyền.',
        image: 'homepageUser/pizza_place.jpg',
        rating: 4.8,
        deliveryTime: 30,
        categories: ['Pizza', 'Drinks'],
        reviews: [
          { user: 'Alice', rating: 5, comment: 'Pizza ngon tuyệt vời!' },
          { user: 'Bob', rating: 4, comment: 'Phục vụ tốt, đồ ăn ngon.' }
        ]
      },
      {
        name: 'Burger Heaven',
        address: '456 Burger Road',
        description: 'Burger thơm ngon, tươi mới.',
        image: 'homepageUser/burger_heaven.webp',
        rating: 4.5,
        deliveryTime: 25,
        categories: ['Burger', 'Fries'],
        reviews: [
          { user: 'Charlie', rating: 5, comment: 'Burger tuyệt vời!' }
        ]
      },
      {
        name: 'Sushi World',
        address: '789 Sushi Blvd',
        description: 'Sushi tươi ngon, chất lượng cao.',
        image: 'homepageUser/sushi_word.jpg',
        rating: 4.9,
        deliveryTime: 40,
        categories: ['Sushi', 'Japanese'],
        reviews: []
      },
      {
        name: 'Salad Fresh',
        address: '321 Green Ave',
        description: 'Salad tươi ngon, lành mạnh.',
        image: 'homepageUser/salad_fresh.jpg',
        rating: 4.3,
        deliveryTime: 20,
        categories: ['Salad', 'Healthy'],
        reviews: [
          { user: 'David', rating: 3, comment: 'Salad hơi nhạt.' },
          { user: 'Eva', rating: 4, comment: 'Rất thích salad ở đây.' }
        ]
      }
    ];

    // Xóa dữ liệu cũ để seed lại nếu muốn
    await Restaurant.deleteMany({});
    await Restaurant.insertMany(restaurants);

    console.log('Seeding restaurants completed!');
    mongoose.disconnect();
  })
  .catch(err => {
    console.error('Error seeding restaurants:', err);
    mongoose.disconnect();
  });
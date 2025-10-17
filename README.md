# 🍔 Food Delivery App

[![Flutter](https://img.shields.io/badge/Flutter-3.9.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-16.0+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-4.4+-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://mongodb.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

Một ứng dụng giao đồ ăn trực tuyến hoàn chỉnh với Flutter frontend và Node.js backend, kết nối User, Chef và Shipper với trải nghiệm realtime đầy đủ.

> 📋 **Xem báo cáo đầy đủ**: [Báo cáo bài tập lớn Kĩ Thuật Phần Mềm - Food Delivery App](https://docs.google.com/document/d/1UKzzk9Ut9GU6Quh3QzpFtDKEdpyo0j8d/edit)  
> 📱 **Demo ứng dụng**: Tất cả screenshots và demo được trình bày chi tiết trong **Chương 5** của báo cáo

## 📱 Tổng quan

Dự án Food Delivery App mô phỏng quy trình đặt món – nấu – giao với các tính năng:
- Quản lý tài khoản User, Chef và Shipper
- Quản lý sản phẩm, giỏ hàng và thanh toán
- Chat thời gian thực giữa khách hàng và Shipper
- Cập nhật vị trí Shipper trên bản đồ realtime
- Thiết kế giao diện tham khảo từ Figma

## 🛠️ Công nghệ sử dụng

### Frontend
- **Flutter** 3.9.0+ (Dart SDK)
- **Provider** - State management
- **HTTP** - API calls
- **Shared Preferences** - Local storage
- **Geolocator** - Location services
- **Permission Handler** - Device permissions

### Backend
- **Node.js** + **Express.js**
- **MongoDB** - Database
- **Redis** - Caching
- **CORS** - Cross-origin requests
- **Mongoose** - ODM

## 🚀 Cài đặt và chạy dự án

### Yêu cầu hệ thống

- **Node.js** 16.0+ 
- **Flutter** 3.9.0+
- **MongoDB** 4.4+
- **Redis** 6.0+ (optional)
- **Git**

### 1. Clone repository

```bash
git clone <repository-url>
cd Food-Delivery-App
```

### 2. Cài đặt Backend

```bash
cd backend
npm install
```

#### Cấu hình môi trường

Tạo file `.env` trong thư mục `backend`:

```env
# Database
MONGO_URL=mongodb://localhost:27017/FoodDeliveryApp
# hoặc MongoDB Atlas
# MONGO_URL=mongodb+srv://username:password@cluster.mongodb.net/FoodDeliveryApp

# Redis (optional)
REDIS_URL=redis://localhost:6379

# Server
PORT=3000
```

#### Chạy Backend

```bash
# Development mode
npm run dev

# Production mode
npm start

# Seed dữ liệu mẫu
npm run seed
```

Backend sẽ chạy tại: `http://localhost:3000`

### 3. Cài đặt Frontend

```bash
cd frontend
flutter pub get
```

#### Chạy Frontend

```bash
# Chạy trên web
flutter run -d chrome

# Chạy trên Android
flutter run

# Chạy trên iOS
flutter run -d ios
```

## 🎯 Tính năng chính

### 👤 Quản lý tài khoản
- Đăng ký/Đăng nhập cho User, Chef, Shipper
- Quản lý profile và địa chỉ
- Phân quyền theo vai trò

### 🏪 Quản lý nhà hàng & món ăn
- Danh sách nhà hàng với rating và thời gian giao
- Tìm kiếm món ăn theo tên, danh mục
- Chi tiết món ăn với hình ảnh, mô tả, đánh giá
- Quản lý món ăn cho Chef

### 🛒 Giỏ hàng & Thanh toán
- Thêm/sửa/xóa món trong giỏ hàng
- Tính toán phí giao hàng và phí dịch vụ
- Thanh toán an toàn
- Lưu trữ giỏ hàng local

### 📦 Quản lý đơn hàng
- Tạo đơn hàng từ giỏ hàng
- Theo dõi trạng thái đơn hàng realtime
- Gán shipper cho đơn hàng
- Cập nhật vị trí giao hàng

### 🗺️ Dịch vụ vị trí
- Lấy vị trí hiện tại
- Tìm kiếm địa chỉ
- Chuyển đổi tọa độ ↔ địa chỉ
- Quản lý nhiều địa chỉ giao hàng

### 💬 Chat & Thông báo
- Chat realtime giữa khách hàng và shipper
- Thông báo trạng thái đơn hàng
- Cập nhật vị trí shipper trên bản đồ

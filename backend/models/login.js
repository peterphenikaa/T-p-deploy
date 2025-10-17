const mongoose = require("mongoose");

const AddressSchema = new mongoose.Schema(
  {
    houseNumber: { type: String, required: true },
    ward: { type: String, required: true },
    city: { type: String, required: true },
  },
  { _id: false }
// Nghĩa là trong MongoDB document của bạn sẽ không có _id cho từng address con, 
// mà chỉ có _id cho document cha (Login)
);

const LoginSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: { type: String, required: true },
    name: { type: String, required: true },
    phoneNumber: { type: String, required: true },
    role: { type: String, enum: ['user', 'shipper', 'admin'], default: 'user' },
    address: { type: AddressSchema, required: true },
  },
  { timestamps: true }
);
// trim: true 
// tự động loại bỏ khoảng trắng ở đầu và cuối khi lưu vào database.
// { timestamps: true }
// Khi bật option này, Mongoose sẽ tự động thêm 2 field vào document:
// createdAt: thời gian tạo document.
// updatedAt: thời gian sửa document lần cuối.

module.exports = mongoose.model("Login", LoginSchema);
// Trong MongoDB collection sẽ được đặt tên mặc định là logins 
// (Mongoose tự chuyển chữ cái đầu thành thường và thêm s vào).

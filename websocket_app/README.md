# WebSocket Flutter App với Hiển Thị Ảnh

Ứng dụng Flutter chuyên biệt để nhận và hiển thị ảnh JPEG được mã hóa base64 từ WebSocket server.

## 🚀 Tính năng chính

- ✅ **Kết nối WebSocket realtime** tới URL cấu hình qua `--dart-define=WS_URL=...` (mặc định `ws://10.0.2.2:8765`)
- ✅ **Tự động giải mã Base64** thành ảnh JPEG
- ✅ **Hiển thị ảnh trực tiếp** trong giao diện chat
- ✅ **Nhận diện JSON** và tự động parse dữ liệu
- ✅ **Xem ảnh full size** với dialog popup
- ✅ **Timestamp** cho mỗi tin nhắn
- ✅ **Quản lý kết nối** linh hoạt

## 📱 Giao diện

### Các loại tin nhắn:
- 🔵 **Xanh dương**: Tin nhắn/ảnh nhận từ server
- 🟢 **Xanh lá**: Tin nhắn gửi đi
- ⚪ **Xám**: Tin nhắn hệ thống (kết nối, lỗi...)
- 🖼️ **Ảnh với thumbnail**: Ảnh được giải mã từ base64

### Chức năng:
- **Xem ảnh lớn**: Click vào thumbnail hoặc nút "Xem ảnh lớn"
- **Timestamp**: Hiển thị thời gian nhận tin nhắn
- **Auto-scroll**: Tự động cuộn đến tin nhắn mới nhất
- **Clear messages**: Xóa tất cả tin nhắn

## 🔧 Cách hoạt động

### JSON Processing:
```json
{
  "image": "iVBORw0KGgoAAAANSUhEUgAA...", // Base64 JPEG
  "timestamp": 1234567890,
  "other_data": "..."
}
```

### Flow xử lý:
1. **Nhận WebSocket message** → Parse JSON
2. **Tìm base64 image** → Kiểm tra các field như "image", "data", "frame"
3. **Validate base64** → Kiểm tra format và độ dài
4. **Decode base64** → Chuyển thành Uint8List
5. **Hiển thị ảnh** → Render với Image.memory()

## 🛠️ Cài đặt và chạy

```bash
# Clone project
cd websocket_app

# Cài đặt dependencies
flutter pub get

# Chạy ứng dụng
flutter run
# Chọn [2] Chrome để test WebSocket
```

## 📦 Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  web_socket_channel: ^2.4.0  # WebSocket connectivity
  # dart:convert - JSON parsing
  # dart:typed_data - Binary data handling
```

## 🔍 Troubleshooting

### Không nhận được ảnh?
- ✅ Kiểm tra server đang gửi JSON với field chứa base64
- ✅ Xem console log để debug JSON structure
- ✅ Đảm bảo base64 string đủ dài (>1000 chars)

### Ảnh không hiển thị?
- ✅ Kiểm tra format base64 có đúng không
- ✅ Xem error message trong console
- ✅ Thử với ảnh JPEG chuẩn

### Kết nối WebSocket lỗi?
- ✅ Kiểm tra URL server có đúng không
- ✅ Đảm bảo server đang chạy
- ✅ Test với WebSocket client khác

## 📝 Customization

### Thay đổi WebSocket URL:
Không cần sửa code, truyền URL khi chạy hoặc build:
```bash
flutter run --dart-define=WS_URL=wss://your-server.com/
flutter build apk --dart-define=WS_URL=wss://your-server.com/
```

### Tùy chỉnh detection base64:
```dart
bool _isBase64Image(String data) {
  // Thay đổi logic detection theo nhu cầu
  return data.length > 1000 && /* your logic */;
}
```

### Thêm field JSON khác:
```dart
// Trong _processMessage(), thêm field cần tìm:
for (String key in ['image', 'data', 'frame', 'photo']) {
  // ... logic detection
}
```

## 🎯 Use Cases

- **Live camera streaming** từ IoT devices
- **Real-time image processing** results
- **Security camera feeds** qua WebSocket
- **AI model outputs** (computer vision)
- **Medical imaging** real-time transmission

## 🔄 Workflow Example

1. **Server gửi JSON**:
   ```json
   {"frame": "/9j/4AAQSkZJRgABAQEA...", "timestamp": 1675934023}
   ```

2. **App nhận và parse**:
   ```
   ✅ Detect JSON format
   ✅ Find base64 in "frame" field  
   ✅ Validate base64 (length > 1000)
   ✅ Decode to image bytes
   ```

3. **Hiển thị**:
   ```
   📱 Show thumbnail in chat
   🖼️ Full size on tap
   ⏰ Add timestamp
   ```

---

**Lưu ý**: Ứng dụng được tối ưu cho việc nhận ảnh JPEG base64 từ WebSocket server, đặc biệt phù hợp cho live streaming và real-time image processing.

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

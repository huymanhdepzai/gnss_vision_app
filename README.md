# GNSS-Vision Navigation Assistant (DATN Project)


## 🌟 Tính năng cốt lõi

### 1. Bản đồ & Dẫn đường (Map Module)
*   **Tích hợp Goong Maps & Mapbox:** Hiển thị bản đồ mượt mà, hỗ trợ tìm kiếm địa điểm (Autocomplete) và lấy chi tiết địa điểm.
*   **Dẫn đường thời gian thực:** Lấy dữ liệu lộ trình từ Goong Direction API và vẽ polyline trực quan.
*   **Tương tác thông minh:** Chế độ xem Explore và Navigation linh hoạt, tự động xoay camera theo hướng di chuyển.

### 2. Hệ thống Thị giác máy tính (Vision Module)
*   **Optical Flow (Lucas-Kanade):** Theo dõi chuyển động của các điểm đặc trưng trên mặt đường để tính toán vector di chuyển (Visual Odometry).
*   **YOLOv8 Object Detection:** Nhận diện phương tiện (ô tô, xe máy, xe buýt, xe tải) và người đi bộ trong thời gian thực.
*   **Cảnh báo vùng nguy hiểm:** Tự động tạo "vùng cấm" (Forbidden Zones) xung quanh các vật thể do AI phát hiện để loại bỏ nhiễu cho hệ thống điều hướng.

### 3. Bộ lọc hợp nhất cảm biến (Sensor Fusion)
*   **Adaptive Kalman-like Filter:** Hợp nhất dữ liệu từ GPS (Heading/Speed), IMU (Accelerometer) và Vision (Optical Flow).
*   **Trọng số động:** Tự động ưu tiên Vision khi tín hiệu GPS yếu (trong hầm, đô thị dày đặc) và ưu tiên GPS khi điều kiện ánh sáng kém.

## 🚀 Tối ưu hóa hiệu năng (Performance Optimization)

Để đảm bảo ứng dụng chạy mượt mà trên thiết bị di động với các thuật toán nặng, dự án đã áp dụng các kỹ thuật:

*   **Surgical UI Rebuilds:** Sử dụng `ValueNotifier` và `ValueListenableBuilder` để chỉ vẽ lại (re-render) đúng khu vực chứa video và HUD, tránh rebuild toàn bộ màn hình mỗi frame (30fps).
*   **Downscaling & Encoding:** Nguồn video được nén xuống độ phân giải **240px** và chất lượng JPEG **50%** để giảm tải cho CPU khi giải mã và xử lý OpenCV.
*   **AI Throttling:** Chạy nhận diện YOLOv8 mỗi **10 frame** và áp dụng kỹ thuật "ghi nhớ vật thể" để giữ an toàn trong các frame trung gian.
*   **Smart Frame Skipping:** Thuật toán tự động bỏ qua các frame video nếu tốc độ xử lý của phần cứng không đuổi kịp tốc độ phát thực tế.
*   **Memory Management:** Quản lý nghiêm ngặt bộ nhớ đệm OpenCV (Mat objects), đảm bảo `dispose()` ngay lập tức sau khi sử dụng để tránh rò rỉ bộ nhớ (Memory Leak).

## 🛠 Công nghệ sử dụng

*   **Ngôn ngữ:** Dart (Flutter Framework)
*   **Thị giác máy tính:** `opencv_dart` (FFI binding)
*   **Trí tuệ nhân tạo:** `flutter_vision` (TFLite YOLOv8)
*   **Bản đồ:** `mapbox_maps_flutter`, Goong API
*   **Cảm biến:** `geolocator`, `sensors_plus`

## 📂 Cấu trúc thư mục chính

```text
lib/
├── controllers/    # Xử lý Logic và điều khiển luồng dữ liệu (FlowController)
├── fusion/         # Thuật toán hợp nhất cảm biến (SensorFusion)
├── screens/        # Giao diện người dùng (Map, Vision HUD)
├── vision/         # Lõi xử lý OpenCV (CVCore)
└── widgets/        # Các thành phần giao diện tùy chỉnh (FlowPainter)
```

## ⚙️ Cài đặt

1.  Cài đặt Flutter SDK (^3.10.4).
2.  Cấu hình API Key của Goong và Mapbox trong file `.env`.
3.  Đảm bảo file model `yolov8n.tflite` và `labels.txt` nằm trong thư mục `assets/`.
4.  Chạy lệnh: `flutter pub get` và `flutter run`.

---
*Dự án được thực hiện phục vụ cho mục đích Đồ án tốt nghiệp (DATN).*

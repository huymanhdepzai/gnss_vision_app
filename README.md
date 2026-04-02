# GNSS-Vision Navigation Assistant (DATN Project)

Hệ thống hỗ trợ dẫn đường thông minh tích hợp đa cảm biến (Multi-sensor Fusion), kết hợp dữ liệu vệ tinh GNSS, cảm biến quán tính (IMU) và Thị giác máy tính (Computer Vision) để cung cấp giải pháp điều hướng chính xác trong các môi trường đô thị phức tạp.

---

## Tính năng cốt lõi (Core Features)

### 1. Hệ thống Bản đồ & Dẫn đường Thông minh
*   **Hybrid Map Engine:** Tích hợp **Mapbox Maps SDK** cho khả năng hiển thị vector mượt mà và **Goong API** để tối ưu hóa dữ liệu tìm kiếm, định tuyến (Routing) tại thị trường Việt Nam.
*   **Chế độ xem AR Navigation:** Hỗ trợ la bàn AR thời gian thực, tự động cập nhật góc xoay (Bearing) và độ nghiêng (Tilt) dựa trên hướng di chuyển thực tế.
*   **Hệ thống Tìm kiếm (POI):** Tích hợp Autocomplete gợi ý địa điểm và lấy chi tiết tọa độ chính xác từ Goong Detail API.

### 2. Thị giác máy tính & AI (Vision Module)
*   **Visual Odometry (Optical Flow):** Sử dụng thuật toán **Lucas-Kanade** (qua OpenCV) để theo dõi các điểm đặc trưng (Features) trên mặt đường. Hệ thống tính toán vector di chuyển để bù đắp sai số hướng khi tín hiệu GPS bị nhiễu.
*   **Nhận diện vật thể YOLOv8:** Tích hợp mô hình YOLOv8n (Nano) chạy trên TFLite để nhận diện thời gian thực các đối tượng: ô tô, xe máy, xe buýt, xe tải, người đi bộ và xe đạp.
*   **Vùng cấm động (Dynamic Forbidden Zones):** Tự động tạo các Mask bảo vệ xung quanh vật thể AI phát hiện. Điều này loại bỏ các điểm đặc trưng chuyển động (như xe phía trước) khỏi thuật toán Optical Flow, đảm bảo chỉ tính toán dựa trên các vật thể tĩnh (mặt đường).

### 3. Bộ lọc Hợp nhất Cảm biến (Sensor Fusion)
*   **Adaptive Weighting Filter:** Thuật toán tự động điều chỉnh trọng số tin cậy (Confidence Weight). Khi độ chính xác GPS thấp (Accuracy > 15m), hệ thống sẽ ưu tiên dữ liệu từ Vision.
*   **Xử lý rung chấn IMU:** Tích hợp bộ lọc gia tốc kế để phát hiện các biến động đột ngột (như đi qua ổ gà hoặc phanh gấp), giúp làm mượt dữ liệu hướng (Heading) và vận tốc.

### 4. Giám sát Vệ tinh 3D (GNSS Visualization)
*   **3D Globe UI:** Hiển thị vị trí thực tế của các chòm sao vệ tinh (GPS, GLONASS, Galileo, BeiDou) trên quả địa cầu 3D tương tác.
*   **Skyplot Radar:** Biểu đồ radar hiển thị góc ngẩng, góc phương vị và cường độ tín hiệu (SNR/CNo) của từng vệ tinh trong tầm nhìn.

---

## Tối ưu hóa hiệu năng (Performance Optimization)

Để xử lý đồng thời AI, OpenCV và Map trên thiết bị di động, dự án áp dụng các kỹ thuật:

*   **Kiến trúc Đa luồng (Flutter Isolates):** Tách biệt luồng UI chính và luồng xử lý video (Worker Isolate). Dữ liệu ảnh thô được truyền qua `SendPort/ReceivePort` để tính toán OpenCV mà không gây "jank" giao diện.
*   **Surgical UI Rebuilds:** Sử dụng `ValueNotifier` và `ValueListenableBuilder` để chỉ vẽ lại các widget nhỏ (như chỉ số tốc độ, hướng, frame video) thay vì rebuild toàn bộ màn hình mỗi 33ms.
*   **AI Throttling & Memory Management:** 
    *   Chạy nhận diện AI mỗi 10 frame thay vì mọi frame để tiết kiệm pin.
    *   Sử dụng cơ chế `dispose()` nghiêm ngặt cho đối tượng `cv.Mat` trong OpenCV để tránh rò rỉ bộ nhớ (Memory Leak).
*   **Video Downscaling:** Luồng video được nén xuống độ phân giải **240p** và chất lượng JPEG **50%** trước khi đưa vào Isolate để giảm tải cho CPU khi giải mã.

---

## Công nghệ sử dụng (Tech Stack)

*   **Framework:** Flutter (Dart) - Hỗ trợ đa nền tảng.
*   **Computer Vision:** `opencv_dart` (FFI bindings cho OpenCV C++).
*   **AI/Deep Learning:** `flutter_vision` (TFLite engine), Model YOLOv8n.
*   **Map Services:** `mapbox_maps_flutter`, Goong Direction & Place API.
*   **Sensors:** `geolocator` (GPS), `sensors_plus` (Accelerometer/IMU).
*   **Graphics:** `flutter_earth_globe` (Render 3D WebGL).

---

## Cấu trúc dự án (Project Structure)

```text
lib/
├── controllers/    # FlowController: Quản lý Isolate, vòng đời Video và dữ liệu cảm biến
├── fusion/         # SensorFusion: Thuật toán hợp nhất dữ liệu GPS/IMU/Vision
├── screens/        # Giao diện chính: MapHome, Vision (FlowScreen), SatelliteView
├── vision/         # CVCore: Lõi xử lý OpenCV, Optical Flow và Forbidden Zones
├── widgets/        # FlowPainter: Vẽ HUD, Bounding Box AI và điểm đặc trưng
└── main.dart       # Khởi tạo ứng dụng và cấu hình quyền (Permissions)
```

---

##  Cài đặt & Triển khai (Installation)

### 1. Yêu cầu hệ thống
*   Flutter SDK: `^3.10.4`
*   Android API Level: `24` (Nougat) trở lên.
*   Thiết bị vật lý (Yêu cầu để chạy Camera và GPS).

### 2. Cấu hình Môi trường
Tạo file `.env` tại thư mục gốc và cấu hình các mã API:
```env
MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
GOONG_API_KEY=your_goong_api_key_here
GOONG_MAPTILES_KEY=your_goong_maptiles_key_here
```

### 3. Chuẩn bị Assets
Đảm bảo các file sau đã có trong thư mục `assets/`:
*   `yolov8n.tflite` (Model AI)
*   `labels.txt` (Danh sách nhãn vật thể)

### 4. Chạy ứng dụng
```bash
# Lấy các thư viện phụ thuộc
flutter pub get

# Chạy trên thiết bị (Debug mode)
flutter run
```

---

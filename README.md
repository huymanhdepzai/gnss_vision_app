# GNSS-Vision Navigation Assistant (DATN Project)

Hệ thống hỗ trợ dẫn đường thông minh tích hợp đa cảm biến (Multi-sensor Fusion), kết hợp dữ liệu vệ tinh GNSS, cảm biến quán tính (IMU) và Thị giác máy tính (Computer Vision) để cung cấp giải pháp điều hướng chính xác trong các môi trường đô thị phức tạp.

---

## Tính năng cốt lõi (Core Features)

### 1. Hệ thống Bản đồ & Dẫn đường Thông minh (Map & Navigation)
*   **Hybrid Map Engine:** Tích hợp **Mapbox Maps SDK** cho khả năng hiển thị vector mượt mà và **Goong API** để tối ưu hóa dữ liệu tìm kiếm, định tuyến (Routing) tại thị trường Việt Nam.
*   **Static Map & Day/Night Scene:** Hỗ trợ bản đồ tĩnh và giao diện tự động chuyển đổi sáng/tối theo thời gian thực.
*   **Hệ thống Tìm kiếm (POI):** Tích hợp Autocomplete gợi ý địa điểm và lấy chi tiết tọa độ chính xác từ Goong Search & Directions API.
*   **Trợ lý ảo thông minh (Chat Assistant):** Giao diện tương tác Chat Assistant Overlay hỗ trợ trong quá trình điều hướng.

### 2. Thị giác máy tính & AI (Vision Module)
*   **Visual Odometry (Optical Flow):** Sử dụng thuật toán **Lucas-Kanade** (qua OpenCV C++) để theo dõi các điểm đặc trưng (Features) trên mặt đường. Hệ thống tính toán vector di chuyển để bù đắp sai số hướng khi tín hiệu GPS bị nhiễu.
*   **Nhận diện vật thể YOLOv8:** Tích hợp mô hình YOLOv8n chạy trên TFLite để nhận diện thời gian thực các đối tượng (ô tô, xe máy, người đi bộ...).
*   **Vùng cấm động (Dynamic Forbidden Zones):** Tự động loại bỏ các điểm đặc trưng chuyển động khỏi thuật toán Optical Flow, đảm bảo chỉ tính toán dựa trên các vật thể tĩnh.

### 3. Bộ lọc Hợp nhất Cảm biến (Sensor Fusion)
*   **Kalman Filter & Adaptive Weighting:** Thuật toán tự động điều chỉnh trọng số tin cậy. Khi độ chính xác GPS thấp, hệ thống sẽ ưu tiên dữ liệu từ Vision và IMU.
*   **Xử lý rung chấn IMU:** Tích hợp bộ lọc gia tốc kế để phát hiện các biến động đột ngột, giúp làm mượt dữ liệu hướng (Heading) và vận tốc.

### 4. Giám sát Vệ tinh 3D (GNSS Visualization)
*   **3D Globe & Satellite UI:** Hiển thị vị trí thực tế của các chòm sao vệ tinh trên quả địa cầu 3D tương tác.
*   **Skyplot Radar:** Biểu đồ radar hiển thị góc ngẩng, góc phương vị và phân tích tín hiệu của vệ tinh.

### 5. Quản lý Hành trình & Dashcam (Trip & Media)
*   **Quản lý chuyến đi (Trip Manager):** Ghi lại, lưu trữ và xem lại chi tiết lịch sử hành trình.
*   **Dashcam Media:** Hỗ trợ quay video và chụp ảnh trên hành trình.
*   **Cloud Sync:** Tích hợp **Firebase Firestore** và **Google Drive** để đồng bộ và sao lưu dữ liệu chuyến đi, video/hình ảnh.

### 6. Xác thực & Tiện ích khác (Auth & Utilities)
*   **Xác thực thông minh:** Hỗ trợ đăng nhập qua Google (Google Sign-In) và Sinh trắc học (Biometric: Vân tay / FaceID).
*   **Điều khiển bằng giọng nói (Voice Commands) & TTS:** Ra lệnh và nhận phản hồi bằng giọng nói trong khi lái xe.
*   **Gửi phản hồi:** Tích hợp hệ thống gửi Feedback trực tiếp qua **Telegram Service**.

---

## Cấu trúc dự án (Project Structure - Clean Architecture)

Dự án áp dụng mô hình **Clean Architecture** kết hợp BLoC Pattern để quản lý state:

```text
lib/
├── core/               # Chứa các thành phần cốt lõi, utils, theme, error handling
├── features/           # Các module chức năng chính của ứng dụng
│   ├── auth/           # Xác thực (Google Login, Biometric)
│   ├── feedback/       # Gửi phản hồi qua Telegram
│   ├── map/            # Bản đồ, tìm kiếm, điều hướng (Mapbox, Goong)
│   ├── trip/           # Quản lý hành trình, lưu trữ (Firebase, Google Drive)
│   ├── vision/         # Xử lý OpenCV, YOLOv8, Sensor Fusion, GNSS 3D
│   └── voice/          # Nhận diện giọng nói và Text-to-Speech (TTS)
├── shared/             # Các widget dùng chung, services (Location, Sensor, TTS)
└── main.dart           # Entry point của ứng dụng
```

Trong mỗi Feature thường được chia thành 3 layer chuẩn:
*   **data:** Data Sources (API, Local DB) và Repositories Implementation.
*   **domain:** Entities, Repositories Interfaces và Use Cases.
*   **presentation:** BLoC/State Management, Controllers, Pages và Widgets.

---

## Tối ưu hóa hiệu năng (Performance Optimization)

*   **Kiến trúc Đa luồng (Flutter Isolates):** Tách biệt luồng UI chính và luồng xử lý video AI/OpenCV để đảm bảo 60 FPS.
*   **Clean Architecture & BLoC:** Giúp phân tách rõ ràng UI và Logic, dễ dàng bảo trì và scale.
*   **Memory Management:** Quản lý vòng đời chặt chẽ cho đối tượng C++ (OpenCV) và luồng camera.

---

## Công nghệ sử dụng (Tech Stack)

*   **Framework:** Flutter (Dart) - Clean Architecture.
*   **State Management:** BLoC / Cubit.
*   **Computer Vision:** `opencv_dart` (FFI bindings cho OpenCV C++).
*   **AI/Deep Learning:** TFLite (`flutter_vision`), Model YOLOv8n.
*   **Map Services:** Mapbox, Goong Direction & Place API.
*   **Sensors & GNSS:** `geolocator`, `sensors_plus`.
*   **Backend & Sync:** Firebase Authentication/Firestore, Google Drive API.

---

## Cài đặt & Triển khai (Installation)

### 1. Yêu cầu hệ thống
*   Flutter SDK: `^3.10.4` trở lên
*   Android API Level: `24` (Nougat) trở lên
*   Thiết bị vật lý (Yêu cầu để chạy Camera, GPS và Biometric).

### 2. Cấu hình Môi trường
Tạo file `.env` tại thư mục gốc và cấu hình các mã API:
```env
MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
GOONG_API_KEY=your_goong_api_key_here
GOONG_MAPTILES_KEY=your_goong_maptiles_key_here
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id
```

### 3. Cấu hình Firebase
Thêm các file `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) vào dự án thông qua Firebase Console.

### 4. Chuẩn bị Assets
Đảm bảo các file sau đã có trong thư mục `assets/`:
*   `yolov8n.tflite` (Model AI)
*   `labels.txt` (Danh sách nhãn vật thể)

### 5. Chạy ứng dụng
```bash
# Lấy các thư viện phụ thuộc
flutter pub get

# Chạy trên thiết bị (Debug mode)
flutter run
```

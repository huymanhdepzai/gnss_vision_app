# Báo Cáo Phân Tích Chức Năng Vision (Điều Hướng & Tracking)

## 1. Đối tượng Tracking để Điều Hướng

Hệ thống **KHÔNG** theo dõi (track) một vật thể (object) cụ thể để suy ra điều hướng. Thay vào đó, nguyên lý hoạt động của chức năng vision là **theo dõi sự dịch chuyển của môi trường xung quanh** để suy ngược ra chuyển động của bản thân (Ego-motion).

Cụ thể, quá trình này diễn ra như sau:
1.  **Tracking Điểm Đặc Trưng Nền (Background Feature Points):** Hệ thống trích xuất và theo dõi hàng loạt điểm đặc trưng (corners/features) tĩnh trên mặt đất hoặc cảnh vật xung quanh. Bằng cách phân tích sự dịch chuyển quang học (Optical Flow) của các điểm này qua từng khung hình, hệ thống sẽ tính toán được một **Motion Vector** (vector chuyển động) đại diện cho hướng và tốc độ di chuyển của camera (người dùng).
2.  **Loại bỏ Vật Cản (Obstacle Exclusion):** Song song đó, hệ thống sử dụng AI để nhận diện các vật cản (người, xe,...). Các khu vực chứa vật cản này được coi là **"vùng cấm" (forbidden zones)**. Optical Flow sẽ không track các điểm nằm trong vùng này nhằm tránh việc vector chuyển động bị nhiễu do vật cản di chuyển (thay vì người dùng di chuyển).

=> **Kết luận:** Chuyển động điều hướng được suy ra từ việc track **các điểm đặc trưng tĩnh của môi trường**, có kết hợp loại trừ các vật thể động.

---

## 2. Công Nghệ & Thuật Toán Cốt Lõi

Hệ thống kết hợp ba trụ cột công nghệ chính: **Computer Vision (CV)**, **Artificial Intelligence (AI)** và **Xử lý tín hiệu (Signal Processing)**.

### A. Computer Vision (Thị giác máy tính)
*   **Shi-Tomasi Corner Detector (`cv.goodFeaturesToTrack`):** Thuật toán tìm kiếm các điểm đặc trưng (feature points) tốt nhất trên khung hình để chuẩn bị cho việc theo dõi.
*   **Lucas-Kanade Optical Flow (`cv.calcOpticalFlowPyrLK`):** Thuật toán theo dõi chuyển động (quang luồng). Nó tính toán sự thay đổi vị trí của các điểm đặc trưng từ khung hình trước sang khung hình hiện tại.

### B. Trí Tuệ Nhân Tạo (AI - Object Detection)
*   **YOLOv8 (phiên bản Nano - `yolov8n_float16.tflite`):** Mô hình mạng nén sâu (Deep Learning) chạy trực tiếp trên thiết bị (On-device ML). Mô hình này chịu trách nhiệm phát hiện vật cản theo thời gian thực để tạo ra "vùng cấm" cho thuật toán CV bên trên.

### C. Xử Lý Tín Hiệu & Ước Lượng
*   **RANSAC (Random Sample Consensus):** Thuật toán loại bỏ nhiễu. Trong hàng chục điểm được track, sẽ có những điểm bị track sai hoặc vô tình nằm trên vật đang di chuyển. RANSAC giúp tìm ra khối đại đa số các điểm chuyển động nhất quán (inliers) để tính toán Motion Vector chính xác, loại bỏ các điểm sai (outliers).
*   **Kalman Filter 2D (`KalmanFilter2D`):** Bộ lọc toán học dùng để làm mượt vector chuyển động. Vì việc cầm điện thoại di chuyển sẽ tạo ra độ rung lắc lớn, Kalman Filter kết hợp dự đoán dựa trên quán tính vật lý và dữ liệu đo đạc từ khung hình để cho ra quỹ đạo di chuyển mượt mà, ổn định hơn.
*   **Sensor Fusion (Hợp nhất dữ liệu cảm biến):** Vector chuyển động từ camera (Vision) được kết hợp với dữ liệu từ module GPS và IMU (gia tốc kế) để cung cấp thông tin Heading (hướng đi) và Speed (tốc độ) có độ tin cậy cao nhất.

---

## 3. Các Thư Viện (Libraries) Sử Dụng

Phần chức năng này được xây dựng dựa trên các packages chính yếu sau trong hệ sinh thái Flutter/Dart:

1.  **`opencv_dart`**: Cung cấp bindings để sử dụng thư viện C++ OpenCV thần thánh ngay trong Dart. Chịu trách nhiệm cho toàn bộ phần Computer Vision (Optical Flow, tìm điểm, xử lý ảnh xám/mask).
2.  **`flutter_vision`**: Thư viện hỗ trợ chạy các mô hình Machine Learning TFLite (cụ thể là YOLO) trên nền tảng di động một cách hiệu quả nhờ khả năng tăng tốc phần cứng (GPU/NPU/NNAPI).
3.  **`camera`**: Quản lý phần cứng camera, lấy luồng hình ảnh (image stream) theo thời gian thực để đẩy vào luồng xử lý.
4.  **`geolocator` & `sensors_plus`**: Thu thập dữ liệu vị trí GPS, tốc độ tuyệt đối và dữ liệu từ cảm biến gia tốc, hỗ trợ cho module Sensor Fusion.

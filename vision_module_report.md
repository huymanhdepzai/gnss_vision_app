# Báo Cáo Phân Tích Chức Năng Vision (Điều Hướng & Tracking)

## 1. Cơ Chế Tracking & Điều Hướng (Cập nhật Mới)

Hệ thống Vision hiện tại hỗ trợ **hai cơ chế tracking song song** để phục vụ cho các mục đích và tình huống giao thông khác nhau:

### 1.1. Environment Tracking (Quét môi trường tĩnh - Mặc định)
*   **Nguyên lý:** Khóa vào các điểm đặc trưng (feature points) tĩnh của môi trường xung quanh (như mặt đường, tòa nhà) để tính toán *Optical Flow* và suy ngược ra chuyển động của bản thân (Ego-motion).
*   **Cơ chế:** Các vùng có xe cộ di chuyển (phát hiện bởi YOLO) sẽ bị khoanh vùng thành "Vùng cấm" (Forbidden Zones) để tránh nhiễu vector.
*   **Điều hướng:** Nếu môi trường trôi sang phải (`dx > 0`), nghĩa là camera (người dùng) đang rẽ sang TRÁI. Hệ thống sẽ chỉ dẫn người dùng đang rẽ trái.

### 1.2. Object Focus Tracking (Theo dõi mục tiêu/Leader Following)
*   **Nguyên lý:** Người dùng bám theo một phương tiện dẫn đường (Leader) trong dòng xe cộ đông đúc hoặc khi mất tầm nhìn về môi trường tĩnh.
*   **Cơ chế:** 
    * Nguồn điểm tracking (points) được phân bổ tập trung vào Bounding Box của vật thể được chọn.
    * Bằng việc giám sát kích thước Bounding Box giữa các khung hình, hệ thống liên tục tính toán độ hẹp khoảng cách. Nếu mục tiêu to ra đột ngột quá 5%, hệ thống sẽ lập tức cảnh báo "Khoảng cách đang hẹp lại! Chú ý phanh!".
    * **Tính năng hủy khóa (Auto-unfocus):** Dựa trên diện tích che khuất. Nếu vật thể đi ra khỏi viền màn hình hoặc bị che lấp dẫn đến diện tích hiển thị nhỏ hơn **50%**, hệ thống tự động hủy khóa và quay về Environment Tracking.
*   **Điều hướng (Reference Frame Misalignment Fix):** Việc tracking đối tượng di chuyển đòi hỏi hệ quy chiếu ngược. Cụ thể, khi xe mục tiêu trôi sang phải (`dx > 0`), hệ thống sẽ **tự động đảo ngược vector** để hiểu rằng phương tiện Leader đang rẽ sang phải, từ đó cập nhật La bàn (Sensor Fusion) và Mũi tên (Turn Instruction) chỉ dẫn bạn RẼ PHẢI để đi theo đúng quỹ đạo.

---

## 2. Tính năng Auto-Focus Tracking (Tự động khóa mục tiêu ưu tiên)

Hệ thống tích hợp một công tắc Auto-Focus, cho phép người dùng tùy ý bật/tắt (Icon tâm ngắm trên UI Navigation và trong Option Menu của FlowPage). Khi kích hoạt, thay vì đợi người dùng chạm (tap) để khóa, hệ thống sẽ tự động chọn mục tiêu tốt nhất.

**Thuật toán Heuristic Scoring (Trọng số ưu tiên):**
Nhằm khắc phục nhược điểm "chỉ ưu tiên độ tin cậy AI" (dễ khóa nhầm xe đậu bên kia đường do AI nhìn quá rõ), hệ thống sẽ chấm điểm toàn bộ vật thể (với độ tin cậy > 0.35) dựa trên thang điểm tổng hợp (Combined Score từ 0.0 -> 1.0):

1.  **Confidence Score (40% Trọng số):** Điểm độ tin cậy gốc từ mô hình YOLOv8. Đảm bảo chắc chắn mục tiêu là phương tiện thật sự.
2.  **Center Proximity Score (40% Trọng số):** Điểm vị trí tâm. Xe càng nằm gần chính giữa chiều ngang khung hình (cùng làn đường) thì điểm càng cao. Đặc biệt, việc lệch trục ngang (trái/phải) bị trừ điểm nặng (70%) hơn so với độ lệch dọc (30%).
3.  **Size Score (20% Trọng số):** Điểm diện tích. Tỷ lệ chiều rộng vật thể so với màn hình. Xe càng to thì càng gần người dùng, điểm ưu tiên càng cao.

=> Thuật toán này giúp hệ thống mô phỏng tư duy của con người: *"Luôn bám theo chiếc xe ở gần nhất, to nhất, nằm ngay thẳng mặt và được nhận dạng rõ ràng nhất"*.

---

## 3. Công Nghệ & Thuật Toán Cốt Lõi

Hệ thống vẫn giữ vững ba trụ cột công nghệ chính: **Computer Vision (CV)**, **Artificial Intelligence (AI)** và **Xử lý tín hiệu (Signal Processing)**.

### A. Computer Vision (Thị giác máy tính)
*   **Shi-Tomasi Corner Detector (`cv.goodFeaturesToTrack`):** Quét tìm điểm đặc trưng trên khung hình. Số lượng điểm sẽ thay đổi động: Tracking môi trường cần khoảng 60 điểm rải rác, Tracking mục tiêu chỉ cần khoảng 30 điểm tập trung.
*   **Lucas-Kanade Optical Flow (`cv.calcOpticalFlowPyrLK`):** Theo dõi độ dời của quang luồng.
*   **Bounding Box IOU Tracking:** Tính toán Intersection over Union (IOU) để giữ vững khóa mục tiêu khi YOLO cập nhật các Box mới sau mỗi lần inference.

### B. Trí Tuệ Nhân Tạo (AI - Object Detection)
*   **YOLOv8 (`yolov8n_float16.tflite`):** Phân tích hình ảnh trên tiến trình nền. Cung cấp danh sách các chướng ngại vật (Bounding Box & Confidence) cho việc tạo "vùng cấm" hoặc làm đầu vào cho Auto-Focus.

### C. Xử Lý Tín Hiệu & Ước Lượng
*   **RANSAC (Random Sample Consensus):** Tách lọc Inliers (điểm di chuyển đúng quỹ đạo số đông) và Outliers (nhiễu).
*   **Kalman Filter 2D (`KalmanFilter2D`):** Làm mượt vector chuyển động thô, triệt tiêu gia tốc rung lắc bất thường do điện thoại gây ra.
*   **Sensor Fusion (Hợp nhất dữ liệu):** Kết hợp Vector đã qua xử lý (Vision), la bàn GPS tuyệt đối, và gia tốc kế (IMU) để tính toán góc rẽ (Heading) cho UI.

---

## 4. Kiến Trúc Luồng Dữ Liệu & Isolate

1.  **Dart Isolates (`Isolate`)**: Tất cả quy trình xử lý thị giác (Resize ảnh, tạo Mask, Optical Flow, RANSAC, Kalman Filter) được dời toàn bộ sang **Background Worker Isolate** qua `SendPort` & `ReceivePort`. Isolate chính (UI) hoàn toàn không bị ảnh hưởng, đảm bảo hiệu năng 60FPS.
2.  **State Management**: `CameraFlowController` và `VideoFlowController` đóng vai trò là cầu nối, tiếp nhận DTO (`IsolateResult`) từ Worker, đảo ngược vector (nếu ở chế độ Auto-Focus/Leader Follow), hợp nhất với GPS và xuất tín hiệu lên màn hình thông qua các `ValueNotifier`.
3.  **UI Components**: Lắng nghe `ValueNotifier` cục bộ qua `ValueListenableBuilder` để cập nhật vùng nhìn (PiP Camera, Bounding Box, Alert Banner) mà không gọi `setState` nguyên cây Widget.

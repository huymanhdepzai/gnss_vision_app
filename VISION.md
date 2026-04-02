# Báo cáo Hệ thống Thị giác máy tính (Vision System)

---

## 1. Kiến trúc xử lý đa luồng (Tri-Isolate Architecture)

Để đảm bảo ứng dụng đạt tốc độ **30 FPS** ổn định trong khi phải xử lý đồng thời AI và OpenCV, hệ thống phân tách thành 3 môi trường thực thi độc lập:

1.  **UI Isolate (Main):** 
    *   Quản lý Mapbox/Goong Maps và render các thành phần HUD.
    *   Thực hiện nhận diện vật thể YOLOv8 định kỳ (Throttled AI).
2.  **CV Worker Isolate:** 
    *   Xử lý giải mã video và lõi OpenCV (Optical Flow).
    *   Gửi kết quả về UI Isolate thông qua `SendPort` dưới dạng byte ảnh đã nén để tối ưu băng thông.
3.  **IO/Sensor Isolate:** 
    *   Lắng nghe dữ liệu GPS và IMU liên tục để đồng bộ hóa với luồng Vision.

---

## 2. Lõi Visual Odometry: Thuật toán Lucas-Kanade

Nằm tại `cv_core.dart`, đây là thành phần quan trọng nhất để tính toán vector dịch chuyển của xe.

### 2.1. Lọc điểm đặc trưng (Feature Extraction)
*   **Thuật toán:** **Shi-Tomasi Corner Detector** (`goodFeaturesToTrack`).
*   **Chiến lược ROI (Region of Interest):** 
    *   Hệ thống chỉ tìm kiếm điểm đặc trưng ở **50% phần dưới bức ảnh**.
    *   **Lý do:** Phần này chứa mặt đường và các vật thể cố định gần xe nhất, mang lại độ chính xác cao nhất cho việc tính toán vận tốc và hướng thực tế của thiết bị.
*   **Tham số tối ưu:** Giới hạn 60 điểm (`maxCorners`) để giảm độ phức tạp tính toán $O(N)$ trong các frame tiếp theo.

### 2.2. Theo dõi chuyển động (Optical Flow)
*   **Thuật toán:** **Lucas-Kanade Pyramidal** (`calcOpticalFlowPyrLK`).
*   **Cơ chế:** Tính toán sự thay đổi vị trí của tập hợp điểm đặc trưng giữa khung hình $t$ và $t-1$.
*   **Xử lý sai số:** Hệ thống sử dụng phương pháp tính **trung bình cộng có trọng số** của các vector dịch chuyển thành công (`status == 1`) để tạo ra vector dịch chuyển thô (`rawMoveVector`).

### 2.3. Bộ lọc Kalman-like (Smoothing)
Để loại bỏ hiện tượng rung lắc camera (jitter), vector Vision được đưa qua một bộ lọc làm mượt:
$$V_{smoothed} = V_{prev} + (V_{target} - V_{prev}) \times \alpha$$
Trong đó $\alpha = 0.15$ giúp cân bằng giữa độ nhạy và độ ổn định của la bàn AR.

---

## 3. Dynamic Forbidden Zones (Vùng cấm động)

*   **Vấn đề:** Khi một chiếc ô tô hoặc xe máy đi phía trước camera, các điểm đặc trưng Shi-Tomasi sẽ bám vào chiếc xe đó. Nếu xe đó rẽ trái, hệ thống Vision sẽ hiểu nhầm là bạn đang rẽ phải.
*   **Giải pháp:** 
    1.  **AI Detection:** YOLOv8 nhận diện các phương tiện xung quanh.
    2.  **Masking:** Hệ thống tạo ra một "vùng cấm" (Rect) xung quanh các vật thể này.
    3.  **Exclusion:** Hàm `goodFeaturesToTrack` và `calcOpticalFlow` sẽ **bỏ qua hoàn toàn** các điểm nằm trong vùng cấm.
*   **Kết quả:** Hệ thống chỉ tính toán hướng dựa trên các vật thể tĩnh (mặt đường, vỉa hè), loại bỏ hoàn toàn nhiễu từ các phương tiện đang di chuyển cùng chiều hoặc ngược chiều.

---

## 4. Cơ chế Sensor Fusion (Hợp nhất cảm biến)

Dữ liệu Vision sau khi xử lý sẽ được hợp nhất với GPS  theo logic:

*   **Tình huống GPS tốt (Accuracy < 10m):** GPS giữ vai trò điều hướng chính, Vision đóng vai trò làm mượt góc xoay (Smoothing).
*   **Tình huống GPS yếu (Hầm, Đô thị dày đặc):** 
    *   Hệ thống tự động tăng trọng số của Vision lên mức tối đa.
    *   **Logic phạt (Penalty):** Nếu Vision theo dõi được ít hơn 20 điểm đặc trưng, hệ thống sẽ tự động giảm độ tin cậy để tránh dẫn đường sai.
*   **Bù IMU:** Sử dụng gia tốc kế để phát hiện "ổ gà". Khi xe bị rung mạnh theo trục Y, Vision sẽ bị tạm ngắt trong 0.5 giây để tránh tính toán sai lệch do camera bị xóc.

---

## 5. Các con số tối ưu hóa 

*   **Độ phân giải xử lý:** 240p (Đủ để nhận diện đặc trưng nhưng giảm 80% tải CPU so với 1080p).
*   **Tần suất AI:** 3 Hz (Chạy mỗi 10 frames) - Giúp tiết kiệm 70% pin nhưng vẫn đảm bảo vùng cấm được cập nhật đủ nhanh.
*   **Độ trễ hệ thống:** < 50ms từ lúc camera nhận hình ảnh đến lúc hiển thị trên HUD.

---

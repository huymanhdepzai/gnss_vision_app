# Nội Dung Báo Cáo Đồ Án Tốt Nghiệp: Xây Dựng Ứng Dụng Android Hỗ Trợ Định Vị GNSS-Vision

Dưới đây là nội dung chi tiết cho các slide trình bày đồ án tốt nghiệp, được cập nhật bám sát vào cấu trúc mã nguồn (Clean Architecture, BLoC) và các chức năng thực tế đã triển khai trong ứng dụng:

---

## Slide 1: Đặt vấn đề
**Tiêu đề:** Đặt Vấn Đề
* **Vai trò của hệ thống dẫn đường:** Rất quan trọng đối với phương tiện giao thông trong đô thị hiện đại.
* **Sự phụ thuộc vào GNSS (GPS):** Phần lớn các ứng dụng hiện nay đều dùng tín hiệu vệ tinh.
* **Thách thức trong môi trường đô thị:**
  * Mật độ tòa nhà cao tầng dày đặc, hầm chui, tán cây rậm rạp.
  * Hiện tượng hiệu ứng đa đường (multipath) và che khuất hoàn toàn tín hiệu vệ tinh.
* **Hậu quả:** Sai lệch vị trí nghiêm trọng, hướng đi không ổn định hoặc mất hoàn toàn kết nối định vị $\rightarrow$ Gây nguy hiểm, khó khăn cho người lái xe.

---

## Slide 2: Hạn chế của các hệ thống hiện tại
**Tiêu đề:** Hạn Chế Của Các Hệ Thống Định Vị Hiện Tại
* **Google Maps, Apple Maps:** Hoạt động tốt trong điều kiện lý tưởng, nhưng thường bị "đơ" hoặc dịch chuyển sai khi vào hầm chui.
* **Sự đơn lẻ của GNSS:** Thiếu tính liên tục và độ chính xác khi không có tín hiệu vệ tinh hỗ trợ.
* **Giải pháp hợp nhất cảm biến hiện tại:** 
  * Chủ yếu thử nghiệm trên máy tính cấu hình cao hoặc robot chuyên dụng.
  * Chưa tối ưu trên thiết bị di động (gây quá tải phần cứng, hao pin, không đạt realtime).
* **Bài toán đặt ra:** Cần một giải pháp định vị liên tục, tận dụng sức mạnh phần cứng di động sẵn có (Camera, Cảm biến quán tính) mà không phụ thuộc hoàn toàn vào hạ tầng vệ tinh.

---

## Slide 3: Mục tiêu đồ án
**Tiêu đề:** Mục Tiêu Và Giải Pháp Đột Phá Của Đồ Án
* **Mục tiêu chính:** Xây dựng ứng dụng Android hỗ trợ định vị "GNSS-Vision" hoạt động ổn định trong vùng mù GPS.
* **Những cải tiến nổi bật (Multi-sensor Fusion):**
  * **Hợp nhất đa cảm biến:** Kết hợp dữ liệu GNSS, cảm biến quán tính (IMU) và Thị giác máy tính (Visual Odometry).
  * **Độ chính xác cao:** Duy trì lộ trình mượt mà ngay cả khi GPS bị nhiễu.
  * **Tối ưu phần cứng di động:** Kiến trúc đa luồng (Isolates) giúp chạy mô hình AI và xử lý hình ảnh realtime (60 FPS) không gây nghẽn UI.
  * **Hệ sinh thái tiện ích thông minh:** Camera hành trình (Dashcam), Đồng bộ đám mây (Google Drive/Firebase), Trợ lý ảo AI & Điều khiển giọng nói (TTS), Xác thực sinh trắc học.

---

## Slide 4: Phân tích thiết kế hệ thống (1/2)
**Tiêu đề:** Kiến Trúc Hệ Thống Tổng Thể (Clean Architecture)
* **Mô hình kiến trúc:** Áp dụng **Clean Architecture** kết hợp **BLoC Pattern** để quản lý state, phân tách rõ ràng Data, Domain và Presentation.
* **Xử lý đa luồng (Flutter Isolates):** Tách biệt giao diện (Main Thread) và các tác vụ tính toán nặng (AI, OpenCV C++).
* **Các Module cốt lõi:**
  * **Map Module:** Hybrid Map Engine (Mapbox + Goong API), POI Search, Day/Night Scene.
  * **Vision Module:** Nhận diện vật thể (YOLOv8), Optical Flow (OpenCV), Sensor Fusion (Kalman), GNSS 3D.
  * **Trip Module:** Quản lý hành trình, Dashcam, Cloud Sync.
  * **Auth & Voice Module:** Xác thực vân tay/FaceID, Ra lệnh giọng nói, Phản hồi qua Telegram.

---

## Slide 5: Phân tích thiết kế hệ thống (2/2)
**Tiêu đề:** Luồng Hoạt Động Của Hệ Thống Định Vị (Sensor Fusion)
* **Thu thập dữ liệu liên tục:** GNSS, Gia tốc kế, Con quay hồi chuyển (IMU), và Camera Frame.
* **Giám sát & Đánh giá tín hiệu:** Đo lường độ chính xác (Accuracy) của GPS theo thời gian thực.
* **Bù trừ sai số (Adaptive Weighting):**
  * Trích xuất vector vận tốc và hướng từ **Visual Odometry** (Optical Flow) và IMU.
  * **Bộ lọc Kalman (Kalman Filter):** Tự động điều chỉnh trọng số tin cậy. Khi GPS yếu, hệ thống ưu tiên dữ liệu từ Vision và IMU để nội suy tọa độ mượt mà nhất.

---

## Slide 6: Công nghệ sử dụng (1/3)
**Tiêu đề:** Nền Tảng, Giao Diện & Bản Đồ Số
* **Flutter Framework (Dart):** Phát triển đa nền tảng, hiệu năng cao. Quản lý trạng thái bằng **BLoC/Cubit**.
* **Hybrid Map Engine:**
  * **Mapbox Maps SDK:** Render không gian vector 3D mượt mà.
  * **Goong API:** Tối ưu hóa tìm kiếm địa điểm (Geocoding) và định tuyến (Routing) chính xác tại Việt Nam.
* **Backend & Lưu trữ đám mây:** 
  * Firebase (Authentication, Firestore).
  * Google Drive API (Đồng bộ video/hình ảnh Dashcam).
* **Giao tiếp ngoại vi:** Telegram API cho hệ thống gửi Feedback.

---

## Slide 7: Công nghệ sử dụng (2/3)
**Tiêu đề:** Trí Tuệ Nhân Tạo & Nhận Diện Hình Ảnh
* **Mô hình YOLOv8n (TFLite):** 
  * Phát hiện vật thể (Object Detection) realtime ngay trên thiết bị (On-device AI).
  * Khởi tạo **"Vùng cấm động" (Dynamic Forbidden Zones):** Tự động loại bỏ các điểm đặc trưng của phương tiện khác đang di chuyển khỏi thuật toán.
* **Thị giác máy tính (Computer Vision):**
  * Tích hợp **C++ OpenCV** thông qua **FFI (Foreign Function Interface)** (`opencv_dart`).
  * **Thuật toán Optical Flow (Lucas-Kanade):** Theo dõi các điểm trên mặt đường tĩnh để trích xuất vector chuyển động bù đắp sai số hướng.

---

## Slide 8: Công nghệ sử dụng (3/3)
**Tiêu đề:** Hợp Nhất Cảm Biến & Giám Sát GNSS
* **Cảm biến quán tính (IMU):** Sử dụng `sensors_plus` để lọc gia tốc kế và con quay hồi chuyển, làm mượt hướng (Heading) và phát hiện rung chấn.
* **Bộ lọc Kalman (Kalman Filter):** Lọc nhiễu và ước lượng trạng thái di chuyển, phối hợp nhịp nhàng giữa GPS và Vision.
* **Giám sát GNSS 3D trực quan:** 
  * **3D Globe & Satellite UI:** Hiển thị vị trí thực tế của vệ tinh trên quả địa cầu.
  * **Skyplot Radar:** Phân tích góc ngẩng, góc phương vị của tín hiệu vệ tinh.

---

## Slide 9: Cài đặt & Triển khai
**Tiêu đề:** Môi Trường & Cơ Chế Triển Khai Thực Tế
* **Yêu cầu hệ thống:** Thiết bị Android (API 24+), có Camera, GPS, IMU và hỗ trợ sinh trắc học.
* **Cách thức gắn thiết bị:** Gắn cố định trên xe (ô tô/xe máy), camera hướng về phía trước quan sát mặt đường.
* **Cơ Chế Hoạt Động Đa Luồng (Multithreading):**
  * **Vấn đề:** Chạy YOLOv8 và OpenCV tốn nhiều tài nguyên, gây giật lag UI.
  * **Giải pháp:** Sử dụng **Flutter Isolates**. Luồng chính xử lý bản đồ Mapbox/Goong; Luồng nền xử lý Frame Camera, AI và Kalman Filter đảm bảo đạt ~60 FPS.

---

## Slide 10: CSDL Thực tế
**Tiêu đề:** CSDL Thực Tế - Nguồn Dữ Liệu
* **Dữ liệu bản đồ & Địa điểm:** API từ Goong và Mapbox (Dữ liệu mạng lưới giao thông Việt Nam).
* **Dữ liệu mô hình AI (YOLOv8):** Huấn luyện sẵn (TFLite) nhận diện phương tiện giao thông và người đi bộ.
* **Dữ liệu thu thập thực tế (Real-time Data):**
  * Dữ liệu Camera nội suy liên tục (Vector chuyển động).
  * Tọa độ GPS & Dữ liệu IMU tần số cao.
* **Dữ liệu đám mây (Firebase/Google Drive):** Tài khoản người dùng, lịch sử hành trình, video Dashcam lưu trữ online.

---

## Slide 11: Giao diện (1/2)
**Tiêu đề:** Giao Diện Ứng Dụng (Chèn hình ảnh minh họa)
* **Màn hình chính (Bản đồ & Dẫn đường):** Bản đồ Hybrid 3D với Day/Night mode, thanh tìm kiếm thông minh Goong Autocomplete.
* **Trợ lý ảo & Điều khiển giọng nói:** Giao diện Chat Assistant Overlay, phản hồi bằng Text-to-Speech.
* **Màn hình Quản lý hành trình (Trip Manager):** Xem lại lộ trình đã đi, phát lại video Dashcam được đồng bộ từ Cloud.
* **Màn hình Xác thực & Góp ý:** Đăng nhập sinh trắc học (vân tay/khuôn mặt) nhanh chóng, form gửi lỗi tự động đẩy về Telegram.

---

## Slide 12: Giao diện (2/2)
**Tiêu đề:** Giao Diện Màn Hình Giám Sát Kỹ Thuật (Chèn hình ảnh minh họa)
* **Màn hình Camera/Trợ lý tầm nhìn (Vision):** 
  * Hiển thị bounding box (YOLOv8).
  * Vector chuyển động Optical Flow trên mặt đường (điểm màu xanh/đỏ).
* **Màn hình giám sát GNSS 3D:** 
  * Quả địa cầu 3D với các chòm sao vệ tinh.
  * Biểu đồ Radar (Skyplot) hiển thị cường độ tín hiệu.

---

## Slide 13: Đánh giá hệ thống (1/2)
**Tiêu đề:** Đánh Giá Khả Năng Nhận Diện & Tối Ưu Hiệu Năng
* **Đạt chuẩn thời gian thực (Real-time):** Nhờ cơ chế Isolates và FFI (OpenCV C++), hệ thống duy trì khung hình ổn định khi chạy AI trên thiết bị di động.
* **Đánh giá "Vùng cấm động":** Thuật toán YOLOv8 nhận diện và loại trừ chính xác các đối tượng đang di chuyển $\rightarrow$ Cơ chế chống chớp nháy (chịu đựng 3 frame rỗng) hoạt động hiệu quả.
* **Xử lý rung chấn:** Bộ lọc IMU loại bỏ tốt các dao động đột ngột từ mặt đường xấu, giữ định hướng ổn định.

---

## Slide 14: Đánh giá hệ thống (2/2)
**Tiêu đề:** Đánh Giá Độ Chính Xác Định Vị
* **Kịch bản kiểm thử:** Tuyến đường có hầm chui dài hoặc khu vực nhiều tòa nhà cao tầng làm nhiễu GPS.
* **Độ lệch quỹ đạo (Trajectory Error):**
  * *Chỉ dùng GPS:* Mất tín hiệu, quỹ đạo nhảy vọt hoặc đóng băng.
  * *Hệ thống GNSS-Vision:* Quỹ đạo được nội suy trơn tru nhờ tốc độ từ Optical Flow và hướng từ IMU, khớp với cung đường thực tế.
* **Sự chuyển giao mượt mà:** Bộ lọc Kalman tự động cân bằng các nguồn dữ liệu mà không làm giật lag giao diện bản đồ.

---

## Slide 15: Ví dụ chạy thực tế
**Tiêu đề:** Kịch Bản Kiểm Thử Thực Tế (Gắn Video/Biểu Đồ)
* **Kịch bản 1: Mất sóng trong hầm chui:**
  * Xe đi vào hầm, GPS báo tín hiệu yếu/mất hoàn toàn.
  * Hệ thống tự động đẩy trọng số Vision & IMU lên mức cao nhất. Marker trên bản đồ vẫn di chuyển tịnh tiến đúng theo vận tốc xe.
* **Kịch bản 2: Ứng dụng trong điều kiện giao thông đông đúc:**
  * AI kích hoạt "vùng cấm động" loại bỏ các xe chạy cắt ngang.
  * Trợ lý ảo cảnh báo bằng giọng nói (TTS) kết hợp lưu trữ diễn biến qua Dashcam.

---

## Slide 16: Kết luận & Hướng phát triển (1/2)
**Tiêu đề:** Kết Quả Đạt Được & Đóng Góp
* **Kết quả:** Xây dựng thành công ứng dụng Android thực tiễn, áp dụng chuẩn **Clean Architecture** và tối ưu đa luồng tốt.
* **Đóng góp nổi bật:**
  * Hoàn thiện giải pháp kết hợp Bản đồ số Hybrid (Mapbox+Goong) với mô hình Deep Learning (YOLOv8) trên thiết bị di động.
  * Tích hợp thành công C++ OpenCV vào Flutter, bù đắp hiệu quả sai số định vị bằng Camera và IMU.
  * Cung cấp trải nghiệm người dùng hiện đại với Xác thực sinh trắc học, Voice Command, và đồng bộ dữ liệu Cloud.

---

## Slide 17: Kết luận & Hướng phát triển (2/2)
**Tiêu đề:** Hạn Chế & Hướng Phát Triển
* **Hạn chế:**
  * Thuật toán Optical Flow giảm độ chính xác khi đi vào ban đêm thiếu sáng hoặc đường không có điểm đặc trưng (đường trơn bóng, vũng nước lớn).
  * Tiêu hao năng lượng nhanh hơn các app bản đồ thông thường do phải chạy xử lý ảnh liên tục.
* **Hướng phát triển:**
  * **Tích hợp thuật toán SLAM:** Đo đạc chiều sâu 3D thực tế để tính toán chính xác hơn.
  * **Nâng cấp mô hình AI:** Áp dụng thuật toán tăng cường ảnh ban đêm (Low-light Image Enhancement) và Quantization model để tiết kiệm pin hơn.
  * **Hỗ trợ đa nền tảng:** Biên dịch tối ưu để đưa ứng dụng lên iOS/CarPlay.

---
*Ghi chú: Hãy sử dụng hình ảnh thực tế từ ứng dụng (màn hình Mapbox, GNSS 3D, màn hình Camera YOLOv8...) để thêm vào các slide Giao Diện và Đánh Giá nhằm tăng tính thuyết phục cho báo cáo.*

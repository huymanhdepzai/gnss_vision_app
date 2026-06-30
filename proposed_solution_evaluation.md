# Báo Cáo Đánh Giá Giải Pháp: Tự Động Chuyển Đổi & Lựa Chọn Tracking Đối Tượng Trong Môi Trường Đông Đúc

## 1. Tóm Tắt Giải Pháp Đề Xuất (Đã Cập Nhật)
* **Vấn đề hiện tại:** Optical Flow theo dõi các điểm nền tĩnh sẽ thất bại khi môi trường quá đông đúc (xe cộ, người qua lại che khuất phần lớn khung hình).
* **Giải pháp đề xuất mới:** 
  1. Khi môi trường đông đúc, hệ thống tự động chuyển sang chế độ **"Leader Following"** (Theo dõi đối tượng dẫn đường).
  2. **Auto-selection:** Ban đầu, hệ thống ưu tiên tự động phát hiện và chọn một vật thể nổi bật nhất (ví dụ: kích thước Bounding Box lớn, nằm ở trung tâm, chứa nhiều điểm ảnh/đặc trưng) để bắt đầu tracking.
  3. **User in the loop (Trao quyền cho người dùng):** Hệ thống không "khóa cứng" (hard-lock) vào vật thể đó. Người dùng có quyền can thiệp, tự quyết định chọn một đối tượng khác làm mục tiêu tracking (thông qua thao tác chạm trên màn hình) nếu thấy đối tượng AI chọn không phù hợp (ví dụ: AI chọn chiếc xe rẽ trái, nhưng người dùng muốn đi thẳng).

---

## 2. Phân Tích Kỹ Thuật Hướng Tiếp Cận Mới

Đây là một hướng tiếp cận **rất xuất sắc và hiện đại**, kết hợp giữa tự động hóa (AI) và sự kiểm soát của con người (Human-Computer Interaction - HCI). 

### A. Cơ chế hoạt động dự kiến
1. **Phát hiện đám đông (Trigger):** YOLO liên tục đếm số lượng Box. Khi vượt ngưỡng, bật chế độ `Crowd Mode`.
2. **Gợi ý mục tiêu (Target Proposal):** 
   * Thuật toán lọc các Box từ YOLO, chấm điểm (scoring) dựa trên: Kích thước (Area), Vị trí (càng gần tâm càng điểm cao), Loại đối tượng (ưu tiên ô tô/xe máy/người đi bộ cùng chiều).
   * Box có điểm cao nhất được gán thành `active_target`.
3. **Thao tác người dùng (User Override):** 
   * Trên UI, vẽ một khung (bracket) đặc biệt quanh `active_target`. 
   * Nếu người dùng chạm (tap) vào một đối tượng khác trên màn hình, tọa độ (x, y) chạm được gửi xuống, tìm Box nào chứa điểm đó và đổi `active_target` sang Box mới.
4. **Tracking mục tiêu:** 
   * Khi đã có mục tiêu, thay vì dùng Optical Flow để tính Ego-motion toàn khung hình, hệ thống sẽ giới hạn việc tracking **chỉ bên trong Bounding Box** của mục tiêu đó (Có thể dùng Single Object Tracker như CSRT, KCF, MedianFlow của OpenCV, hoặc tiếp tục dùng Optical Flow nhưng cắt Mask theo Box).
   * Dựa vào sự thay đổi kích thước và vị trí của Box, hệ thống báo cáo khoảng cách và hướng tương đối để đi theo.

---

## 3. Đánh Giá Ưu Điểm & Rủi Ro

### Ưu điểm vượt trội (Pros):
1. **Độ an toàn cực cao:** Việc trao quyền cho người dùng giải quyết triệt để rủi ro "AI đoán sai ý người dùng". Nếu AI chọn nhầm xe đang chuẩn bị rẽ, người dùng ngay lập tức có thể chuyển sang xe đi thẳng.
2. **Tính linh hoạt:** Giải quyết hoàn toàn bài toán mù màu/mất phương hướng khi bị che khuất. Người dùng tự chọn "ngọn hải đăng" của mình để bám theo.
3. **Tài nguyên tính toán:** Khi chuyển sang track 1 đối tượng duy nhất (Single Object Tracking), tài nguyên CPU/GPU cần thiết sẽ ít hơn so với việc chạy Optical Flow trên hàng trăm điểm toàn màn hình.

### Rủi ro và Thách thức cần giải quyết (Cons & Challenges):
1. **Bài toán mất dấu (Target Loss & Re-identification):** 
   * *Rủi ro:* Xe mà người dùng đang track đột ngột tăng tốc đi mất, hoặc bị một chiếc xe tải to hơn cắt ngang che khuất trong 2 giây. Hệ thống sẽ mất dấu đối tượng.
   * *Giải pháp:* Cần có cơ chế Fallback. Nếu mất dấu, tự động chọn lại mục tiêu nổi bật khác và thông báo (bằng giọng nói/âm thanh) để người dùng biết mục tiêu đã thay đổi.
2. **Bài toán phân biệt chiều di chuyển:**
   * *Rủi ro:* AI chọn nhầm một chiếc xe đi ngược chiều đang tiến tới sát mình làm mục tiêu (kích thước nó cũng to và ở giữa). Nếu track theo nó, hệ thống sẽ hiểu sai hoàn toàn.
   * *Giải pháp:* Cần dùng Optical Flow trên Box đó trong vài frame đầu tiên để xác định vector chuyển động tương đối. Nếu đối tượng di chuyển quá nhanh về phía camera (looming effect mạnh) -> Loại bỏ, không đưa vào danh sách đề xuất.
3. **Trải nghiệm người dùng (UX):**
   * Nếu đây là ứng dụng cho người khiếm thị/mắt kém, việc yêu cầu họ "chạm chính xác" vào một vật thể đang di chuyển trên màn hình là điều bất khả thi. Nếu app dành cho xe tự hành/hỗ trợ lái xe thì màn hình cảm ứng hoàn toàn khả thi. Bạn cần cân nhắc đối tượng người dùng cuối (End-user) của app để thiết kế thao tác "User Override" cho phù hợp (Ví dụ: Thay vì chạm, vuốt sang trái/phải để chuyển mục tiêu).

---

## 4. Phân Tích Tính "Đúng/Sai" Của Kết Quả Điều Hướng Khi Bám Đối Tượng

Về bản chất, việc chuyển sang track một vật thể đang di chuyển làm thay đổi hoàn toàn ý nghĩa của dữ liệu đầu ra:

### A. Về mặt Định vị Tuyệt đối (Visual Odometry) -> KẾT QUẢ SAI
Nếu tiếp tục dùng dữ liệu dịch chuyển của mục tiêu để đưa vào các công thức SLAM/Odometry tính toán chuyển động của chính xe mình (Ego-motion), kết quả sẽ **sai hoàn toàn**:
* **Ảo giác đứng yên:** Nếu xe của bạn và xe phía trước chạy cùng một vận tốc, hệ thống điều hướng sẽ báo cáo xe bạn đang đứng yên.
* **Đi lùi:** Nếu xe phía trước tăng tốc, hệ thống có thể hiểu nhầm là xe bạn đang lùi lại.
* **Sai lệch quỹ đạo:** Các chuyển động lách né của xe phía trước sẽ bị tính nhầm thành chuyển động ngang của chính xe bạn.

### B. Về mặt Bám đuôi (Adaptive Cruise Control / Leader Following) -> KẾT QUẢ ĐÚNG
Nếu chuyển đổi mục tiêu bài toán sang "Tôi phải đi như thế nào để an toàn so với xe phía trước?", thông tin cung cấp lại **cực kỳ chính xác và hữu ích**:
* **Chính xác về Khoảng cách (TTC - Time to Collision):** Dựa vào sự phình to/thu nhỏ của Bounding Box, hệ thống biết được khoảng cách tương đối đang thu hẹp hay giãn ra để đưa ra cảnh báo phanh/tăng tốc.
* **Chính xác về Hướng đi tương đối (Relative Bearing):** Sự dịch chuyển tâm của Box sang trái/phải giúp hệ thống biết cần phải đánh lái như thế nào để tiếp tục bám theo quỹ đạo của "Leader".

### C. Nguy cơ tiềm ẩn và Cách khắc phục
* **Rủi ro:** Xe "Leader" đổi hướng đột ngột (rẽ vào hẻm) hoặc đi ngược chiều. Nếu mù quáng đi theo, kết quả điều hướng sẽ dẫn người dùng vào nguy hiểm.
* **Giải pháp:** Cần thay đổi cách báo cáo thông tin (Feedback) cho người dùng. Ở chế độ này, hệ thống không nên báo cáo định vị tuyệt đối (ví dụ: "Bạn đang ở tọa độ X") mà nên chuyển sang báo cáo tương đối (ví dụ: "Đang bám theo xe phía trước", "Chú ý phanh"). Kết hợp với cơ chế **User-in-the-loop** (đã đề cập ở phần 1) để người dùng có thể can thiệp ngay lập tức khi phát hiện "Leader" đi sai đường.

---

## 5. Kết Luận & Định Hướng Viết Code

Giải pháp này hoàn toàn khả thi và mang tính thực tiễn cao. Nó chuyển bài toán từ **Visual Odometry (tính toán tọa độ tuyệt đối)** sang **Target Following (Bám theo mục tiêu)** khi gặp điều kiện bất lợi.

**Các bước cần làm sắp tới trong Codebase:**
1. Cập nhật `vision_data_source.dart` và `cv_data_source_impl.dart` thêm hàm nhận đầu vào tọa độ `(x, y)` từ UI để khóa mục tiêu thủ công.
2. Trong `cv_data_source_impl.dart`, thêm trạng thái logic: `enum TrackingMode { environment, objectFocus }`.
3. Khi ở chế độ `objectFocus`, khởi tạo thuật toán Tracker riêng biệt chỉ tập trung vào vùng Box được chọn thay vì quét toàn khung hình.

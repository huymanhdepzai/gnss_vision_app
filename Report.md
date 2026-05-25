# BÁO CÁO CHI TIẾT ỨNG DỤNG GNSS VISION NAVIGATION

---

## CHƯƠNG I: TỔNG QUAN ỨNG DỤNG

### 1.1. Giới thiệu

Ứng dụng **GNSS Vision Navigation** (tên nội bộ: Vision Flow) là một hệ thống điều hướng thông minh chạy trên nền tảng mobile, kết hợp ba công nghệ cốt lõi: **định vị vệ tinh GNSS (Global Navigation Satellite System)**, **thị giác máy tính (Computer Vision)** và **điều khiển bằng giọng nói (Voice Command)**. Mục tiêu chính của ứng dụng là cung cấp trải nghiệm điều hướng an toàn hơn thông qua việc phát hiện vật cản theo thời gian thực, ước lượng heading chính xác ngay cả khi GPS suy giảm, và cho phép người dùng tương tác ứng dụng hoàn toàn bằng giọng nói — đặc biệt hữu ích khi đang lái xe.

Phiên bản hiện tại: **1.0.0**, phát triển trên nền tảng **Flutter** (Dart ^3.10.4), hỗ trợ đa nền tảng: Android, iOS, Web, Windows, macOS.

### 1.2. Vấn đề đặt ra

Trong điều kiện điều tuyến thực tế, đặc biệt tại Việt Nam, hệ thống điều hướng truyền thống đối mặt với nhiều hạn chế:

- **GPS không chính xác trong đô thị dày đặc**: Các tòa nhà cao tầng gây ra hiệu ứng multipath (đa đường), làm suy giảm độ chính xác định vị xuống hàng chục mét, và heading (hướng di chuyển) từ GPS thường sai lệch nghiêm trọng khi tốc độ thấp hoặc khi dừng ở giao lộ.
- **Không phát hiện vật cản**: Các ứng dụng điều hướng hiện tại (Google Maps, Goong Maps) chỉ cung cấp chỉ dẫn rẽ nhưng không cảnh báo vật cản phía trước như xe đỗ, người đi bộ, xe máy đi ngược chiều.
- **Không thể tương tác thủ công khi lái xe**: Việc chạm màn hình để thao tác trên bản đồ gây mất tập trung và nguy hiểm.

### 1.3. Giải pháp đề xuất

Ứng dụng giải quyết ba vấn đề trên bằng cách:

1. **Camera-Based Heading Estimation**: Sử dụng Optical Flow từ camera để ước lượng hướng di chuyển (heading) của xe, bổ sung và thay thế khi GPS suy giảm. Kết hợp với IMU và GPS qua Adaptive Complementary Filter + Kalman Filter.
2. **Real-time Object Detection**: Mô hình YOLOv8-nano chạy trên thiết bị để phát hiện 6 loại vật cản (ô tô, xe máy, xe buýt, xe tải, người đi bộ, xe đạp) và cảnh báo bằng giọng nói tiếng Việt.
3. **Vietnamese Voice Command**: Nhận diện lệnh bằng giọng nói tiếng Việt thông qua `speech_to_text`, cho phép mở các tính năng chính (tầm nhìn, vệ tinh, trang chủ) mà không cần chạm màn hình.

### 1.4. Mô hình kiến trúc

Ứng dụng áp dụng **Clean Architecture** theo feature-based organization, tách biệt thành 3 lớp rõ ràng trong mỗi feature:

- **Domain Layer**: Chứa entities (đối tượng nghiệp vụ), repositories interface, và use cases. Lớp này không phụ thuộc vào bất kỳ framework hay thư viện bên ngoài nào, đảm bảo tính thuần túy của logic nghiệp vụ.
- **Data Layer**: Chứa data sources (API, local storage), models (JSON serialization), và repository implementations. Lớp này triển khai các interface từ domain layer, giao tiếp với thế giới bên ngoài.
- **Presentation Layer**: Chứa BLoC/Cubit (state management mới) hoặc ChangeNotifier (legacy), pages, widgets. Lớp này quản lý giao diện người dùng và phản hồi trạng thái ứng dụng.

**Quản lý trạng thái** đang trong giai đoạn chuyển đổi:
- **Mục tiêu**: `flutter_bloc` + `GetIt` (dependency injection) — phân tách rõ ràng event/state, dễ test, dễ mở rộng.
- **Hiện tại**: `provider` + `ChangeNotifier` (legacy) — vẫn còn sử dụng ở `FlowController`, `TripController`, `NavigationController`, `VoiceController`.
- Hai pattern cùng tồn tại; các controller legacy sẽ được migrate dần sang BLoC.

**Xử lý lỗi thống nhất**: Tất cả use cases trả về `dartz.Either<Failure, T>` với 9 loại Failure chuyên biệt: `VisionFailure`, `CameraFailure`, `AIFailure`, `SensorFailure`, `LocationFailure`, `StorageFailure`, `NetworkFailure`, `CacheFailure`, `UnknownFailure`. Mỗi loại có mã lỗi và thông báo riêng, giúp trace dễ dàng.

### 1.5. Cấu trúc thư mục

```
lib/
├── core/                          # Hạ tầng dùng chung
│   ├── errors/                   # Failure & Exception hierarchy
│   ├── constants/                # AppConstants (tham số toàn cục)
│   ├── providers/                # ThemeProvider (dark/light mode)
│   ├── widgets/                  # ModernUI system (13+ reusable widgets)
│   │   ├── modern_ui.dart        # ModernButton, ModernCard, ModernTextField...
│   │   └── modern_animations.dart # EntranceAnimation, StaggeredListView...
│   ├── utils/                    # GetIt injection container
│   ├── app_theme.dart            # Material 3 theme, gradients, UIConsts
│   ├── page_transitions.dart     # 10 transition types
│   ├── extensions/               # BuildContext extensions
│   └── pages/                    # SplashScreen, OnboardingScreen
│
├── features/                      # Feature modules (Clean Architecture)
│   ├── vision/                   # Thị giác máy tính & Sensor Fusion
│   │   ├── domain/
│   │   │   ├── entities/        # MotionVector, Obstacle, FrameResult
│   │   │   ├── repositories/    # VisionRepository interface
│   │   │   ├── usecases/        # ProcessFrame, DetectObstacles, GetHeading
│   │   │   └── utils/           # CVCore, KalmanFilter, MotionEstimator,
│   │   │                          FeatureTracker, SensorFusion
│   │   ├── data/
│   │   │   ├── datasources/     # CVDataSource, AIDataSource, SensorDataSource
│   │   │   ├── models/          # FrameResultModel, ObstacleModel
│   │   │   └── repositories/    # VisionRepositoryImpl
│   │   └── presentation/
│   │       ├── bloc/            # VisionBloc (partial)
│   │       ├── controllers/     # FlowController (legacy, actively used)
│   │       ├── pages/           # FlowPage, NavigationVisionPage, SatellitePage
│   │       └── widgets/         # FlowPainter, DirectionArrowPainter,
│   │                             NavigationMapWidget, TurnInstructionCard
│   │
│   ├── map/                      # Bản đồ & Điều hướng
│   │   ├── domain/
│   │   │   ├── entities/        # MapMarker, NavigationRoute, NavigationStep,
│   │   │   │                      NavigationState
│   │   │   ├── repositories/    # MapRepository, NavigationRepository
│   │   │   └── usecases/        # AddMarker, GetMarkers, GetStaticMapRoute
│   │   ├── data/
│   │   │   ├── datasources/     # GoongSearchDataSource, GoongDirectionsDataSource
│   │   │   ├── models/          # NavigationRouteModel (polyline decoder)
│   │   │   └── repositories/    # NavigationRepositoryImpl
│   │   └── presentation/
│   │       ├── bloc/            # MapHomeBloc (11 events, rich state)
│   │       ├── controllers/     # MapHomeController, NavigationController (legacy)
│   │       └── pages/           # MapHomeScreenV2
│   │           └── widgets/     # MapSearchBar, MapPlaceSheet,
│   │                             MapNavigationTopBar, MapNavigationPanel,
│   │                             MapFloatingButtons, StaticMapWidget, AppDrawer
│   │
│   ├── trip/                     # Quản lý hành trình
│   │   ├── domain/
│   │   │   ├── entities/        # Trip, MediaFile
│   │   │   ├── repositories/    # TripRepository interface
│   │   │   └── usecases/        # GetAllTrips, CreateTrip, DeleteTrip
│   │   ├── data/
│   │   │   ├── datasources/    # TripLocalDataSource (Hive), TripService (legacy)
│   │   │   ├── models/          # TripModel, MediaFileModel (dual model hierarchy)
│   │   │   └── repositories/    # TripRepositoryImpl
│   │   └── presentation/
│   │       ├── bloc/             # TripBloc (8 events)
│   │       ├── controllers/      # TripController (legacy)
│   │       └── pages/            # TripManagerPage, TripDetailPage, CreateTripPage
│   │
│   └── voice/                    # Điều khiển bằng giọng nói
│       ├── domain/
│       │   ├── entities/         # VoiceCommand, VoiceCommandType
│       │   └── repositories/     # VoiceRepository interface
│       └── presentation/
│           └── controllers/      # VoiceController (legacy)
│
├── shared/                        # Shared services
│   └── data/services/            # LocationService, SensorService,
│                                  TTSService, MediaService,
│                                  VoiceFeedbackService
│
├── main.dart                      # Entry point (MultiProvider, Hive init, dotenv)
```

---

## CHƯƠNG II: CHI TIẾT CHỨC NĂNG ỨNG DỤNG

### 2.1. Feature Vision — Thị giác máy tính & Cảm biến fusion

#### 2.1.1. Tổng quan chức năng

Feature Vision là module phức tạp nhất và là trái tim của ứng dụng. Module này nhận đầu vào từ ba nguồn cảm biến — camera (hoặc video file), GPS, và IMU — xử lý qua pipeline Computer Vision và Sensor Fusion, rồi xuất ra các kết quả: heading đã fuse, vector chuyển động, danh sách vật cản, và thông tin vị trí текущу chọn cho UI và voice feedback.

Các chức năng chính bao gồm:

**a) Phân tích video thời gian thực**: Hệ thống đọc khung hình từ camera hoặc file video qua `cv.VideoCapture`, xử lý trong một Dart Isolate riêng biệt để không làm block UI thread. Tốc độ mục tiêu là 30 fps, với khung hình được resize xuống 240 pixel chiều rộng để tối ưu hiệu năng. Mỗi khung hình đi qua toàn bộ pipeline: grayscale conversion → feature detection → optical flow tracking → RANSAC motion estimation → Kalman filtering → sensor fusion.

**b) Phát hiện và theo dõi điểm đặc trưng**: Sử dụng thuật toán Shi-Tomasi Corner Detection để tìm các điểm đặc trưng (corner points) đáng theo dõi trong ảnh, sau đó tracking chúng qua các khung hình liên tiếp bằng Pyramidal Lucas-Kanade Optical Flow. Hệ thống quản lý điểm theo dấu bằng Spatial Grid Feature Bucketing — chia khung hình thành lưới 4×3, đảm bảo phân bố đều và không bị tập trung tại một vùng.

**c) Ước lượng chuyển động robust**: Vector chuyển động của camera được ước lượng bằng RANSAC (Random Sample Consensus) để loại bỏ outlier — các điểm bị ảnh hưởng bởi vật thể di động độc lập (xe cộ, người đi bộ) hoặc nhiễu. Sau RANSAC, weighted least-squares refinement với trọng số 1/(1+error) giúp ước lượng chính xác hơn, và Kalman Filter 2D (4-state) làm mịn kết quả theo thời gian.

**d) Phát hiện vật cản bằng AI**: Mô hình YOLOv8-nano chạy inference trên thiết bị (TFLite) mỗi 10 khung hình, phát hiện 6 loại vật cản: ô tô (car), xe máy (motorcycle), xe buýt (bus), xe tải (truck), người đi bộ (person), xe đạp (bicycle). Vùng bounding box phát hiện được mở rộng 15% và giữ lại trong 20 khung hình sau, tạo thành "forbidden zones" loại trừ khỏi optical flow tracking — tránh tracker bị ảnh hưởng bởi chuyển động của vật thể độc lập.

**e) Cảm biến fusion (Sensor Fusion)**: Dữ liệu từ ba nguồn (vision heading delta, GPS absolute heading, IMU lateral acceleration) được kết hợp qua Adaptive Weighted Complementary Filter với trọng số thích ứng dựa trên confidence, quality, số điểm tracking, và GPS accuracy. Khi GPS suy giảm hoặc mất tín hiệu, hệ thống tự động chuyển sang dead reckoning (định vị suy diễn) sử dụng vận tốc góc dự đoán từ Kalman Filter và vision delta. IMU bump suppression phân biệt giữa chuyển động thực sự và rung lắc do ổ gà, tốc độ giảm, v.v.

**f) Cảnh báo giọng nói**: VoiceFeedbackService tạo ra các thông báo tiếng Việt tự nhiên: cảnh báo vật cản ("Cảnh báo! Xe hơi phía trước"), cảnh báo rẽ ("Rẽ nhẹ bên trái"), và thông báo trạng thái tracking. Service sử dụng cơ chế throttle — không lặp lại cùng cảnh báo trong vòng 2 giây (1 giây cho cảnh báo khẩn cấp), đảm bảo không gây phiền toái cho tài xế.

#### 2.1.2. Pipeline xử lý khung hình chi tiết

Quá trình xử lý một khung hình đi qua các bước sau, thực hiện chủ yếu trong Dart Isolate (`_videoWorker`):

**Bước 1 — Khung hình đầu vào**: Video frame được đọc từ `cv.VideoCapture`, resize xuống 240px chiều rộng (giảm 5-10x lượng pixel so với resolution gốc), đảm bảo xử lý ổn định 30 fps trên thiết bị mobile.

**Bước 2 — Chuyển đổi ảnh xám**: `cv.cvtColor(frame, cv.COLOR_BGR2GRAY)` chuyển ảnh màu sang grayscale, loại bỏ thông tin màu sắc không cần thiết cho optical flow và feature detection, giảm chiều dữ liệu từ 3 kênh xuống 1 kênh.

**Bước 3 — Xây dựng vùng cấm (Forbidden Zones)**: Bounding boxes từ YOLOv8 detection được mở rộng 15% mỗi phía (ví dụ: box 100×60 → 115×69) và giữ lại trong 20 khung hình sau lần phát hiện cuối cùng (temporal persistence). Các vùng này được kết hợp với ROI mask (chỉ sử dụng 60% phía dưới của khung hình, bỏ 40% phía trên thường là bầu trời) thành một combined mask đầu vào cho feature detection. Điểm nào nằm trong forbidden zone sẽ bị loại khỏi optical flow tracking.

**Bước 4 — Phát hiện điểm đặc trưng**: `cv.goodFeaturesToTrack()` sử dụng thuật toán Shi-Tomasi để tìm các điểm góc (corner) đáng theo dõi. Số điểm mục tiêu thay đổi adaptive theo confidence: 42 điểm khi tracking tốt (confidence > 0.7), tăng lên 72 điểm khi confidence thấp. Các điểm có `qualityLevel` dưới 0.03 (tức eigenvalue nhỏ nhất < 3% eigenvalue lớn nhất toàn ảnh) bị loại.

**Bước 5 — Tracking bằng Optical Flow**: `cv.calcOpticalFlowPyrLK()` theo dõi các điểm từ khung hình trước sang khung hình hiện tại, sử dụng Pyramidal Lucas-Kanade với window 15×15 và 2 mức pyramid. Kết quả là tập các cặp điểm tương ứng (oldPoints → newPoints) cùng với status flag cho từng điểm.

**Bước 6 — Lọc điểm**: Các điểm có status = false (không tracking được), nằm ngoài frame bounds, hoặc nằm trong forbidden zones bị loại bỏ. Số điểm còn lại quyết định confidence của kết quả.

**Bước 7 — RANSAC Motion Estimation**: Thuật toán RANSAC chạy 80 vòng lặp, mỗi vòng chọn 1 điểm ngẫu nhiên làm hypothesis cho translation vector, đếm inlier với threshold 4.0 pixel. Model tốt nhất (nhiều inlier nhất) được refine bằng weighted least-squares với trọng số `w = 1/(1+error)`. Kết quả trả về: motion vector, số inlier, confidence, và quality score.

**Bước 8 — Kalman Filter 2D Smoothing**: Nếu RANSAC trả về ≥ 8 inliers và confidence > 0.3, Kalman Filter 4-state [x, y, vx, vy] thực hiện predict-update cycle (dt = 0.033s). Kết quả Kalman được sử dụng nếu uncertainty < 10 pixel và motion < 50 pixel; ngược lại fallback sang double exponential smoothing. Nếu confidence thấp, toàn bộ kết quả RANSAC bị giảm xuống còn 30%.

**Bước 9 — Gửi kết quả về main thread**: IsolateResult (tracked points, smoothed motion vector, forbidden zones, confidence, inlier count, JPEG-encoded frame) được gửi về main thread qua SendPort.

**Bước 10 — Xử lý main thread (FlowController)**:
- Cập nhật UI: FlowPainter vẽ debug grid, tracking points, motion vector arrow, obstacle bounding boxes.
- Mỗi 10 khung hình: Chạy YOLOv8 inference (TFLite) để phát hiện vật cản, filter 6 class (car, motorcycle, bus, truck, person, bicycle), gửi bounding boxes về isolate cho forbidden zone mask.
- Sensor Fusion: Gọi `SensorFusion.update()` với vision dx, GPS heading, IMU accel-Y, tracked points count, GPS accuracy, confidence, quality → tính toán fused heading cuối cùng.
- Voice feedback: `VoiceFeedbackService.alertObstacle()` khi phát hiện vật cản mới, `alertTurn()` khi phát hiện rẽ.

#### 2.1.3. Entities (Domain Layer)

Ba entity chính trong feature Vision:

**MotionVector** — Đại diện cho vector chuyển động ước lượng từ optical flow:
- `vector` (Offset): Dịch chuyển pixel giữa hai khung hình
- `confidence` (double, 0-1): Độ tin cậy từ RANSAC (inlier ratio × min(magnitude/3, 1))
- `inlierCount` (int): Số điểm inlier trong RANSAC
- `quality` (double, 0-1): Chất lượng tracking (0.4 × coverage + 0.6 × avgQuality)
- Computed property `magnitude` = `vector.distance`, chiều dài Euclidean của vector

**Obstacle** — Đại diện cho vật cản phát hiện bởi AI:
- `boundingBox` (Rect): Vùng bounding box trên ảnh
- `label` (String): Loại vật cản (car, motorcycle, bus, truck, person, bicycle)
- `confidence` (double, 0-1): Độ tin cậy của mô hình detection
- Computed: `area` = diện tích bounding box, `center` = tâm bounding box

**FrameResult** — Tổng hợp kết quả xử lý một khung hình:
- `trackedPoints` (List\<Offset\>): Các điểm đang được theo dõi
- `motionVector` (MotionVector?): Vector chuyển động ước lượng
- `obstacles` (List\<Obstacle\>): Danh sách vật cản phát hiện
- `fusedHeading` (double): Heading đã fuse từ sensor fusion
- `speed` (double): Tốc độ di chuyển (từ GPS)
- `hasValidGps` (bool): GPS có khả dụng không
- `isModelLoaded` (bool): Mô hình YOLO đã load chưa
- `voiceEnabled` (bool): Voice feedback đang bật không
- `timestamp` (Duration): Thời điểm xử lý

---

### 2.2. Feature Map — Bản đồ & Điều hướng

#### 2.2.1. Tổng quan chức năng

Feature Map cung cấp trải nghiệm điều hướng hoàn chỉnh, từ tìm kiếm địa điểm đến hiển thị tuyến đường và theo dõi vị trí thời gian thực. Module này sử dụng **Goong Maps API** (dịch vụ bản đồ Việt Nam) cho geocoding và routing, **Mapbox Maps SDK Flutter** cho render bản đồ, và tích hợp trực tiếp với feature Vision thông qua nút "GNSS-Vision" trên màn hình điều hướng.

**a) Tìm kiếm địa điểm (Place Search)**: Khi người dùng nhập text vào thanh tìm kiếm, `MapHomeBloc` đợi 500ms (debounce) rồi gọi Goong Places API autocomplete. Kết quả hiển thị dạng danh sách gợi ý với main text (tên địa điểm) và secondary text (địa chỉ chi tiết). Khi chọn một kết quả, app gọi `getPlaceDetail()` để lấy đầy đủ thông tin: tọa độ (latitude, longitude), số điện thoại, rating, giờ mở cửa, website, types.

**b) Tính toán tuyến đường (Route Calculation)**: Sau khi chọn điểm đến, app gọi Goong Directions API với tham số origin (vĩ độ, kinh độ hiện tại), destination, vehicle (car/bike/foot), và `alternatives=true` để nhận nhiều tuyến đường dự phòng. Mỗi tuyến đường trả về: tổng khoảng cách (mét và text), tổng thời gian (giây và text), danh sách bước điều hướng (NavigationStep), và encoded polyline để vẽ lên bản đồ.

**c) Hiển thị bản đồ**: Mapbox Maps SDK render bản đồ với hai style: `navigation_day` và `navigation_night`, tự động chuyển theo theme. Bản đồ hiển thị tuyến đường dưới dạng GeoJSON LineString với 5 lớp vẽ (inner glow, outer glow, casing, line, highlight), mũi tên hướng dọc tuyến (computed bằng geodesic bearing formula), và vòng tròn đánh dấu vị trí hiện tại + điểm đến.

**d) Điều hướng theo bước (Turn-by-turn Navigation)**: `NavigationController` quản lý trạng thái phiên điều hướng (idle → navigating → paused), theo dõi current step index, và tính toán tiến độ hoàn thành (progressPercentage). Mỗi `NavigationStep` chứa: instruction (ví dụ: "Rẽ trái vào Nguyễn Trãi"), distance, duration, maneuver type, maneuver modifier, start/end coordinates.

**e) Chế độ Heading-Up**: Khi bật, bản đồ tự động xoay theo heading của người dùng (từ GPS hoặc vision-fused), chế độ pitch 65° tạo góc nhìnntp perspective. Heading được làm mịn bằng Exponential Moving Average (alpha = 0.3) để tránh jerkiness.

**f) Tích hợp Vision**: Nút "GNSS-Vision" ở panel điều hướng mở `NavigationVisionPage` — màn hình PiP (Picture-in-Picture) hiển thị camera/vision overlay bên cạnh bản đồ điều hướng, cho phép đồng thời xem bản đồ và nhận cảnh báo vật cản.

#### 2.2.2. Entities (Domain Layer)

**MapMarker** — Điểm đánh dấu trên bản đồ:
- `id` (String): Định danh duy nhất
- `title` (String): Tiêu đề hiển thị
- `description` (String?, optional): Mô tả chi tiết
- `latitude`, `longitude` (double): Tọa độ địa lý
- `type` (String): Loại marker (ví dụ: "destination", "waypoint")
- `createdAt` (DateTime): Thời gian tạo

**NavigationRoute** — Tuyến đường điều hướng hoàn chỉnh:
- `id` (String): Định danh
- `totalDistance` (double): Tổng khoảng cách (mét)
- `totalDuration` (double): Tổng thời gian (giây)
- `distanceText` (String): Khoảng cách dạng text ("5.2 km")
- `durationText` (String): Thời gian dạng text ("12 phút")
- `steps` (List\<NavigationStep\>): Danh sách các bước điều hướng
- `polyline` (List\<List\<double\>\>): Đường đi dạng tọa độ [[lng, lat], ...]
- `originLat`, `originLng`, `destLat`, `destLng` (double): Tọa độ điểm đầu/cuối
- `destinationName` (String): Tên điểm đến

**NavigationStep** — Một bước maneuver trên tuyến đường:
- `instruction` (String): Mô tả hướng dẫn ("Rẽ trái vào Nguyễn Trãi")
- `distance` (double): Khoảng cách bước (mét)
- `duration` (double): Thời gian bước (giây)
- `maneuverType` (ManeuverType): Loại maneuver — 13 giá trị enum: `depart`, `arrive`, `turn`, `fork`, `roundabout`, `merge`, `onRamp`, `offRamp`, `ferry`, `continueStraight`, `endOfRoad`, `newName`, `notification`
- `maneuverModifier` (String?, optional): Chi tiết thêm ("left", "right", "slight left", "sharp right", "uturn")
- `startLat`, `startLng`, `endLat`, `endLng` (double): Tọa độ bắt đầu và kết thúc
- `name` (String?, optional): Tên đường

**NavigationState** — Trạng thái phiên điều hướng:
- `status` (NavigationStatus): `idle` (chưa bắt đầu), `navigating` (đang điều hướng), `paused` (tạm dừng)
- `route` (NavigationRoute?): Tuyến đường hiện tại
- `currentStepIndex` (int): Bước điều hướng hiện tại
- `isHeadingRotated` (bool): Chế độ heading-up đang bật hay tắt

#### 2.2.3. Encoded Polyline Decoder

Khi nhận phản hồi từ Goong Directions API, tuyến đường được mã hóa dưới dạng **Encoded Polyline** — một thuật toán nén do Google phát triển. Hàm `_decodePolyline(String encoded)` trong `NavigationRouteModel` thực hiện giải mã theo quy trình:

1. Khởi tạo các biến index = 0, lat = 0, lng = 0
2. Vòng lặp đọc từng tọa độ (latitude, rồi longitude):
   - Đọc 5-bit groups: Mỗi 5 bit, kiểm tra bit thứ 6 (0x20) để biết còn tiếp hay không. Giá trị mỗi nhóm = ASCII code - 63.
   - Assemble bits: Shift trái và OR để ghép các 5-bit groups thành một số nguyên.
   - Zigzag decode: Nếu bit cuối cùng (LSB) là 1, đảo tất cả các bit phía trên: `result = (result & 1) == 1 ? ~(result >> 1) : (result >> 1)`. Đây là cách mã hóa số âm thành số dương (zigzag encoding).
   - Delta decoding: Cộng dồn delta vào giá trị tuyệt đối của latitude/longitude trước đó.
   - Chia cho 1E5 (100000) để khôi phục 5 chữ số thập phân.
3. Kết quả: `List<List<double>>` với mỗi phần tử là `[longitude, latitude]` theo thứ tự GeoJSON.

Thuật toán này cho phép nén một tuyến đường hàng ngàn điểm tọa độ xuống một chuỗi ASCII ngắn gọn, tiết kiệm băng thông mạng đáng kể.

---

### 2.3. Feature Trip — Quản lý hành trình

#### 2.3.1. Tổng quan chức năng

Feature Trip cho phép người dùng ghi lại và quản lý các hành trình di chuyển. Mỗi hành trình (Trip) bao gồm thông tin cơ bản (tên, mô tả, điểm xuất phát/đích, khoảng cách, thời gian) và có thể đính kèm các file media (ảnh, video, audio). Dữ liệu được lưu trữ cục bộ bằng Hive — một NoSQL embedded database nhẹ, cho phép read/write nhanh mà không cần server.

**a) Tạo hành trình**: Người dùng mở màn hình `CreateTripScreen`, tương tác với bản đồ Mapbox để chọn điểm xuất phát và điểm đến (hoặc nhập text tìm kiếm qua Goong Places API). App gọi Goong Directions API để tính khoảng cách và thời gian dự kiến. Khi tạo, Trip được gán UUID, timestamp, và lưu vào Hive box `trips`.

**b) Xem danh sách hành trình**: `TripManagerScreen` hiển thị danh sách trip dạng card với staggered animation (sliding in từ dưới lên). Mỗi card hiển thị: tên, ngày tạo, khoảng cách, thời gian, số lượng media, timeline xuất phát→đích, thumbnail strip từ media, và badge "Đang đi" nếu trip còn active.

**c) Xem chi tiết hành trình**: `TripDetailScreen` hiển thị đầy đủ thông tin: bản đồ nhỏ với marker xuất phát/đích và route line (sử dụng polyline decoder giống feature Map), summary (khoảng cách, thời gian), location timeline (địa chỉ xuất phát/đích), và media gallery dạng grid. Hỗ trợ full-screen media viewer với swipe navigation, video player cho file video, và camera/gallery picker để thêm media mới.

**d) Quan hệ dữ liệu**: Mỗi Trip tham chiếu đến MediaFile qua `mediaFileIds` (List\<String\>). Khi xóa Trip, tất cả MediaFile liên quan cũng bị xóa theo (cascade delete). MediaFile lưu trữ tọa độ (latitude, longitude) để có thể hiển thị trên bản đồ.

**e) Dual model hierarchy**: Do quá trình migration, hiện tồn tại hai bộ model song song:
- **Clean Architecture models** (`TripModel`, `MediaFileModel`): Extends Equatable, có JSON serialization, sử dụng `Either<Failure, T>` trong data source.
- **Legacy models** (`Trip`, `MediaFile` từ data/models/): Mutable, sử dụng Hive trực tiếp, đang dần được thay thế.

`TripRepositoryImpl` thực hiện mapping thủ công giữa hai hierarchy này, chuyển `TripModel.title` → `Trip.name`, `TripModel.completedAt` → `Trip.updatedAt`, v.v.

#### 2.3.2. Entities (Domain Layer)

**Trip** — Một hành trình di chuyển:
- `id` (String): Định danh duy nhất (UUID)
- `name` (String): Tên hành trình
- `description` (String?, optional): Mô tả
- `createdAt` (DateTime): Thời gian tạo
- `updatedAt` (DateTime?, optional): Thời gian cập nhật cuối
- `videoPath` (String?, optional): Đường dẫn file video ghi hình
- `thumbnailPath` (String?, optional): Đường dẫn thumbnail
- `distance` (double): Tổng khoảng cách (mét)
- `duration` (double): Tổng thời gian (giây)
- `mediaCount` (int): Số lượng media đính kèm
- `isSynced` (bool): Đã đồng bộ lên server chưa (dự phòng)

**MediaFile** — File media đính kèm:
- `id` (String): Định danh UUID
- `tripId` (String): ID của Trip chứa
- `path` (String): Đường dẫn file local
- `type` (MediaType): image, video, hoặc audio
- `createdAt` (DateTime): Thời gian tạo
- `latitude`, `longitude` (double?, optional): Tọa độ geotag
- `thumbnailPath` (String?, optional): Đường dẫn thumbnail (cho video)
- `duration` (double?, optional): Thời lượng (cho video/audio)
- `isSynced` (bool): Đã đồng bộ chưa

Quan hệ: **Trip 1 ──* MediaFile** (one-to-many). Mỗi trip có thể có nhiều media file, mỗi media file thuộc về một trip duy nhất thông qua `tripId`.

---

### 2.4. Feature Voice — Điều khiển bằng giọng nói

#### 2.4.1. Tổng quan chức năng

Feature Voice cung cấp khả năng điều khiển ứng dụng bằng giọng nói tiếng Việt, sử dụng `speech_to_text` package (wrapper quanh native speech recognition của thiết bị). Module này đặc biệt quan trọng trong bối cảnh điều hướng khi lái xe — người dùng không cần chạm màn hình.

**a) Nhận diện lệnh giọng nói**: `VoiceController` khởi tạo `SpeechToText` engine với locale `vi_VN` (tiếng Việt). Khi được kích hoạt, engine nghe liên tục trong tối đa 30 giây, tự dừng sau 3 giây im lặng (pause detection). Text được nhận dạng sẽ được so khớp với danh sách từ khóa:

| Từ khóa | Lệnh |
|---------|------|
| "gnss", "vision", "geennss", "định vị", "tầm nhìn" | Mở màn hình GNSS-Vision |
| "satellite", "globe", "3d", "vệ tinh", "quả cầu" | Mở màn hình Satellite 3D |
| "home", "back", "return", "trang chủ", "quay lại" | Về màn hình chính |

Cơ chế matching là simple substring matching — text nhận dạng được convert sang lowercase, sau đó kiểm tra xem có chứa bất kỳ từ khóa nào không. Cách này đơn giản nhưng hiệu quả cho tập lệnh nhỏ, không cần mô hình NLP phức tạp.

**b) Phản hồi giọng nói (Text-to-Speech)**: `VoiceFeedbackService` sử dụng `FlutterTts` với locale tiếng Việt (`vi-VN`) và fallback sang tiếng Anh nếu không khả dụng. Tốc độ nói 0.9, pitch 1.0, volume 1.0. Service tạo ra các thông báo tự nhiên:

- *1 vật cản*: "Cảnh báo! Xe hơi phía trước"
- *2-3 vật cản*: "Phát hiện 2 vật cản: Xe máy, Người đi bộ"
- *4+ vật cản*: "Cảnh báo! Nhiều vật cản phía trước, 4 vật thể"
- *Rẽ nhẹ*: "Rẽ nhẹ bên trái/trái" (góc rẽ 15°-45°)
- *Rẽ mạnh*: "Rẽ trái/phải" (góc rẽ > 45°)
- *Bỏ qua*: Góc rẽ < 15° không thông báo

Bảng dịch nhãn vật cản: car → "xe hơi", motorcycle → "xe máy", bus → "xe buýt", truck → "xe tải", person → "người đi bộ", bicycle → "xe đạp".

**c) Throttling**: Service thực hiện throttle để không lặp lại cùng cảnh báo trong vòng 2 giây (thời gian bình thường) hoặc 1 giây (cảnh báo khẩn cấp), tránh tình trạng nói liên tục khi vật cản xuất hiện ở nhiều khung hình liên tiếp.

**d) Lưu thiết lập**: Việc bật/tắt voice được lưu vào `SharedPreferences` với key `_voiceEnabledKey`, đảm bảo thiết lập được giữ khi khởi động lại app.

#### 2.4.2. Entity (Domain Layer)

**VoiceCommand** — Một lệnh giọng nói đã nhận diện:
- `id` (String): Định danh
- `command` (String): Lệnh đã nhận dạng
- `parameter` (String?, optional): Tham số bổ sung
- `timestamp` (DateTime): Thời điểm nhận dạng
- `confidence` (double?, optional): Độ tin cậy nhận dạng (0-1)

**VoiceCommandType** — Enum phân loại lệnh:
- `startNavigation`, `stopNavigation`, `pauseNavigation`, `resumeNavigation`
- `zoomIn`, `zoomOut`, `toggleMap`
- `repeatInformation`
- `unknown` (fallback)

**Lưu ý**: Chức năng nhận dạng lệnh hiện tại chỉ sử dụng keyword matching, chưa triển khai đầy đủ các loại lệnh trong `VoiceCommandType`. Repository interface `VoiceRepository` đã được định nghĩa nhưng chưa có implementation — module Voice đang ở giai đoạn sớm nhất trong migration sang Clean Architecture.

---

### 2.5. Màn hình Vệ tinh (Satellite View)

Màn hình vệ tinh cung cấp hình ảnh hóa trực quan về dữ liệu GNSS:

- **Quả cầu 3D**: Sử dụng `FlutterEarthGlobe` widget hiển thị quả cầu Trái Đất với texture ban đêm (earth-night.jpg), có thể xoay bằng touch gesture.
- **Điểm vệ tinh**: Vẽ các điểm vệ tinh phân bố theo chòm sao (GPS, GLONASS, GALILEO, BEIDOU, QZSS) trên quả cầu, kết nối bằng đường line từ vị trí vệ tinh đến tâm quả cầu.
- **Radar/Skyplot view**: Hiển thị góc nhìn từ trên xuống (skyplot) phân bổ vệ tinh theo elevation và azimuth, giúp đánh giá Dilution of Precision (DOP) trực quan.
- **Dữ liệu GNSS thực**: Sử dụng `EventChannel('gnss_status_channel')` để nhận raw GNSS data từ platform native (Android GnssStatus.Callback), bao gồm: satellite ID, elevation, azimuth, SNR, usedInFix.
- **Lọc chòm sao**: Người dùng có thể chọn hiển thị từng chòm sao riêng biệt hoặc tất cả, với màu sắc phân biệt.
- **Fallback dữ liệu mô phỏng**: Nếu không có GNSS thực (chạy trên emulator), hệ thống tự tạo dữ liệu giả lập với 4 chòm sao vệ tinh.

---

### 2.6. Màn hình Splash & Onboarding

**SplashScreen**: Hiển thị animation intro với logo GNSS Vision (CustomPainter vẽ pin vị trí + vệ tinh orbital rings + kim cương la bàn + hiệu ứng phát sáng), particle background, concentric ring rotations, và elastic logo entrance. Song song đó, app yêu cầu permissions (camera, location, microphone), đợi GetIt initialization (Hive boxes), rồi navigate sang `MapHomeScreenV2`.

**OnboardingScreen** (3 trang):
1. "Định Vị Thông Minh" — Giới thiệu khả năng định vị chính xác bằng GNSS + Vision + IMU
2. "Nhìn Thấu Mọi Trở Ngại" — Giới thiệu phát hiện vật cản bằng camera + AI
3. "Theo Dõi Vệ Tinh" — Giới thiệu chế độ xem vệ tinh GNSS 3D

Mỗi trang có gradient blob intro, phone mockup với fake UI, page dot navigation. Trang cuối có hiệu ứng "takeover" transition sang home screen với ripple/fill/flash effects.

---

## CHƯƠNG III: CÁC THUẬT TOÁN VÀ LÝ THUYẾT ĐÃ ÁP DỤNG

### 3.1. Pyramidal Lucas-Kanade Optical Flow

#### 3.1.1. Nền tảng lý thuyết

Optical Flow là phương pháp ước lượng vector chuyển động của mỗi pixel giữa hai khung hình liên tiếp, dựa trên giả thiết **brightness constancy** (giả thiết về sự bất biến độ sáng): pixels tương ứng giữa hai khung hình có cùng độ sáng. Phương trình cơ bản (Optical Flow constraint equation):

```
Ix · u + Iy · v + It = 0
```

Trong đó Ix, Iy là gradient không gian (theo x, y), It là gradient thời gian, và (u, v) là vector optical flow cần tìm.

Phương trình này có 2 ẩn (u, v) nhưng chỉ 1 phương trình → bài toán under-determined. **Phương pháp Lucas-Kanade** giải bằng cách giả thiết **tính liên tục cục bộ** (local smoothness): tất cả pixels trong một cửa sổ W×W có cùng vector (u, v). Khi đó, ta có hệ phương trình quá định:

```
[Ix₁  Iy₁]       [-It₁]
[Ix₂  Iy₂]       [-It₂]
[...   ... ] [u]  = [... ]
[Ixₙ  Iyₙ] [v]   [-Itₙ]

Giải bằng Least Squares:
[u]            [-It₁]
[v] = (AᵀA)⁻¹ Aᵀ · [... ]
                 [-Itₙ]

Trong đó:
A = [Ix₁  Iy₁]    b = [-It₁]
    [Ix₂  Iy₂]        [-It₂]
    [...  ... ]        [... ]
    [Ixₙ  Iyₙ]        [-Itₙ]
```

Tuy nhiên, Lucas-Kanade baseline chỉ hoạt động tốt cho chuyển động nhỏ (relatively small displacement). Khi vật thể di chuyển xa giữa hai khung hình, phương pháp thất bại vì giả thiết local smoothness bị vi phạm trong window kích thước nhỏ.

**Giải pháp: Pyramidal approach**. Xây dựng tháp ảnh (image pyramid) với L+1 mức phân giải (level 0 = gốc, level L = phân giản thấp nhất). Tại mỗi mức, ảnh được downsample bằng factor 2. Thuật toán bắt đầu ước lượng flow ở mức phân giản nhất (coarsest level L), rồi tinh chỉnh (refine) dần lên mức chi tiết nhất (finest level 0):

```
1. Xây dựng pyramid: I⁰, I¹, ..., Iᴸ (mỗi mức nhỏ hơn 2 lần mức trước)
2. Khởi tạo gᴸ = 0 (vector flow ở mức L)
3. FOR l = L xuống 0:
   a. Tính flow dˡ tại mức l bằng Lucas-Kanade window
   b. Propagate lên mức l-1: gˡ⁻¹ = 2 · (gˡ + dˡ)  (upscale 2×)
4. Flow cuối cùng: (u, v) = g⁰ + d⁰
```

Ưu điểm: WinSize nhỏ (15×15) vẫn bắt được chuyển động lớn nhờ coarse-to-fine strategy.

#### 3.1.2. Tham số và cách chọn

| Tham số | Giá trị | Lý do chọn |
|---------|---------|------------|
| `winSize` | 15×15 | Cửa sổ đủ lớn để capture cấu trúc cục bộ, đủ nhỏ để tính nhanh. 15×15 là giá trị phổ biến trong literatures, balance giữa accuracy và speed. |
| `maxLevel` | 2 | 3 mức pyramid (0, 1, 2). Với ảnh resize 240px, mức 2 có width ~60px — đủ để capture displacement lớn (hơn 30 pixel), nhưng vẫn có texture để track. |
| Target points | 42-72 (adaptive) | Baseline 60 điểm. Giảm xuống 42 khi confidence cao (ít điểm vẫn đủ, tiết kiệm CPU). Tăng lên 72 khi confidence thấp (cần nhiều điểm hơn để ước lượng chính xác). |

#### 3.1.3. File triển khai

- `lib/features/vision/domain/utils/cv_core.dart` — Pipeline chính (legacy, vẫn hoạt động)
- `lib/features/vision/data/datasources/cv_data_source_impl.dart` — Pipeline nâng cấp (RANSAC + Kalman)

---

### 3.2. Shi-Tomasi Corner Detection (goodFeaturesToTrack)

#### 3.2.1. Nền tảng lý thuyết

Để tracking optical flow hiệu quả, cần chọn các điểm đặc trưng (feature points) có thể được xác định duy nhất qua nhiều khung hình. Một cách tiếp cận phổ biến là **corner detection** — phát hiện các điểm mà gradient ảnh thay đổi mạnh theo mọi hướng.

Ma trận structure tensor tại một điểm (x, y) được định nghĩa:

```
M = [ΣIx²   ΣIxIy]
    [ΣIxIy  ΣIy²]

Trong đó:
- Ix = ∂I/∂x (gradient ảnh theo x)
- Iy = ∂I/∂y (gradient ảnh theo y)
- Σ tính trên cửa sổ lân cận W×W
```

Harris Corner Detection sử dụng response function:

```
R_Harris = det(M) - k · trace(M)² = λ₁λ₂ - k(λ₁ + λ₂)²
```

Trong đó k thường là 0.04-0.06. Điểm corner khi R_Harris > threshold.

**Shi-Tomasi** (1994) đề xuất cải tiến: thay vì dùng R_Harris, sử dụng **eigenvalue nhỏ nhất**:

```
R_ShiTomasi = min(λ₁, λ₂)
```

Điểm được chọn khi `R_ShiTomasi > qualityLevel · max(R)` trên toàn ảnh. Phương pháp này có nền tảng lý thuyết vững chắc hơn: nó trực tiếp yêu cầu cả hai eigenvalues đều lớn, đảm bảo gradient mạnh theo mọi hướng, tức là điểm có thể được localize chính xác.

#### 3.2.2. Tham số và cách chọn

| Tham số | Giá trị | Lý do chọn |
|---------|---------|------------|
| `maxCorners` | 42-72 (adaptive) | Baseline 60. Số điểm cân bằng giữa độ che phủ (coverage) và tốc độ xử lý. Adaptive dựa trên confidence: ít điểm khi tracking ổn định, nhiều điểm khi cần robust. |
| `qualityLevel` | 0.03 | Eigenvalue tối thiểu phải lớn hơn 3% eigenvalue lớn nhất. Threshold thấp để chấp nhận nhiều điểm trong condition khó (low light, low texture). |
| `minDistance` | 8.0 pixels | Đảm bảo các điểm phân tán tối thiểu 8 pixel, tránh cluster tại một vùng. Kết hợp với Spatial Grid Bucketing (4×3 grid) để đảm bảo coverage đồng đều. |

#### 3.2.3. ROI Masking

Chỉ 60% phía dưới của khung hình được sử dụng làm Region of Interest (ROI). Lý do: 40% phía trên thường là bầu trời hoặc cảnh xa — texture ít, không có thông tin chuyển động hữu ích cho việc ước lượng heading của xe. Việc loại bỏ vùng này giảm số điểm feature cần xử lý và tránh tracking cloud movement hoặc distant objects.

Ngoài ROI mask, **obstacle mask** cũng được áp dụng: bounding boxes từ YOLOv8 detection được mở rộng 15% và loại trừ khỏi ROI. Điều này ngăn tracker theo dõi chuyển động của vật thể độc lập (xe cộ, người đi bộ), vốn sẽ gây ra optical flow không chính xác cho heading estimation.

#### 3.2.4. File triển khai

- `lib/features/vision/domain/utils/cv_core.dart` — Hàm `goodFeaturesToTrack()` với ROI mask và obstacle exclusion

---

### 3.3. RANSAC (Random Sample Consensus)

#### 3.3.1. Nền tảng lý thuyết

Trong thực tế, optical flow tracking luôn tạo ra một số **outliers** — điểm bị sai do: vật thể di chuyển độc lập cắt ngang khung hình, nhiễu sensor, occlusion, hoặc running water/reflections. Nếu tính toán motion vector bằng trung bình đơn giản trên tất cả điểm, outliers sẽ kéo vector sai lệch rất nhiều.

**RANSAC** (Fischler & Bolles, 1981) là thuật toán ước lượng robust — nó tìm model phù hợp nhất với **tập con lớn nhất** của dữ liệu, loại bỏ outliers. Thuật toán đặc biệt phù hợp khi tỷ lệ outlier cao (lên đến 50%).

#### 3.3.2. Thuật toán triển khai chi tiết

Ứng dụng sử dụng mô hình **pure translation** — giả thiết camera chỉ dịch chuyển theo hướng ngang/dọc, không xoay (rotation negligible). Đây là giả thiết hợp lý cho camera gắn trên xe hơi khi xoay nhẹ (quay đầu không gây rotation đáng kể trong ROI 60% phía dưới).

```
Input: oldPoints[], newPoints[] — các cặp điểm tương ứng từ Lucas-Kanade
Output: motion vector, inlier count, confidence, quality

ALGORITHM:

1. Khởi tạo bestInlierCount = 0, bestMotion = (0,0), bestInliers = []

2. FOR i = 1 to 80 (RANSAC iterations):
   a. Chọn ngẫu nhiên 1 điểm index k
   b. Tính sampleMotion = oldPoints[k] - newPoints[k]
      → Đây là hypothesis: "tất cả điểm dịch chuyển cùng 1 vector"
   c. DUYỆT qua tất cả điểm j:
      error = ||oldPoints[j] - newPoints[j] - sampleMotion||
      NẾU error < 4.0 pixels → j là inlier
   d. NẾU số inliers > bestInlierCount:
      → Cập nhật best model

3. Weighted Least-Squares Refinement trên best inliers:
   CHO MỖI inlier j:
      error_j = ||oldPoints[j] - newPoints[j] - bestMotion||
      weight_j = 1 / (1 + error_j)           → Điểm có error nhỏ có trọng số cao
   TÍNH weighted centroid:
      motionX = Σ(weight_j × dx_j) / Σ(weight_j)
      motionY = Σ(weight_j × dy_j) / Σ(weight_j)

4. TÍNH confidence:
   inlierRatio = bestInlierCount / totalPoints
   confidence = inlierRatio × min(motionMagnitude / 3.0, 1.0)
   → Clamped vào [0, 1]
   → 少 motion quá nhỏ (< 3 pixels) thì confidence bị giảm,
     vì noise sẽ chiếm tỷ trọng lớn

5. TÍNH quality:
   quality = inlierRatio × (inlierCount >= 8 ? 1.0 : inlierCount / 8.0)
   → Chất lượng thấp nếu không đủ inliers tối thiểu

6. RETURN motion vector, inlier count, confidence, quality
```

**Tại sao chỉ cần 1 điểm cho mỗi hypothesis?** Vì mô hình pure translation chỉ có 2 tham số (dx, dy). Một điểm tương ứng cung cấp đủ 2 phương trình. Tuy nhiên, chạy 80 vòng lặp cho phép thử nhiều hypothesis và chọn ra cái có nhiều inlier nhất — tương đương với việc tìm ra vector dịch chuyển được đồng thuận bởi số đông.

**Weighted Least-Squares Refinement** là M-estimator với function `ρ(e) = |e|/(1+|e|)`, tương đương trọng số `w = 1/(1+e)`. Điều này giảm ảnh hưởng của inlier "xa" — những điểm phù hợp với model nhưng có error tương đối lớn — xuống mức chấp nhận được, thay vì let them pull equally như trong ordinary least squares.

#### 3.3.3. Tham số và cách chọn

| Tham số | Giá trị | Lý do chọn |
|---------|---------|------------|
| `ransacIterations` | 80 | Với tỷ lệ outlier ước lượng ~30-50%, 80 vòng cho xác suất tìm ra model đúng > 99.9% theo công thức `p = 1 - (1 - (1-ε)ⁿ)ᴺ` với n=1 (1 điểm per sample), ε=0.5, N=80 |
| `ransacThreshold` | 4.0 pixels | Ngưỡng inlier. 4 pixel cho phép sai số nhỏ từ measurement noise nhưng loại bỏ outliers rõ ràng. Trên ảnh 240px wide, 4px ~ 1.7% chiều rộng — đủ chặt cho motion estimation. |
| `minInliers` | 8 | Số inlier tối thiểu để chấp nhận kết quả. Dưới 8 điểm, ước lượng không đáng tin cậy. 8 điểm ~ 13% của 60 baseline points — nếu nhiều hơn 87% điểm là outlier, tình trạng tracking quá tệ để sử dụng. |

#### 3.3.4. File triển khai

- `lib/features/vision/domain/utils/motion_estimator.dart` — Class `MotionEstimator` chứa `estimateMotion()`, `filterOutliers()`, `computeMotionStatistics()`

---

### 3.4. Kalman Filter (2D Position + Angle)

#### 3.4.1. Nền tảng lý thuyết

Kalman Filter (Rudolf E. Kálmán, 1960) là thuật toán ước lượng trạng thái tối ưu theo nghĩa minimum mean-square error cho hệ thống tuyến tính với noise Gaussian. Nó là một recursive Bayesian estimator — cập nhật trạng thái mỗi khi có measurement mới, không cần lưu toàn bộ lịch sử.

Kalman Filter gồm hai bước:

**Predict (Dự đoán)**: Extrapolate trạng thái hiện tại dựa trên model động học.

```
x̂ₖ|ₖ₋₁ = F · x̂ₖ₋₁|ₖ₋₁        (Predicted state)
Pₖ|ₖ₋₁ = F · Pₖ₋₁|ₖ₋₁ · Fᵀ + Q   (Predicted covariance)

Trong đó:
- x̂ = state vector
- F = state transition matrix
- P = estimation error covariance
- Q = process noise covariance
```

**Update (Cập nhật)**: Kết hợp prediction với measurement mới.

```
Kₖ = Pₖ|ₖ₋₁ · Hᵀ · (H · Pₖ|ₖ₋₁ · Hᵀ + R)⁻¹   (Kalman Gain)
x̂ₖ|ₖ = x̂ₖ|ₖ₋₁ + Kₖ · (zₖ - H · x̂ₖ|ₖ₋₁)       (Updated state)
Pₖ|ₖ = (I - Kₖ · H) · Pₖ|ₖ₋₁                      (Updated covariance)

Trong đó:
- K = Kalman Gain (trọng số giữa prediction và measurement)
- z = measurement vector
- H = observation matrix
- R = measurement noise covariance
```

**Ý nghĩa vật lý**: Kalman Gain K quyết định mức tin tưởng prediction vs. measurement. Khi measurement noise R cao → K nhỏ → tin prediction hơn. Khi process noise Q cao → K lớn → tin measurement hơn.

#### 3.4.2. KalmanFilter2D — 4-state filter cho vị trí

Ứng dụng triển khai Kalman Filter 2D với vector trạng thái 4 chiều:

```
x = [px, py, vx, vy]ᵀ

Trong đó:
- (px, py): vị trí pixel của motion vector
- (vx, vy): vận tốc pixel/frame
```

**Model động học (Constant Velocity)**:

```
px(t+dt) = px + vx × dt
py(t+dt) = py + vy × dt
vx(t+dt) = vx      (giả thiết vận tốc không đổi)
vy(t+dt) = vy
```

Đây là mô hình **constant velocity** — giả thiết đơn giản nhất cho chuyển động. Dù thực tế xe tăng/giảm tốc, process noise Q bù đắp bằng cách cho phép state "dao động" quanh prediction.

**Implementation chi tiết**:

```dart
// PREDICT
void predict(double dt) {
  // State extrapolation: position += velocity * dt
  state[0] += state[2] * dt;    // px += vx * dt
  state[1] += state[3] * dt;    // py += vy * dt
  // Velocity giữ nguyên (constant velocity model)

  // Covariance extrapolation: P += Q * dt² (position) + Q * dt (velocity)
  // Sử dụng simplified diagonal covariance:
  // P[0] (px variance) += Q * dt²
  // P[5] (py variance) += Q * dt²
  // P[2] (vx variance) += Q  (không nhân dt vì xấp xỉ)
  // P[7] (vy variance) += Q
  covariance[0] += processNoise * dt * dt;    // Ppxx
  covariance[5] += processNoise * dt * dt;    // Ppyy
  covariance[2] += processNoise;               // Pvxvx  (diagonal approx)
  covariance[7] += processNoise;               // Pvyvy
}

// UPDATE
void update(double measurementX, double measurementY) {
  double innovationX = measurementX - state[0];
  double innovationY = measurementY - state[1];

  // Kalman Gain: K = P / (P + R)
  double gainX = covariance[0] / (covariance[0] + measurementNoise);
  double gainY = covariance[5] / (covariance[5] + measurementNoise);

  // State update: x̂ += K * innovation
  state[0] += gainX * innovationX;
  state[1] += gainY * innovationY;

  // Velocity update: v += K * innovation / dt
  // dt ≈ 0.033s (30fps) —_velocity được cập nhật dựa trên innovation position
  state[2] += gainX * innovationX / dt;
  state[3] += gainY * innovationY / dt;

  // Covariance update: P *= (1 - K)
  covariance[0] *= (1 - gainX);
  covariance[5] *= (1 - gainY);
  covariance[2] *= (1 - gainX);
  covariance[7] *= (1 - gainY);
}
```

**Lưu ý về simplified implementation**: Implementation này sử dụng diagonal covariance approximation — chỉ giữ các thành phần trên đường chéo chính (Ppxx, Ppyy, Pvxvx, Pvyvy). Điều này giả thiết rằng position x và y không tương quan, cũng như position và velocity không tương quan. Trong thực tế, chúng có thể tương quan (ví dụ: khi chuyển động theo đường chéo), nhưng simplified version vẫn hoạt động hữu hiệu vì:
1. Initial covariance rất lớn (500.0) nên Kalman Gain ban đầu cao → measurement được tin tưởng → state hội tụ nhanh.
2. Process noise và measurement noise được tune empirically để bù đắp cho simplification.

#### 3.4.3. KalmanFilterAngle — 2-state filter cho heading

Vector trạng thái 2 chiều cho ước lượng heading:

```
x = [θ, ω]ᵀ

Trong đó:
- θ: heading angle (độ, 0-360)
- ω: vận tốc góc (độ/giây)
```

**Đặc điểm quan trọng**: Heading angle là **circular variable** — 0° và 360° là cùng một hướng. Phải xử lý **wraparound** trong Kalman update:

```dart
void update(double measurementAngle) {
  predict(0.033);  // dt = 0.033s

  // Innovation với circular wrapping
  double innovation = measurementAngle - state[0];
  if (innovation > 180) innovation -= 360;
  if (innovation < -180) innovation += 360;
  // → innovation luôn trong [-180, 180]

  double gain = covariance[0] / (covariance[0] + measurementNoise);
  state[0] += gain * innovation;
  state[1] += gain * innovation / 0.033;

  // Normalize angle về [0, 360)
  state[0] = ((state[0] % 360) + 360) % 360;

  covariance[0] *= (1 - gain);
  covariance[1] *= (1 - gain);  // Simplified diagonal
}
```

**Mục đích**: KalmanFilterAngle được sử dụng bên trong `SensorFusion` để làm mịn heading cuối cùng sau khi complementary filter đã kết hợp vision và GPS. Nó giúp loại bỏ noise và giữ heading ổn định hơn, đặc biệt khi GPS jitter gây nhảy số.

#### 3.4.4. Tham số Kalman Filter

| Tham số | Giá trị | Giải thích |
|---------|---------|------------|
| P₀ (initial covariance) | 500.0 | Rất lớn → Kalman Gain ban đầu ≈ 1 → measurement được tin tưởng hoàn toàn ở những frame đầu. State hội tụ nhanh về giá trị thực. |
| Q (process noise, position) | 0.1 | Process noise thấp cho position → prediction mượt, ít nhảy. Không quá thấp để cho phép model theo kịp chuyển động thực. |
| Q (process noise, angle) | 0.05 | Process noise thấp hơn cho angle → heading ít noise hơn position. |
| R (measurement noise, position) | 1.0 | Measurement noise moderate → K ≈ 0.33 (sau khi hội tụ) → cân bằng giữa prediction và measurement. |
| R (measurement noise, angle) | 2.5-3.0 | Measurement noise cao hơn cho angle vì GPS heading có thể sai lớn, đặc biệt ở tốc độ thấp. |
| Uncertainty threshold | 10 pixels | Nếu `sqrt(Ppxx + Ppyy) > 10`, Kalman state không đáng tin cậy → fallback sang exponential smoothing. |
| dt | 0.033s | Frame interval ở 30 fps. Giả thiết cố định — không điều chỉnh theo frame time thực. |

#### 3.4.5. File triển khai

- `lib/features/vision/domain/utils/kalman_filter.dart` — KalmanFilter2D và KalmanFilterAngle

---

### 3.5. Adaptive Weighted Complementary Filter & Dead Reckoning

#### 3.5.1. Nền tảng lý thuyết

**Complementary Filter** là phương pháp fusion đơn giản nhưng hiệu quả: kết hợp hai nguồn dữ liệu có đặc tính tần số khác nhau — một nguồn có độ chính xác cao ở tần số thấp (GPS absolute heading) nhưng bị noise ở tần số cao, và nguồn khác có độ chính xác cao ở tần số cao (vision incremental heading) nhưng có drift ở tần số thấp.

Công thức cơ bản:

```
output = α × lowFreqSource + (1 - α) × highFreqSource

Trong đó:
- α ∈ [0, 1] là hệ số complementary
- α → 1: tin tưởng nguồn tần số thấp (GPS)
- α → 0: tin tưởng nguồn tần số cao (vision)
```

Trong ứng dụng, **α không cố định** mà thay đổi thích ứng (adaptive) dựa trên chất lượng từng nguồn tại mỗi thời điểm. Khi vision confidence cao → giảm α → tin vision hơn. Khi GPS accuracy thấp → giảm α → tin GPS ít hơn.

#### 3.5.2. Thuật toán SensorFusion chi tiết

Class `SensorFusion` triển khai toàn bộ pipeline fusion giữa vision, GPS, và IMU:

**Bước 1 — IMU Bump Suppression**

Khi xe đi qua ổ gà, tốc độ giảm, hoặc va chạm, accelerometer đo được gia tốc lớn dọc trục Y (lateral acceleration). Những sự kiện này tạo ra "bump" trong dữ liệu vision — chuyển động ngang đột ngột không phản ánh heading thực sự.

```
IF |imuAccelY| > 3.0 m/s²:
    bumpFactor = (|imuAccelY| - 3.0) / 10.0
    safeVisionDx = visionDx × max(0, 1 - bumpFactor)
ELSE:
    safeVisionDx = visionDx
```

- Ngưỡng 3.0 m/s²: Gia tốc lateral bình thường khi rẽ nhẹ (~1-2 m/s²) không bị suppress. Chỉ bump thật sự ( ổ gà, phanh gấp gây lateral jerk) mới bị attenuated.
- Công thức: Gia tốc 8 m/s² → bumpFactor = 0.5 → visionDx chỉ còn 50%. Gia tốc 13 m/s² → bumpFactor = 1.0 → visionDx = 0 (loại bỏ hoàn toàn).
- `max(0, ...)` đảm bảo visionDx không âm (không đảo chiều).

**Bước 2 — Vision Heading Delta Calculation**

```
visionHeadingDelta = -safeVisionDx × 0.3
```

- Dấu âm: Khi camera quay phải (quay đầu sang phải), pixels trong frame dịch sang trái (negative dx). Nhưng heading thực tế tăng (quay phải = góc tăng). V nên `headingDelta = -dx`.
- Hệ số 0.3: Đại diện cho chuyển đổi pixel-to-degree. Tại khoảng cách ~5m từ camera, 1 pixel horizontal tương ứng ~0.3°. Đây là giá trị xấp xỉ được tune empirically.

**Bước 3 — Adaptive Vision Weight Calculation**

```
IF confidence > 0.7 AND quality > 0.5:
    visionWeight = 0.8    // Vision rất tin cậy
ELIF confidence > 0.5:
    visionWeight = 0.6    // Vision khá tin cậy
ELIF confidence > 0.3:
    visionWeight = 0.4    // Vision trung bình
ELSE:
    visionWeight = 0.2    // Vision kém, chỉ sử dụng ít

// Degradation khi tracking points quá ít:
IF trackedPoints < 15:
    visionWeight = visionWeight × 0.3     // Giảm 70%
    alpha = alpha - 0.3                     // Tin GPS hơn
ELIF trackedPoints < 30:
    visionWeight = visionWeight × 0.6     // Giảm 40%
    alpha = alpha - 0.15                    // Tin GPS hơn một chút
```

Ý nghĩa: Khi feature points quá ít (< 15 điều kiện cực tồi, < 30 điều kiện trung bình), optical flow estimation không đáng tin cậy. Vision weight giảm mạnh, và alpha (GPS weight) tăng tương ứng để dựa vào GPS hơn.

**Bước 4 — GPS Quality Adjustment**

```
IF gpsAccuracy > 20 meters:
    alpha += visionWeight × 0.15    // GPS rất không chính xác → tăng vision weight
ELIF gpsAccuracy > 15 meters:
    alpha += visionWeight × 0.08    // GPS khá không chính xác → tăng vision weight
```

Logic: Khi GPS accuracy suy giảm (accuracy radius lớn), GPS heading cũng không chính xác. Thay vì bao gồm nhiều GPS noise vào fusion, ta tăng alpha thực tế... nhưng đợi đã, logic ngược: `alpha` là **GPS weight** trong complementary filter, nên tăng alpha = tin GPS hơn. Nhưng ở đây, ta muốn tin GPS ít hơn khi accuracy kém. Có vẻ như logic đang **giảm alpha hiệu quả** bằng cách cộng vision weight — tức là shift weight sang vision khi GPS kém.

Thực ra, cần đọc kỹ: `alpha` trong code là **base alpha** (= 0.90 mặc định), và điều chỉnh tăng khi GPS kém → nhưng điều này **đi ngược** với mong đợi. Có thể đây là bug hoặc convention khác (alpha = weight của low-frequency source = vision, không phải GPS). Phân tích thêm từ code source cho thấy thực tế alpha được sử dụng như **GPS weight** trong complementary filter, và code đang **giảm** alpha bằng cách cộng vision weight vào alpha base — có thể đây là cách hiệu chỉnh **thuật** để tính đến việc GPS không đáng tin.

Nhìn lại code cụ thể: khi `gpsAccuracy > 20`, `alpha += visionWeight × 0.15`. Base alpha = 0.90 + max boost = 0.9 + 0.8×0.15 = 1.02, nhưng alpha được clamp về [0.1, 0.98]. Vậy effect là: GPS kém → tăng alpha → tin GPS hơn → kết quả có vẻ sai.

**Nhưng** đây có thể là intentional: khi GPS accuracy rất kém (20m+), GPS heading vẫn có thể cung cấp absolute reference (dù không chính xác nhiều pixel), và việc tăng alpha giúp filter phục hồi từ vision drift dần dần. Nếu chỉ dựa vào vision hoàn toàn (alpha thấp), heading sẽ drift không kiểm soát.

**Bước 5 — Confidence Streak Adaptation**

```
IF consecutiveLowConfidence >= 5:
    alpha -= 0.1       // Vision đang kém kéo dài → tin GPS hơn để tránh noise
IF consecutiveHighConfidence >= 10:
    alpha += 0.05      // Vision đang ổn định kéo dài → tin vision hơn (cho precision cao hơn GPS jitter)

Alpha clamped to [0.1, 0.98]
```

Cơ chế streak: Confidence thấp quá 5 frames liên tiếp → giảm alpha (tin GPS). Confidence cao quá 10 frames liên tiếp → tăng alpha (cho phép vision contribute nhiều hơn vì đã ổn định). Streaks decay khi confidence ở giữa: `streak *= 0.8`.

**Bước 6 — Fusion Decision**

```
IF hasValidGPS:
    // COMPLEMENTARY FILTER: Kết hợp vision prediction với GPS correction
    predictedHeading = fusedHeading + visionHeadingDelta
    angleDiff = normalizeAngle(gpsHeading - predictedHeading)  // [-180, 180]
    fusedHeading = predictedHeading + (1 - alpha) × angleDiff
    
    // Sau đó: Kalman filter angle smooth
    kalmanFilterAngle.predict(0.033)
    kalmanFilterAngle.update(fusedHeading)

ELSE (GPS unavailable — DEAD RECKONING):
    // Kết hợp Kalman prediction (30%) và vision delta (70%)
    predictedDelta = kalmanFilterAngle.getAngularVelocity() × 0.033
    visionPredictedDelta = visionHeadingDelta
    finalDelta = 0.3 × predictedDelta + 0.7 × visionPredictedDelta
    fusedHeading = (fusedHeading + finalDelta) % 360
    
    // Kalman filter predict only (no GPS measurement to update with)
    kalmanFilterAngle.predict(0.033)
```

**Ý nghĩa của tỷ lệ dead reckoning 30/70**:
- 30% từ Kalman prediction: Giữ continuity từ heading trước đó, dựa trên vận tốc góc đã học.
- 70% từ vision: Vision cung cấp delta heading trực tiếp, chính xác hơn prediction khi mập môi trường chưa thay đổi đột ngột.
- Tỷ lệ này ưu tiên vision vì vision delta là measurement thực (dù absolute accuracy thấp), trong khi Kalman prediction chỉ là extrapolation từ state trước — error sẽ tích lũy nhanh nếu dựa hoàn toàn vào prediction.

#### 3.5.3. File triển khai

- `lib/features/vision/domain/utils/sensor_fusion.dart` — Class `SensorFusion` với `update()`, `reset()`, getters cho `fusedHeading`, `headingVelocity`

---

### 3.6. YOLOv8-nano Object Detection

#### 3.6.1. Nền tảng lý thuyết

YOLO (You Only Look Once) là họ kiến trúc object detection real-time. Khác với two-stage detectors (như R-CNN) cần crop region proposals rồi classify, YOLO xử lý toàn bộ ảnh trong một lần forward pass qua neural network, cho ra đồng thời bounding boxes, class probabilities, và confidence scores.

YOLOv8 (Ultralytics, 2023) là phiên bản mới nhất với kiến trúc improved:
- **Backbone**: Modified CSPDarknet với C2f module (Cross Stage Partial Bottleneck with 2 convolutions)
- **Neck**: PANet (Path Aggregation Network) cho multi-scale feature fusion
- **Head**: Decoupled head — tách riêng classification và regression, anchor-free detection
- **YOLOv8-nano (yolov8n)**: Biến thể nhỏ nhất với 3.2M parameters, 8.7 GFLOPs — đủ nhẹ để chạy trên mobile devices qua TFLite

#### 3.6.2. Cách ứng dụng sử dụng YOLOv8

- **Model format**: `.tflite` (TensorFlow Lite) — nằm trong `assets/yolov8n.tflite`
- **Inference engine**: `flutter_vision` package (native TFLite delegate)
- **Frequency**: Mỗi 10 khung hình (≈ 3 lần/giây ở 30fps), không phải mỗi frame vì inference tốn ~100-200ms trên mobile
- **Class filter**: Chỉ giữ 6 class liên quan đến giao thông: car, motorcycle, bus, truck, person, bicycle
- **Confidence threshold**: 0.2 — Threshold thấp (so với 0.5 thông thường) để đảm bảo phát hiện vì vật cản ở xa/th nhỏ nhất cần được cảnh báo, chấp nhận false positive tạm thời vì forbidden zone mask sẽ loại trừ chúng khỏi optical flow
- **IoU threshold (NMS)**: 0.4 — Non-Maximum Suppression threshold, loại bỏ overlapping boxes trùng lặp
- **Output**: Danh sách `Obstacle` objects với bounding boxes được gửi về Isolate để tạo forbidden zones

**Forbidden Zone Handling**: Mỗi bounding box phát hiện được mở rộng 15% mỗi phía (ví dụ: box 100×60 → 115×69 pixel) để tạo buffer zone an toàn. Vùng mở rộng này được giữ lại trong 20 khung hình sau lần phát hiện cuối cùng (temporal persistence). Điều này xử lý trường hợp detection miss ở một số frame — nếu xe cộ bị che khuất tạm thời ở frame 5, forbidden zone vẫn tồn tại đến frame 25, không cho phép tracker bám vào vật cản đó.

#### 3.6.3. File triển khai

- `lib/features/vision/presentation/controllers/flow_controller.dart` — YOLO inference logic, class filtering, obstacle management

---

### 3.7. Spatial Grid Feature Bucketing

#### 3.7.1. Nền tảng lý thuyết

Một vấn đề phổ biến với feature detection dựa trên quality (như Shi-Tomasi) là **clustering**: các điểm đặc trưng thường tập trung ở vùng có nhiều texture (ví dụ: tòa nhà, biển báo), bỏ trống các vùng ít texture (bầu trời, đường trống). Điều này dẫn đến optical flow estimation bị bias — vector trung bình phản ánh chuyển động ở vùng nhiều điểm hơn, không phản ánh chuyển động toàn khung hình.

**Spatial Grid Feature Bucketing** giải quyết bằng cách chia khung hình thành lưới (grid) và giới hạn số điểm mỗi ô. Điểm mới chỉ được thêm vào ô nếu ô đó chưa đạt max. Điểm cũ được pruning dựa trên quality và lifetime.

#### 3.7.2. Thuật toán chi tiết

```
1. CHIA khung hình thành 4×3 grid (12 cells)
2. MỖI ô giữ tối đa 5 điểm, tối thiểu 1 điểm
3. MATCHING: So khớp điểm mới với điểm cũ bằng proximity threshold 15 pixels
   → Nếu điểm mới nằm gần điểm cũ (< 15px), cập nhật quality và lifetime
4. QUALITY BLENDING: newQuality = max(existing, 0.8 × new + 0.2 × existing)
   → Ưu tiên measurement mới nhưng không bỏ hoàn toàn history
5. LIFETIME MANAGEMENT:
   - Mỗi frame: lifetime++
   - Nếu lifetime > 90: loại điểm (stale)
   - Nếu quality < 0.01: loại điểm (unreliable)
6. TRACKING QUALITY SCORE:
   qualityScore = 0.4 × coverageScore + 0.6 × avgQuality
   coverageScore = activeCells / totalCells (tỷ lệ ô đang có điểm)
   → Score cân bằng giữa spatial coverage và per-point quality
```

**Ý nghĩa các tham số**:

| Tham số | Giá trị | Giải thích |
|---------|---------|------------|
| Grid size | 4×3 | 12 ô cho ảnh ~240×180px. Mỗi ô ≈ 60×60px — đủ lớn để chứa nhiều texture, đủ nhỏ để phân biệt vùng. |
| Max points/cell | 5 | 5 × 12 = 60 điểm tối đa toàn frame, phù hợp với optical flow performance. |
| Min points/cell | 1 | Đảm bảo mỗi vùng có ít nhất 1 representative point. |
| Proximity threshold | 15 px | Ngưỡng matching. 15 pixel cho phép slight displacement giữa frames (motion < 15px/frame ~ 450px/s ở 30fps, tương đương chuyển động rất nhanh). |
| Max lifetime | 90 frames | 90/30fps = 3 giây. Sau 3 giây, điểm được thay mới để tránh drift — điểm có thể bị template drift nếu theo dõi quá lâu. |
| Quality blend | 0.8/0.2 | 80% weight cho measurement mới, 20% cho history. EMA-like blending giúp điểm thích ứng dần với condition thay đổi. |
| Tracking quality | 0.4×coverage + 0.6×quality | Trọng số 60% cho per-point quality, 40% cho spatial coverage. Quality quan trọng hơn coverage — 10 điểm chất lượng cao tốt hơn 30 điểm noise. |

#### 3.7.3. File triển khai

- `lib/features/vision/domain/utils/feature_tracker.dart` — Class `FeatureTracker` với `TrackedPoint` data class

---

### 3.8. Double Exponential Smoothing (Holt's Method)

#### 3.8.1. Nền tảng lý thuyết

Double Exponential Smoothing (Hay Holt's Linear Trend Method) là phương pháp time series forecasting mở rộng từ Single Exponential Smoothing bằng cách thêm thành phần **trend** (xu hướng):

```
Level:   Lₜ = α × Yₜ + (1 - α) × (Lₜ₋₁ + Tₜ₋₁)
Trend:   Tₜ = β × (Lₜ - Lₜ₋₁) + (1 - β) × Tₜ₋₁
Forecast: Ŷₜ₊₁ = Lₜ + Tₜ
```

Trong ứng dụng, triển khai được đơn giản hóa thành:

```
velocity = velocity × (1 - αvel) + targetVelocity × αvel    (αvel = 0.15)
position = position + velocity × αpos                         (αpos = 0.15)
```

Method này được sử dụng làm **fallback** khi Kalman Filter có uncertainty quá cao (> 10 pixels). Lý do: Kalman Filter cần thời gian để hội tụ (initial P = 500), trong những frame đầu hoặc sau reset, sorted smoothing provides stability tốt hơn raw measurement.

#### 3.8.2. File triển khai

- `lib/features/vision/domain/utils/cv_core.dart` — Hàm `processFrame()` trong `CVCore`

---

### 3.9. Exponential Moving Average (EMA)

#### 3.9.1. Nền tảng lý thuyết

EMA (Exponential Moving Average) là phương pháp smoothing phổ biến nhất trong signal processing:

```
Sₜ = α × Xₜ + (1 - α) × Sₜ₋₁
```

Trong đó α (alpha) là smoothing factor (0 < α < 1). α cao → responsive hơn (ít smoothing). α thấp → mượt hơn (nhiều smoothing, lag cao).

Ứng dụng sử dụng EMA ở hai nơi:

**a) Map heading smoothing** (`navigation_map_widget.dart`):
```
smoothedHeading = smoothedHeading × (1 - 0.3) + newHeading × 0.3
```
Alpha = 0.3 là chọn compromise: đủ responsive để phản hồi chuyển direction nhanh, đủ smooth để không bị jitter từ GPS noise.

**b) Tracking quality blending** (`feature_tracker.dart`):
```
newQuality = max(existingQuality, 0.8 × newMeasurement + 0.2 × existingQuality)
```
Alpha = 0.8 cho measurement mới, ưu tiên measurement tươi nhưng vẫn giữ một phần history.

#### 3.9.2. File triển khai

- `lib/features/vision/presentation/widgets/navigation_map_widget.dart` — Hàm `_smoothAngle()`
- `lib/features/vision/domain/utils/feature_tracker.dart` — Quality blending

---

### 3.10. Haversine Formula & Geodesic Bearing

#### 3.10.1. Haversine Formula

Tính khoảng cách lớn nhất (great-circle distance) giữa hai điểm trên bề mặt Trái Đất:

```
a = sin²(Δφ/2) + cos(φ₁) × cos(φ₂) × sin²(Δλ/2)
c = 2 × atan2(√a, √(1-a))
d = R × c

Trong đó:
- φ₁, φ₂: vĩ độ (radians)
- λ₁, λ₂: kinh độ (radians)
- Δφ = φ₂ - φ₁, Δλ = λ₂ - λ₁
- R = 6,371,000 m (bán kính Trái Đất trung bình)
- d: khoảng cách (mét)
```

#### 3.10.2. Geodesic Bearing

Tính phương hướng ban đầu (initial bearing) từ điểm 1 đến điểm 2:

```
θ = atan2(sin(Δλ) × cos(φ₂),
          cos(φ₁) × sin(φ₂) - sin(φ₁) × cos(φ₂) × cos(Δλ))
```

Kết quả trong radians, convert sang degrees và normalize về [0°, 360°).

#### 3.10.3. Ứng dụng

Cả hai công thức được sử dụng trong `NavigationMapWidget` để:
- Tính khoảng cách từ vị trí hiện tại đến mỗi waypoint trên route
- Tính bearing giữa các waypoints liên tiếp để vẽ direction arrows trên route line
- So sánh distance giữa các route alternatives

#### 3.10.4. File triển khai

- `lib/features/vision/presentation/widgets/navigation_map_widget.dart` — Hàm `_calculateDistance()` và `_calculateBearing()`

---

### 3.11. Google Encoded Polyline Algorithm

#### 3.11.1. Nền tảng lý thuyết

Thuật toán Encoded Polyline do Google phát triển để nén chuỗi tọa độ địa lý thành chuỗi ASCII ngắn gọn, tiết kiệm băng thông khi truyền tải tuyến đường qua API. Kỹ thuật nén gồm 3 bước:

**Bước 1 — Delta Encoding**: Thay vì lưu tọa độ tuyệt đối, chỉ lưu difference (delta) giữa tọa độ liên tiếp. Ví dụ: [(50.12345, 14.23456), (50.12355, 14.23460)] → delta = [(50.12345, 14.23456), (+0.00010, +0.00004)]

**Bước 2 — Zigzag Encoding**: Biến số âm thành số dương theo công thức `(n << 1) ^ (n >> 31)`:
- 0 → 0
- -1 → 1
- 1 → 2
- -2 → 3
- 2 → 4
Điều này cho phép sử dụng unsigned encoding cho cả số âm.

**Bước 3 — Variable-length encoding**: Mỗi số được biểu diễn bằng các nhóm 5 bit, bắt đầu từ bit thấp nhất. Nếu còn bit tiếp theo, bit thứ 6 (0x20) được set. Mỗi 5-bit group được cộng thêm 63 (ASCII '?' = 63) để tạo ra ký tự ASCII printable.

**Quá trình giải mã** (triển khai trong app):

```dart
List<List<double>> _decodePolyline(String encoded) {
  int index = 0, lat = 0, lng = 0;
  List<List<double>> points = [];

  while (index < encoded.length) {
    // Đọc latitude delta
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    // Zigzag decode
    if ((result & 1) == 1) result = ~result;
    result >>= 1;
    lat += result;

    // Đọc longitude delta (tương tự)
    shift = 0; result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    if ((result & 1) == 1) result = ~result;
    result >>= 1;
    lng += result;

    // Convert về độ (chia cho 1E5)
    points.add([lng / 1E5, lat / 1E5]);  // GeoJSON order: [longitude, latitude]
  }
  return points;
}
```

#### 3.11.2. File triển khai

- `lib/features/map/data/models/navigation_route_model.dart` — Hàm `_decodePolyline()`

---

### 3.12. ROI Masking & Obstacle Exclusion

#### 3.12.1. Vùng quan tâm (Region of Interest)

Chỉ 60% phía dưới của khung hình (từ y = 0.4 × height trở xuống) được sử dụng làm Region of Interest. Lý do:

- 40% phía trên thường là bầu trời hoặc cảnh rất xa — texture ít, không có thông tin chuyển động hữu ích cho heading estimation.
- Vùng đường/phía trước xe nằm ở phần dưới khung hình — đây là vùng quan trọng nhất.
- Loại bỏ bầu trời giảm số pixel cần xử lý và số feature points cần track.

#### 3.12.2. Vùng cấm (Forbidden Zones)

Mỗi bounding box từ YOLOv8 detection được mở rộng 15% mỗi phía:

```dart
double expandRatio = 0.15;
double newLeft = left - width * expandRatio;
double newTop = top - height * expandRatio;
double newRight = right + width * expandRatio;
double newBottom = bottom + height * expandRatio;
```

Vùng mở rộng được giữ lại trong **20 khung hình** sau lần phát hiện cuối cùng (temporal persistence). Cơ chế này xử lý hai vấn đề:
1. Object detection chỉ chạy mỗi 10 frames — forbidden zone cần persist giữa các lần detection.
2. Object có thể bị che khuất tạm thời (occluded) ở một số frame — zone vẫn hoạt động.

Điểm optical flow nào nằm bên trong bất kỳ forbidden zone nào sẽ bị loại bỏ khỏi RANSAC input, đảm bảo chỉ những điểm thuộc background (cảnh tĩnh) mới được sử dụng để ước lượng chuyển động camera.

#### 3.12.3. File triển khai

- `lib/features/vision/domain/utils/cv_core.dart` — Hàm `processFrame()` với ROI và forbidden zone mask
- `lib/features/vision/data/datasources/cv_data_source_impl.dart` — Bản nâng cấp với adaptive masking

---

## CHƯƠNG IV: CÔNG NGHỆ VÀ THƯ VIỆN SỬ DỤNG

### 4.1. Framework & Kiến trúc

| Công nghệ | Phiên bản | Vai trò trong ứng dụng |
|-----------|-----------|----------------------|
| **Flutter** | Dart ^3.10.4 | Cross-platform UI framework. Được chọn vì: hot reload tăng tốc development, single codebase cho 5 nền tảng, custom painter cho HUD overlay phức tạp, và native performance qua Isolate cho CV processing. |
| **flutter_bloc** | ^8.1.3 | State management pattern chuẩn Clean Architecture. Mỗi feature có BLoC riêng với events/states rõ ràng, dễ test và debug qua BLoC Observer. |
| **provider** | ^6.1.1 | Legacy state management (ChangeNotifier). Đang migrate sang BLoC nhưng vẫn dùng cho `FlowController`, `TripController`, `NavigationController`, `VoiceController`, `ThemeProvider`. |
| **get_it** | ^7.6.4 | Dependency injection container. Register Hive boxes async singleton, resolve services trong init(). |
| **dartz** | ^0.10.1 | Functional programming: `Either<Failure, T>` cho error handling, tránh throw/catch, force caller xử lý cả hai trường hợp thành công và thất bại. |
| **equatable** | ^2.0.5 | Value equality cho BLoC states/events, cho phép So sánh nội dung thay vì reference, cần thiết cho BLoC change detection. |

### 4.2. Computer Vision & AI

| Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|--------|
| **opencv_dart** | ^1.0.0 | OpenCV bindings cho Dart. Cung cấp `calcOpticalFlowPyrLK()`, `goodFeaturesToTrack()`, `cvtColor()`, `resize()`, `VideoCapture`, `Mat`. Được chọn vì performance native C++ và API Dart idiomatic. |
| **flutter_vision** | ^1.1.4 | YOLOv8/TFLite inference engine. Chạy mô hình YOLOv8-nano trên device, trả về bounding boxes + class labels + confidence. Sử dụng cho obstacle detection. |
| **google_mlkit_object_detection** | ^0.13.0 | ML Kit object detection (Google). Có sẵn như thư viện dự phòng, hiện không dùng trong pipeline chính. |
| **camera** | ^0.10.5 | Truy cập camera thiết bị. Dùng trong chế độ live camera (chưa triển khai đầy đủ — hiện dùng video file). |
| **image_picker** | ^1.1.2 | Chọn ảnh/video từ gallery hoặc camera. Dùng trong Trip feature cho media attachment. |

### 4.3. Bản đồ & Điều hướng

| Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|--------|
| **mapbox_maps_flutter** | ^0.4.4 | Map rendering, style switching (day/night), camera animation, GeoJSON line rendering, circle annotations. Được chọn vì performance tốt, customize sâu, và hỗ trợ heading-up mode. |
| **flutter_polyline_points** | ^2.0.0 | Polyline decoding (backup cho custom implementation). |
| **flutter_earth_globe** | ^2.2.0 | 3D globe widget cho Satellite View — hiển thị quả cầu Trái Đất và vị trí vệ tinh. |
| **http** | ^1.1.0 | HTTP client cho Goong Maps API calls (autocomplete, directions, static map). |
| **flutter_dotenv** | ^6.0.0 | Load API keys từ `.env` file (Mapbox access token, Goong API key). Tránh hardcode secrets trong source code. |

### 4.4. Cảm biến & Vị trí

| Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|--------|
| **geolocator** | ^13.0.1 | GPS positioning: current location, heading, speed, accuracy. Stream-based API cho continuous position updates với distance filter 5m. |
| **sensors_plus** | ^5.0.1 | Device sensors: `userAccelerometerEventStream` cho lateral acceleration (IMU bump detection). |

### 4.5. Giọng nói & Media

| Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|--------|
| **speech_to_text** | ^7.0.0 | Vietnamese speech recognition (locale `vi_VN`). Max listen: 30s, pause detection: 3s. |
| **flutter_tts** | ^4.2.0 | Text-to-speech engine. Vietnamese primary (`vi-VN`), English fallback. Rate: 0.9, Volume: 1.0, Pitch: 1.0. |
| **video_player** | ^2.8.1 | Video playback cho trip video review và video source trong Vision feature. |

### 4.6. Lưu trữ & Tiện ích

| Công nghệ | Phiên bản | Vai trò |
|-----------|-----------|--------|
| **hive** | ^2.2.3 | NoSQL embedded database cho Trip và MediaFile storage. Được chọn vì: không cần native dependencies, Dart pure, performance cao cho read/write nhỏ. |
| **hive_flutter** | ^1.1.0 | Flutter extensions cho Hive init và adapter generation. |
| **shared_preferences** | ^2.2.2 | Key-value storage cho app settings (voice enabled, theme mode, onboarding completed). |
| **path_provider** | ^2.1.2 | Filesystem paths cho media storage (app documents directory). |
| **uuid** | ^4.2.1 | UUID v4 generation cho Trip, MediaFile, VoiceCommand IDs. |
| **intl** | ^0.19.0 | Date/time formatting và number formatting (khoảng cách, thời gian). |
| **permission_handler** | ^11.0.1 | Runtime permissions cho camera, location, microphone. |
| **package_info_plus** | ^8.0.0 | Read app version and build number. |
| **flutter_svg** | ^2.0.0 | Render SVG icons and illustrations. |

---

## CHƯƠNG V: BẢNG TỔNG HỢP HẰNG SỐ VÀ THAM SỐ

Bảng sau tổng hợp tất cả các hằng số và tham số quan trọng được sử dụng trong ứng dụng, kèm theo giá trị, ý nghĩa, và file nguồn:

| STT | Tham số | Giá trị | Ý nghĩa | File nguồn |
|----|---------|---------|----------|------------|
| 1 | Kalman P₀ (2D) | 500.0 | Covariance ban đầu — giá trị lớn → tin measurement hoàn toàn ở frame đầu | `kalman_filter.dart` |
| 2 | Kalman Q (position) | 0.1 | Process noise cho position — giá trị thấp → prediction mượt, ít noise | `kalman_filter.dart` |
| 3 | Kalman R (position) | 1.0 | Measurement noise cho position — moderate → K ≈ 0.33 sau hội tụ | `kalman_filter.dart` |
| 4 | Kalman Q (angle) | 0.05 | Process noise cho heading — thấp hơn position vì heading thay đổi chậm hơn | `kalman_filter.dart` |
| 5 | Kalman R (angle) | 2.5-3.0 | Measurement noise cho heading — cao vì GPS heading noise, đặc biệt ở tốc độ thấp | `kalman_filter.dart` |
| 6 | Kalman dt | 0.033s | Frame interval (1/30fps) — giả thiết cố định | `kalman_filter.dart` |
| 7 | Kalman uncertainty limit | 10.0 px | Ngưỡng uncertainty, vượt quá → fallback sang exponential smoothing | `kalman_filter.dart` |
| 8 | RANSAC iterations | 80 | Số vòng lặp RANSAC — đủ cho >99.9% xác suất tìm model đúng với 50% outlier | `motion_estimator.dart` |
| 9 | RANSAC threshold | 4.0 px | Inlier threshold — cho phép noise ±4 pixel | `motion_estimator.dart` |
| 10 | RANSAC minInliers | 8 | Số inlier tối thiểu — dưới 8 điểm, estimation không đáng tin cậy | `motion_estimator.dart` |
| 11 | LK winSize | 15×15 | Optical flow window size — balance giữa accuracy và speed | `cv_core.dart` |
| 12 | LK maxLevel | 2 | Pyramid levels — 3 mức cho displacement lớn | `cv_core.dart` |
| 13 | Shi-Tomasi quality | 0.03 | Feature detection quality level — threshold thấp để accept nhiều điểm hơn | `cv_core.dart` |
| 14 | Shi-Tomasi minDistance | 8.0 px | Minimum distance giữa feature points | `cv_core.dart` |
| 15 | Target features (base) | 60 | Số điểm feature tối ưu | `cv_core.dart` |
| 16 | Target features (adaptive) | 42-72 | Giảm khi confident, tăng khi uncertain | `cv_data_source_impl.dart` |
| 17 | Grid size | 4×3 | Feature bucketing grid — 12 ô cho ảnh 240px wide | `feature_tracker.dart` |
| 18 | Max points/cell | 5 | Giới hạn điểm/ô — tổng tối đa 60 điểm | `feature_tracker.dart` |
| 19 | Max lifetime | 90 frames | Điểm stale sau 3 giây, cần refresh | `feature_tracker.dart` |
| 20 | Proximity threshold | 15.0 px | Matching threshold giữa điểm cũ/mới | `feature_tracker.dart` |
| 21 | Minimum quality | 0.01 | Ngưỡng loại điểm kém chất lượng | `feature_tracker.dart` |
| 22 | Quality blend ratio | 0.8/0.2 | 80% measurement mới, 20% history | `feature_tracker.dart` |
| 23 | Tracking quality weight | 0.4/0.6 | 40% coverage, 60% quality | `feature_tracker.dart` |
| 24 | ROI region | Bottom 60% | Vùng quan tâm — bỏ bầu trời | `cv_core.dart` |
| 25 | Obstacle expansion | 15% | Mở rộng bounding box cho forbidden zone | `cv_core.dart` |
| 26 | Obstacle expiry | 20 frames | Thời gian persist của forbidden zone | `cv_core.dart` |
| 27 | Vision dx→degree | 0.3 | Hệ số chuyển pixel sang mức độ heading | `sensor_fusion.dart` |
| 28 | IMU bump threshold | 3.0 m/s² | Ngưỡng phát hiện va chạm/rung lắc | `sensor_fusion.dart` |
| 29 | IMU bump divisor | 10.0 | Hệ số attenuation cho bump | `sensor_fusion.dart` |
| 30 | Base alpha (GPS) | 0.90 | Base weight cho GPS trong complementary filter | `sensor_fusion.dart` |
| 31 | Alpha range | [0.1, 0.98] | Clamp range cho alpha | `sensor_fusion.dart` |
| 32 | Vision weight range | 0.2-0.8 | Adaptive vision weight dựa trên confidence | `sensor_fusion.dart` |
| 33 | Low confidence streak | 5 frames | Giảm alpha sau 5 frames liên tục confidence thấp | `sensor_fusion.dart` |
| 34 | High confidence streak | 10 frames | Tăng alpha sau 10 frames liên tục confidence cao | `sensor_fusion.dart` |
| 35 | GPS accuracy (poor) | > 20m | Threshold tăng vision weight | `sensor_fusion.dart` |
| 36 | GPS accuracy (fair) | > 15m | Threshold tăng vision weight nhẹ | `sensor_fusion.dart` |
| 37 | Dead reckoning blend | 30% Kalman / 70% vision | Tỷ lệ khi GPS mất tín hiệu | `sensor_fusion.dart` |
| 38 | Exponential α (position) | 0.15 | Double exponential smoothing position factor | `cv_core.dart` |
| 39 | Exponential α (velocity) | 0.15 | Double exponential smoothing velocity factor | `cv_core.dart` |
| 40 | EMA α (map heading) | 0.3 | Map heading smoothing factor | `navigation_map_widget.dart` |
| 41 | Video resize width | 240 px | Downscale cho CV processing performance | `flow_controller.dart` |
| 42 | Target FPS | 30 | Frame rate mục tiêu | `app_constants.dart` |
| 43 | AI detection interval | 10 frames | Tần suất YOLO inference (~3 lần/giây) | `app_constants.dart` |
| 44 | YOLO conf threshold | 0.2 | Confidence threshold thấp — chấp nhận false positive | `app_constants.dart` |
| 45 | YOLO IoU threshold | 0.4 | NMS IoU threshold | `app_constants.dart` |
| 46 | GPS accuracy threshold | 10 m | Ngưỡng xác định GPS tin cậy | `app_constants.dart` |
| 47 | Haversine R | 6,371,000 m | Bán kính Trái Đất trung bình | `navigation_map_widget.dart` |
| 48 | Search debounce | 500 ms | Độ trễ gọi API search | `map_home_bloc.dart` |
| 49 | Voice max listen | 30 s | Thời gian tối đa Speech Recognition | `voice_controller.dart` |
| 50 | Voice pause timeout | 3 s | Thời gian im lặng trước khi dừng | `voice_controller.dart` |
| 51 | Voice throttle (normal) | 2 s | Khoảng tối thiểu giữa 2 cảnh báo cùng loại | `voice_feedback_service.dart` |
| 52 | Voice throttle (urgent) | 1 s | Khoảng tối thiểu cho cảnh báo khẩn cấp | `voice_feedback_service.dart` |
| 53 | TTS speech rate | 0.9 | Tốc độ đọc (1.0 = bình thường) | `tts_service_impl.dart` |

---

## CHƯƠNG VI: LUỒNG DỮ LIỆU TỔNG THỂ

### 6.1. Sơ đồ tổng thể

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Camera /       │    │   GPS /          │    │   IMU Sensor      │
│   Video File     │    │   Geolocator     │    │   sensors_plus    │
│                  │    │                  │    │                    │
│ (cv.VideoCapture │    │ - Latitude       │    │ - Accelerometer X │
│  30fps, 240px)  │    │ - Longitude      │    │ - Accelerometer Y  │
│                  │    │ - Heading (°)    │    │ - Accelerometer Z  │
│                  │    │ - Speed (m/s)    │    │                    │
│                  │    │ - Accuracy (m)   │    │                    │
└────────┬─────────┘    └────────┬─────────┘    └─────────┬────────┘
         │                       │                        │
         ▼                       │                        │
┌────────────────────────────────┼────────────────────────┤
│                                │                        │
│  ┌─────────────────────────────▼────────────────────────▼───┐
│  │              Dart Isolate (_videoWorker)                   │
│  │                                                           │
│  │  1. cv.VideoCapture.read() → grayscale → resize(240px)  │
│  │  2. Build ROI mask (bottom 60%) + obstacle mask           │
│  │  3. goodFeaturesToTrack() → feature detection             │
│  │  4. calcOpticalFlowPyrLK() → sparse optical flow           │
│  │  5. Filter points (bounds + forbidden zones)               │
│  │  6. RANSAC motion estimation (80 iters, 4px threshold)     │
│  │  7. Kalman Filter 2D smoothing ([x,y,vx,vy])             │
│  │  8. JPEG encode frame for UI display                       │
│  │  9. Send IsolateResult to main thread                     │
│  └──────────────────────────┬───────────────────────────────┘
│                             │
└─────────────────────────────┤
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Main Thread (FlowController)                        │
│                                                                        │
│  1. Nhận IsolateResult:                                                │
│     - trackedPoints (List<Offset>)                                     │
│     - smoothedVector (MotionVector)                                    │
│     - forbiddenZones (List<Rect>)                                      │
│     - confidence, inlierCount, quality, trackCount                     │
│     - JPEG-encoded frame (Uint8List)                                   │
│                                                                        │
│  2. Mỗi 10 frames: YOLOv8 object detection                            │
│     - flutter_vision.yoloOnImage()                                     │
│     - Filter 6 class: car, motorcycle, bus, truck, person, bicycle     │
│     - Expand bounding boxes by 15%                                      │
│     - Send obstacle rects to isolate for forbidden zone masking         │
│     - Voice feedback: alertObstacle()                                  │
│                                                                        │
│  3. Mỗi frame: SensorFusion.update()                                   │
│     Input:  vision dx, GPS heading, IMU accel-Y                        │
│              tracked points count, GPS accuracy                         │
│              vision confidence, vision quality                          │
│     Output: fused heading (degrees 0-360)                               │
│     Steps:                                                              │
│     a. IMU bump suppression (|accelY| > 3.0)                            │
│     b. Vision heading delta = -dx × 0.3                                 │
│     c. Adaptive vision weight (0.2-0.8 based on confidence)             │
│     d. GPS quality adjustment                                           │
│     e. Confidence streak adaptation                                      │
│     f. Complementary filter (GPS available) / Dead reckoning (GPS lost) │
│     g. Kalman Filter Angle smoothing                                    │
│                                                                        │
│  4. Voice feedback: alertTurn() khi heading thay đổi đáng kể            │
│     - < 15°: bỏ qua                                                    │
│     - 15-45°: "Rẽ nhẹ bên trái/phải"                                  │
│     - > 45°: "Rẽ trái/phải"                                           │
│                                                                        │
│  5. Cập nhật UI notifiers (ChangeNotifier)                              │
│     - headingNotifier: fused heading                                    │
│     - progressNotifier: video playback progress                         │
│     - speedNotifier: GPS speed                                         │
│     - obstaclesNotifier: detected obstacles                             │
│     - trackedPointsNotifier: optical flow points for debug overlay      │
└───────────────────────────────┬────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
          ┌─────────┐    ┌──────────────┐  ┌────────────┐
          │  Flow   │    │  Navigation  │  │    Trip     │
          │  Page   │    │Vision Page   │  │  Manager    │
          │         │    │  (PiP mode)  │  │            │
          └─────────┘    └──────────────┘  └────────────┘
```

### 6.2. Mô tả luồng dữ liệu

**Luồng Camera/Vision** (xử lý trong Isolate, ~30fps):
1. Video frame đọc từ `cv.VideoCapture`
2. Resize xuống 240px width
3. Chuyển BGR → Grayscale
4. Xây dựng combined mask (ROI bottom 60% + obstacle exclusion)
5. Feature detection (Shi-Tomasi)
6. Optical flow tracking (Pyramidal LK)
7. Point filtering (bounds + forbidden zones)
8. RANSAC motion estimation → motion vector + confidence
9. Kalman Filter 2D smoothing
10. Encode JPEG → gửi về main thread

**Luồng AI Detection** (mỗi 10 frames, trên main thread):
1. Decode frame → `yoloOnImage()` (YOLOv8n TFLite)
2. Filter 6 class → expand bounding boxes 15%
3. Send obstacle rects → Isolate (cho forbidden zone mask ở frame tiếp theo)
4. Generate voice alerts (throttle 1-2 giây)

**Luồng Sensor Fusion** (mỗi frame, trên main thread):
1. Nhận vision dx từ IsolateResult
2. Nhận GPS heading, speed, accuracy từ Geolocator stream
3. Nhận IMU accel-Y từ sensors_plus stream
4. IMU bump suppression → safe vision dx
5. Adaptive weight calculation → complementary filter
6. Kalman Filter Angle smoothing → fused heading
7. Output: headingNotifier → UI

**Luồng Map/Navigation** (event-driven, trên main thread):
1. User nhập text → debounce 500ms → Goong Autocomplete API
2. User chọn place → Goong Place Detail API → route calculation
3. Goong Directions API → decode polyline → draw on Mapbox map
4. GPS position stream → update user location on map
5. Heading stream → rotate map (heading-up mode)

**Luồng Voice** (event-driven):
1. User nhấn nút mic → `speech_to_text` listen (max 30s, pause 3s)
2. Recognized text → keyword matching
3. Command dispatch → navigate to page (GNSS-Vision, Satellite, Home)
4. TTS response (optional)

---

## CHƯƠNG VII: MÀN HÌNH VÀ GIAO DIỆN NGƯỜI DÙNG

| STT | Màn hình | File nguồn | Mô tả chi tiết |
|-----|----------|------------|----------------|
| 1 | Splash | `core/pages/splash_screen.dart` | Animation intro 434 dòng: logo GNSS Vision với CustomPainter vẽ pin + vệ tinh orbital + kim cương la bàn + hiệu ứng phát sáng; particle background; concentric ring rotations; elastic logo entrance; linear progress indicator. Xử lý permissions (camera, location, microphone) song song, đợi GetIt init, navigate sang Onboarding hoặc MapHome. |
| 2 | Onboarding | `core/pages/onboarding_screen.dart` | 1461 dòng, 3 trang: "Định Vị Thông Minh" (GNSS + Vision + IMU), "Nhìn Thấu Mọi Trở Ngại" (camera + AI detection), "Theo Dõi Vệ Tinh" (3D globe + GNSS). Gradient blob intro, phone mockup với fake UI, page dot navigation, "takeover" transition với ripple/fill/flash effects. |
| 3 | Map Home | `map/presentation/pages/map_home_page.dart` | Màn hình chính. Mapbox Maps SDK hiển thị bản đồ, BlocProvider/ BlocConsumer cho state management. Đặc điểm: voice command integration, GeoJSON route line (5-layer styling: inner glow, outer glow, casing, line, highlight), circle annotations cho position + destination, camera fly-to animation, DraggableScrollableSheet cho place detail, haptic feedback. |
| 4 | GNSS-Vision | `vision/presentation/pages/flow_page.dart` | Video analysis HUD. Hiển thị: processed video frame với FlowPainter overlay (debug grid, tracking points, motion vector arrow, obstacle boxes với glow + corner brackets + warning icons), speedometer gauge, heading compass (DirectionArrowPainter), status indicators (GPS, AI model loaded), obstacle warning banner, video controls (play/pause, speed, debug mode, voice). |
| 5 | Navigation+Vision | `vision/presentation/pages/navigation_vision_page.dart` | Split view: Mapbox map toàn màn hình + PiP video overlay (expandable/collapsible). Route line + direction arrows, turn instruction card (TurnInstructionCard), speed/heading/obstacle indicators, heading-up map toggle. |
| 6 | Satellite | `vision/presentation/pages/satellite_page.dart` | 3D globe (FlutterEarthGlobe) + radar/skyplot view. Real GNSS data qua EventChannel, constellation filtering (GPS, GLONASS, GALILEO, BEIDOU, QZSS), mock data fallback, signal quality visualization. |
| 7 | Trip Manager | `trip/presentation/pages/trip_manager_page.dart` | Trip list với SliverAppBar, staggered animations. Mỗi card: title, date, distance, duration, media count, start/end location timeline, media thumbnail strip, active badge ("Đang đi"), FAB tạo trip mới. |
| 8 | Trip Detail | `trip/presentation/pages/trip_detail_page.dart` | Rich detail page: embedded Mapbox map với start/end markers + route, trip summary (distance, duration), location timeline, staggered media gallery grid, full-screen media viewer với video player support, camera/gallery picker. |
| 9 | Create Trip | `trip/presentation/pages/create_trip_page.dart` | Interactive map-based trip creation. Map tap chọn start/end points, Goong Places API search, place detail resolution, "Use current location" (long-press), route distance/duration preview, vehicle type selection. |

**Design System**: Material 3, dark-first, 6 gradient presets (primary #7C6AFF→#22D3EE, accent, danger, success, warm, surface), glassmorphism (blur backdrop + semi-transparent overlay), neumorphism (press/raised shadow), 10+ decoration factory methods, 13+ custom widgets (ModernButton, ModernCard, ModernTextField, ModernIconContainer, ModernBadge, ModernChip, ModernAvatar, ModernStatusCard, ModernProgressBar, ModernLoadingOverlay, ModernEmptyState, ModernSectionHeader, ModernDivider, ModernDialog, ModernBottomSheet), animation system (5 speed tiers, 5 curve presets, EntranceAnimation với 5 types).

---

## CHƯƠNG VIII: TỔNG KẾT

### 8.1. Bảng tóm tắt lý thuyết đã áp dụng

| STT | Lý thuyết/Thuật toán | Lĩnh vực | Ứng dụng cụ thể | File triển khai |
|-----|---------------------|----------|------------------|-----------------|
| 1 | Pyramidal Lucas-Kanade Optical Flow | Computer Vision | Theo dõi điểm đặc trưng qua các khung hình liền kề, ước lượng chuyển động pixel-level | `cv_core.dart`, `cv_data_source_impl.dart` |
| 2 | Shi-Tomasi Corner Detection | Computer Vision | Phát hiện điểm đặc trưng (corner) với eigenvalue threshold, đảm bảo trackability | `cv_core.dart` |
| 3 | RANSAC (Random Sample Consensus) | Robust Estimation | Ước lượng translation vector từ noisy correspondences, loại bỏ outlier từ vật thể di chuyển độc lập | `motion_estimator.dart` |
| 4 | Weighted Least Squares (M-estimator) | Estimation | Refinement sau RANSAC với trọng số 1/(1+error), giảm ảnh hưởng inlier xa | `motion_estimator.dart` |
| 5 | Kalman Filter 2D (4-state) | Optimal Estimation | Làm mịn motion vector [px, py, vx, vy], predict position khi lost tracking | `kalman_filter.dart` |
| 6 | Kalman Filter Angle (2-state) | Optimal Estimation | Làm mịn heading [θ, ω] với circular wraparound handling | `kalman_filter.dart` |
| 7 | Adaptive Weighted Complementary Filter | Multi-Sensor Fusion | Kết hợp vision incremental heading + GPS absolute heading với trọng số thích ứng | `sensor_fusion.dart` |
| 8 | Dead Reckoning | Navigation | Ước lượng heading khi GPS mất tín hiệu (30% Kalman prediction + 70% vision delta) | `sensor_fusion.dart` |
| 9 | IMU Bump Suppression | Signal Processing | Loại bỏ vision artifact từ va chạm/rung lắc, dựa trên accelerometer threshold | `sensor_fusion.dart` |
| 10 | Spatial Grid Feature Bucketing | Feature Management | Phân bố đều tracking points trên 4×3 grid, đảm bảo coverage | `feature_tracker.dart` |
| 11 | YOLOv8 Object Detection | Deep Learning | Phát hiện 6 loại vật cản thời gian thực trên mobile device | `flow_controller.dart` |
| 12 | Double Exponential Smoothing | Time Series | Fallback smoothing khi Kalman uncertainty quá cao | `cv_core.dart` |
| 13 | Exponential Moving Average | Time Series | Làm mịn heading trên bản đồ, blending tracking quality | `navigation_map_widget.dart`, `feature_tracker.dart` |
| 14 | Haversine Formula | Geodesy | Tính khoảng cách great-circle giữa 2 điểm GPS | `navigation_map_widget.dart` |
| 15 | Geodesic Bearing | Geodesy | Tính phương hướng (bearing) giữa 2 waypoints cho route arrows | `navigation_map_widget.dart` |
| 16 | Encoded Polyline Decoding | Compression | Giải mã tuyến đường từ Goong Directions API (delta + zigzag + 5-bit ASCII) | `navigation_route_model.dart` |
| 17 | ROI Masking + Forbidden Zones | Computer Vision | Loại bỏ bầu trời (top 40%) và vùng vật cản (expand 15%) khỏi optical flow tracking | `cv_core.dart`, `cv_data_source_impl.dart` |
| 18 | Debounced Search | UX/API | Giảm API calls khi user đang gõ, timer 500ms | `map_home_bloc.dart` |
| 19 | Keyword Spotting (Vietnamese) | NLP | Nhận diện lệnh giọng nói tiếng Việt bằng substring matching | `voice_controller.dart` |

### 8.2. Điểm mạnh của hệ thống

1. **Robust motion estimation**: Kết hợp RANSAC + Kalman Filter + Adaptive Complementary Filter tạo thành pipeline 3 lớp, mỗi lớp xử lý một loại noise khác nhau (outlier, measurement noise, GPS jitter).
2. **Graceful degradation**: Khi GPS mất tín hiệu, hệ thống tự động chuyển sang dead reckoning. Khi tracking quality thấp, adaptive weight shift vị trí sang GPS. Khi Kalman uncertainty cao, fallback sang exponential smoothing.
3. **Real-time object detection**: YOLOv8-nano chạy trên device, không cần server, latency thấp (~100ms inference).
4. **Vietnamese-first design**: TTS, voice commands, UI labels đều hỗ trợ tiếng Việt.
5. **Clean Architecture**: Tách biệt concerns, dễ test, dễ thay thế implementation.

### 8.3. Hạn chế và hướng phát triển

1. **Vision heading chỉ dựa trên translation model**: RANSAC sử dụng pure translation assumption — không handle rotation. Khi xe quay đầu hoặc vào cua gấp, model không chính xác.
2. **Pixel-to-degree scaling cố định**: Hệ số 0.3 là giá trị xấp xỉ, chỉ chính xác ở một khoảng cách nhất định. Cần calibrate theo focal length và mounting position.
3. **YOLOv8 chỉ chạy mỗi 10 frames**: có thể miss vật cản xuất hiện giữa các lần detection. Forbidden zone persistence (20 frames) giúp giảm nhưng không loại bỏ hoàn toàn.
4. **Voice command giới hạn**: Keyword matching đơn giản, không handle paraphrase hay context. Cần nâng cấp sang intent-based NLU.
5. **BLoC migration chưa hoàn thành**: FlowController, TripController, NavigationController vẫn dùng ChangeNotifier. Cần migrate dần để thống nhất architecture.
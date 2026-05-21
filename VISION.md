# Vision System Report

## 1. Gioi thieu

### 1.1. Muc tieu

Module `vision` trong du an co vai tro trich xuat thong tin chuyen dong tu video/camera de ho tro bai toan dan duong GNSS. Muc tieu chinh khong phai la tai tao pose 6-DoF day du theo huong SLAM, ma la:

- uoc luong xu huong chuyen huong trai/phai tu optical flow
- on dinh hoa heading khi GPS dao dong hoac cham cap nhat
- loai bo anh huong cua vat the dong bang semantic detection
- tao mot tang perception nhe, co the chay gan real-time tren Flutter

### 1.2. Pham vi tai lieu

Tai lieu nay tong hop toan bo phan vision lien quan den:

- optical flow
- tracking feature
- AI obstacle masking
- sensor fusion trong `lib/features/vision`
- cac module nang cao da cai dat nhung chua noi vao runtime chinh

Tat ca nhan xet duoi day duoc rut ra truc tiep tu code hien co trong repo, khong dua tren y tuong thiet ke chung chung.

### 1.3. Trang thai thuc te cua he thong

Module `vision` hien dang o trang thai chuyen tiep giua:

- pipeline legacy/runtime dang chay that
- pipeline Clean Architecture dang duoc scaffold

Vi vay, can phan biet ro hai lop sau:

#### Pipeline dang chay thuc te

- `FlowController`
- `CVCore`
- `SensorFusion`
- YOLO obstacle masking qua `flutter_vision`

#### Pipeline nang cao da duoc cai dat nhung chua noi vao runtime chinh

- `CVDataSourceImpl`
- `MotionEstimator`
- `KalmanFilter2D`
- `FeatureTracker`
- `VisionBloc`, `VisionRepositoryImpl`

Day la diem rat quan trong khi viet bao cao, vi neu khong tach bach hai tang nay se de mo ta sai rang cac ky thuat RANSAC/Kalman 2D da duoc dua vao luong runtime chinh, trong khi thuc te chua phai.

## 2. Bai toan ky thuat

### 2.1. Dau vao

He thong nhan cac nguon du lieu sau:

- video frame tu file video qua OpenCV
- ket qua object detection tu YOLOv8
- GPS heading
- GPS speed
- GPS accuracy
- IMU user acceleration theo truc `Y`

### 2.2. Dau ra

He thong tao ra:

- tap feature points dang duoc track
- motion vector tu vision
- forbidden zones tao tu AI obstacles
- heading hop nhat sau sensor fusion
- frame da nen de render len UI

### 2.3. Rang buoc he thong

Do module duoc viet trong Flutter va huong den ung dung di dong, bai toan co cac rang buoc:

- tai tinh toan CV phai nhe
- AI khong the chay moi frame
- qua trinh render UI phai duoc tach khoi xu ly CV
- can chiu duoc nhieu giao thong, rung camera, GPS khong on dinh

## 3. Kien truc tong the

### 3.1. Kien truc xu ly isolate

Luot xu ly hien tai duoc tach thanh hai thanh phan:

#### UI isolate

Duoc quan ly boi `FlowController`, dam nhiem:

- load YOLO model
- quan ly playback
- nhan frame da xu ly tu worker isolate
- chay AI dinh ky
- thuc hien sensor fusion
- cap nhat notifier cho UI

#### Worker isolate

Trong `FlowController._videoWorker`, isolate rieng dam nhiem:

- mo video qua `cv.VideoCapture`
- doc frame
- resize frame
- goi `CVCore.processFrame`
- nen frame thanh JPEG
- gui ket qua ve main isolate

Kien truc nay hop ly ve mat ky thuat, vi optical flow va video decode la tac vu nang CPU, khong nen nam tren UI thread.

### 3.2. Luong du lieu tong quat

\[
\text{Video Frame} \rightarrow \text{Resize} \rightarrow \text{Gray} \rightarrow \text{Feature Detection/Tracking} \rightarrow \text{Motion Vector}
\]

\[
\text{Motion Vector} + \text{GPS} + \text{IMU} \rightarrow \text{Sensor Fusion} \rightarrow \text{Fused Heading}
\]

\[
\text{Video Frame} \rightarrow \text{YOLO} \rightarrow \text{Forbidden Zones} \rightarrow \text{Mask for Optical Flow}
\]

Y nghia la he thong co hai nhanh perception song song:

- nhanh hinh hoc: optical flow
- nhanh semantic: object detection

Sau do nhanh semantic duoc dung de ho tro nhanh hinh hoc bang cach loai bo cac moving object.

## 4. Cong nghe va thu vien duoc su dung

Theo `pubspec.yaml`, vision stack hien co dung:

- `opencv_dart: ^1.0.0`
- `flutter_vision: ^1.1.4`
- `geolocator: ^13.0.1`
- `sensors_plus: ^5.0.1`
- `image_picker: ^1.1.2`
- `provider: ^6.1.1`
- `flutter_bloc: ^8.1.3`
- `get_it: ^7.6.4`
- `dartz: ^0.10.1`
- `equatable: ^2.0.5`

Trong do:

- `opencv_dart` la nen tang cho optical flow va video processing
- `flutter_vision` dung cho YOLOv8 TFLite
- `geolocator` va `sensors_plus` cung cap du lieu fusion
- `provider` hien la state management runtime cua vision page
- `flutter_bloc/get_it` da co de phuc vu migration sang Clean Architecture

## 5. Optical Flow Pipeline dang chay thuc te

Phan nay mo ta pipeline dang duoc goi thuc su trong:

- `lib/features/vision/presentation/controllers/flow_controller.dart`
- `lib/features/vision/domain/utils/cv_core.dart`
- `lib/features/vision/domain/utils/sensor_fusion.dart`

### 5.1. Tien xu ly khung hinh

Trong `FlowController._runLoop`, moi frame duoc resize ve chieu rong co dinh `240 px`:

\[
\text{scale} = \frac{240}{W}
\]

\[
H' = H \cdot \text{scale}
\]

Muc dich:

- giam chi phi tinh toan optical flow
- giam bo nho frame
- giu latency thap cho isolate

### Tham so dang dung

- target width: `240`
- target playback fps: `30`
- JPEG quality: `50`

### 5.2. Chuyen anh sang grayscale

Trong `CVCore.processFrame`, frame duoc chuyen sang anh xam:

\[
I_t = \text{cvtColor}(F_t, \text{BGR2GRAY})
\]

Dieu nay phu hop voi optical flow co ban vi:

- khong can khai thac mau
- giam 3 kenh ve 1 kenh
- sat voi gia thiet brightness constancy

### 5.3. Feature detection bang Shi-Tomasi

Khi can tai khoi tao tracking points, he thong dung:

- `cv.goodFeaturesToTrack`

voi tham so:

- `maxCorners = 60`
- `qualityLevel = 0.03`
- `minDistance = 8.0`

Ve mat ly thuyet, Shi-Tomasi chon cac corner co tri rieng nho nhat cua ma tran gradient cuc bo du lon:

\[
R = \min(\lambda_1, \lambda_2)
\]

Voi:

- `\lambda_1, \lambda_2` la hai tri rieng cua structure tensor

Shi-Tomasi duoc chon vi:

- nhe
- phu hop tracking sparse
- cho corner on dinh hon so voi diem bien don le

### 5.4. ROI cho feature selection

He thong khong tim feature tren toan frame, ma chi mo mask o phan duoi:

\[
\text{roiY} = 0.4H
\]

Nghia la chi lay vung:

\[
y \in [0.4H, H]
\]

Tuong ung voi `60%` phan duoi cua anh.

Co so ky thuat cua lua chon nay:

- mat duong va vat the gan xe thuong nam o nua duoi frame
- troi, tan cay, toa nha xa gay nhieu cho heading ground vehicle
- optical flow tren mat duong co y nghia hon doi voi bai toan dieu huong

### 5.5. Theo doi feature bang Pyramidal Lucas-Kanade

Tracking duoc thuc hien boi:

- `cv.calcOpticalFlowPyrLK`

voi:

- `winSize = (15, 15)`
- `maxLevel = 2`

#### Co so toan hoc

Lucas-Kanade dua tren gia thiet do sang khong doi theo thoi gian:

\[
I(x, y, t) \approx I(x+u, y+v, t+\Delta t)
\]

Khai trien Taylor bac nhat:

\[
I_x u + I_y v + I_t = 0
\]

Do mot diem cho 1 phuong trinh va 2 an, can mot cua so cuc bo de giai bang least squares:

\[
\begin{bmatrix}
\sum I_x^2 & \sum I_x I_y \\
\sum I_x I_y & \sum I_y^2
\end{bmatrix}
\begin{bmatrix}
u \\ v
\end{bmatrix}
=
-
\begin{bmatrix}
\sum I_x I_t \\
\sum I_y I_t
\end{bmatrix}
\]

Phien ban pyramid giup xu ly chuyen dong lon hon bang cach giai o nhieu muc scale.

### 5.6. Loc diem hop le sau tracking

Sau khi optical flow tra ve:

- `p1`
- `status`
- `err`

He thong chi giu cac diem:

- `status[i] == 1`
- nam trong bien frame
- khong nam trong forbidden zone

Ket qua la:

- `trackedPoints`: phuc vu hien thi
- `goodNewPoints`: lam dau vao tracking frame sau
- cap diem cu/moi de tinh motion

## 6. AI Obstacle Masking

### 6.1. Muc dich

Optical flow tu ban chat khong phan biet:

- camera dang quay
- nguoi dung dang re
- hay mot vat the phia truoc dang chuyen dong

Do do, neu mot xe may hoac oto cat ngang frame, motion vector trung binh co the bi lech manh. Giai phap hien tai la dung object detection de tao vung cam, loai bo nhung diem track tren vat the dong.

### 6.2. YOLO model va cau hinh

Trong `FlowController._loadYoloModel`, model duoc nap voi:

- `modelPath = assets/yolov8n.tflite`
- `labels = assets/labels.txt`
- `modelVersion = "yolov8"`
- `numThreads = 4`
- `useGpu = true`

Lua chon `yolov8n` cho thay uu tien toc do va tai nhe hon do chinh xac cuc dai.

### 6.3. Tan suat suy dien AI

AI khong chay moi frame. Trong `_handleFrameResult`, he thong goi YOLO moi `10` frame:

\[
f_{AI} \approx \frac{30}{10} = 3 \text{ Hz}
\]

Neu playback dang o muc tieu `30 FPS`.

Day la mot lua chon thuc dung:

- giam tai suy dien
- du de cap nhat vat can cho muc dich masking
- tranh keo do tre toan pipeline

### 6.4. Cac nhan duoc quan tam

Chi cac object co nhan sau moi duoc dua vao forbidden zones:

- `car`
- `motorcycle`
- `bus`
- `truck`
- `person`
- `bicycle`

Day la cac lop vat the de gay nhieu nhat cho optical flow trong boi canh duong pho.

### 6.5. Nguong detector

Trong `vision.yoloOnImage`:

- `iouThreshold = 0.4`
- `confThreshold = 0.2`

`confThreshold` tuong doi thap, cho phep detector nhay hon de uu tien khong bo sot vat can. Doi lai, nguy co false positive co the tang, nhung da duoc han che phan nao boi cac luat mask tiep theo.

### 6.6. Tao forbidden zones

Moi bounding box AI duoc mo rong them `15%` moi chieu:

\[
x_{left}' = x_{left} - 0.15w
\]
\[
x_{right}' = x_{right} + 0.15w
\]
\[
y_{top}' = y_{top} - 0.15h
\]
\[
y_{bottom}' = y_{bottom} + 0.15h
\]

Sau do clamp vao bien frame.

Muc dich cua expansion:

- tranh tinh trang corner nam sat mep bounding box van lot vao optical flow
- dem du vi sai detector/frame-to-frame jitter

### 6.7. Dieu kien loai bo box qua lon

Neu box qua lon thi bi bo qua:

- `box.width > 0.7 * frameW`
- hoac `box.height > 0.7 * frameH`

Quy tac nay co the hieu nhu mot bo loc de tranh:

- detection sai tran frame
- vat the qua gan camera che phan lon anh
- mask lam mat qua nhieu feature

### 6.8. Co che nho vat can

Neu AI khong tra ve obstacle moi:

- `_framesSinceLastYolo++`

Neu qua `20` frame khong cap nhat:

- `_lastKnownObstacles.clear()`

Co che nay giu tri nho ngan cho vat can giua hai lan detector, giup forbidden zones khong nhap nhay qua manh.

## 7. Uoc luong motion trong `CVCore`

### 7.1. Cach tinh motion vector

Trong luong runtime chinh hien tai, motion vector duoc tinh don gian bang trung binh cong cac vector dich chuyen cua cac diem hop le:

\[
\Delta x_i = x_i^{new} - x_i^{old}
\]
\[
\Delta y_i = y_i^{new} - y_i^{old}
\]

\[
\bar{\Delta x} = \frac{1}{N}\sum_{i=1}^{N}\Delta x_i
\]
\[
\bar{\Delta y} = \frac{1}{N}\sum_{i=1}^{N}\Delta y_i
\]

\[
\mathbf{m}_{raw} = (\bar{\Delta x}, \bar{\Delta y})
\]

Dieu kien toi thieu:

- phai co it nhat `8` diem hop le

Neu duoi nguong nay, vector duoc xem nhu khong du manh de suy dien.

### 7.2. Confidence va quality dang dung

`CVCore` tinh:

\[
\text{confidence} = \frac{N}{60}
\]

trong do:

- `N` la so diem duoc giu lai sau tracking va masking
- `60` la so target points

Dong thoi:

- `inlierCount = N`
- `quality = confidence`

Can nhan manh:

- day la heuristic confidence
- khong phai confidence theo nghia robust estimator
- khong dua tren residual hoac inlier model thuc su

No chu yeu phan anh mat do tracking, khong phan anh muc do dong thuan hinh hoc cua cac vector.

### 7.3. Smoothing motion vector

Sau khi co `rawMoveVector`, he thong ap dung mot bo loc velocity-position hai tang.

#### Buoc 1: tinh target velocity

\[
\mathbf{v}_{target} = \mathbf{m}_{raw} - \mathbf{m}_{smooth}
\]

#### Buoc 2: low-pass cho velocity

\[
\mathbf{vel}_t = (1-\alpha_v)\mathbf{vel}_{t-1} + \alpha_v \mathbf{v}_{target}
\]

voi:

- `\alpha_v = 0.15`

#### Buoc 3: cap nhat motion smoothed

\[
\mathbf{m}_{smooth,t} = \mathbf{m}_{smooth,t-1} + \alpha_p \mathbf{vel}_t
\]

voi:

- `\alpha_p = 0.15`

Bo loc nay co tac dung:

- giam jitter
- han che thay doi dot ngot frame-to-frame
- tao vector mem hon cho sensor fusion

Tuy nhien, day van la smoothing heuristic, khong mo hinh hoa ro noise/process uncertainty.

## 8. Sensor Fusion dang chay thuc te

`SensorFusion` la lop hop nhat output vision voi GPS va IMU de tao `fusedHeading`.

### 8.1. Dau vao fusion

Ham `update` nhan:

- `visionDx`
- `gpsHeading`
- `imuAccelY`
- `hasValidGps`
- `trackedPointsCount`
- `gpsAccuracy`
- `visionConfidence`
- `visionQuality`

### 8.2. Chuyen motion pixel thanh heading delta

Trong code:

\[
\text{safeVisionDx} = -\text{visionDx}
\]

Phep dao dau nay phan anh quy uoc:

- pixel apparent motion sang trai co the ung voi xe dang quay sang phai

Sau do:

\[
\Delta \theta_{vision} = 0.3 \cdot \text{safeVisionDx}
\]

He so `0.3` hien la gain thuc nghiem. No chua duoc noi voi:

- FOV camera
- focal length
- van toc xe
- hinh hoc perspective

Vi vay, heading delta hien tai co tinh ky thuat-thuc nghiem hon la duoc hieu chinh vat ly chinh xac.

### 8.3. Bump compensation bang IMU

Neu:

\[
|a_y| > 3.0
\]

thi vision bi giam trong so thong qua:

\[
\text{bumpFactor} = \frac{|a_y| - 3.0}{10.0}
\]

\[
\text{safeVisionDx} \leftarrow \text{safeVisionDx}\cdot\max(0, 1-\text{bumpFactor})
\]

Y nghia:

- rung camera lon lam optical flow de bi sai
- IMU duoc dung nhu mot tin hieu phat hien frame xau
- motion tu vision bi attenuate thay vi bi bo cat cung

### 8.4. Dieu chinh trong so theo confidence

He thong khoi tao:

- `baseAlpha = 0.90`

Sau do `visionWeight` duoc suy ra:

- neu `visionConfidence > 0.7` va `visionQuality > 0.5` -> `0.8`
- neu `visionConfidence > 0.5` -> `0.6`
- neu `visionConfidence > 0.3` -> `0.4`
- con lai -> `0.2`

Neu so diem tracking thap:

- `< 15` -> `visionWeight *= 0.3`, `baseAlpha -= 0.3`
- `< 30` -> `visionWeight *= 0.6`, `baseAlpha -= 0.15`

Neu GPS accuracy xau:

- `gpsAccuracy > 20.0` -> `baseAlpha += visionWeight * 0.15`
- `gpsAccuracy > 15.0` -> `baseAlpha += visionWeight * 0.08`

Ngoai ra he thong theo doi streak:

- low-confidence streak khi `visionConfidence < 0.2`
- high-confidence streak khi `visionConfidence > 0.6`

Va hieu chinh:

- low streak > `5` -> `baseAlpha = max(0.5, baseAlpha - 0.1)`
- high streak > `10` -> `baseAlpha = min(0.95, baseAlpha + 0.05)`

Cuoi cung:

\[
\alpha = \text{clamp}(baseAlpha, 0.1, 0.98)
\]

Ve ban chat, `alpha` la tham so complementary fusion dong, quyet dinh muc do uu tien heading du bao tu vision so voi GPS.

### 8.5. Truong hop khong co GPS hop le

Neu `hasValidGps == false`, he thong dua vao:

- Kalman heading predictor
- vision heading delta

Predict:

\[
\Delta \theta_{pred} = \omega_{kalman}\cdot 0.033
\]

Scale vision theo confidence:

\[
\Delta \theta_{visionScaled} =
\Delta \theta_{vision}
\begin{cases}
1.0, & c_v > 0.5 \\
2c_v, & c_v \le 0.5
\end{cases}
\]

Tron:

\[
\Delta \theta_{final} = 0.3\Delta \theta_{pred} + 0.7\Delta \theta_{visionScaled}
\]

Cap nhat heading:

\[
\theta_t = \theta_{t-1} + \Delta \theta_{final}
\]

Sau do heading nay lai duoc dung de update Kalman.

Y tuong cua nhanh nay la:

- khi mat GPS, vision tro thanh nguon thong tin chinh
- nhung van giu du bao quan tinh tren heading qua Kalman de tranh giat

### 8.6. Truong hop co GPS hop le

Neu co GPS, he thong dua vision vao nhu mot buoc du bao:

\[
\theta_{pred} = \theta_{prev} + \Delta \theta_{vision}
\]

Sai lech voi GPS:

\[
\text{diff} = \theta_{gps} - \theta_{pred}
\]

`diff` duoc wrap ve khoang `(-180, 180]`.

Trong so GPS:

\[
w_{gps} = 1 - \alpha
\]

Neu `visionConfidence > 0.7`:

- `w_{gps} *= 0.6`

Cap nhat:

\[
\theta_{fused} = \theta_{pred} + w_{gps}\cdot(\theta_{gps} - \theta_{pred})
\]

He thong nay ve thuc chat gan voi mot adaptive complementary filter:

- GPS dong vai tro reference cham nhung tuyet doi hon
- vision dong vai tro local short-term heading correction

### 8.7. KalmanFilterAngle

`SensorFusion` su dung `KalmanFilterAngle` voi:

- `processNoise = 0.05`
- `measurementNoise = 2.5`

State gom:

- `angle`
- `angularVelocity`

#### Predict

\[
\theta_t^- = \theta_{t-1} + \omega_{t-1}\Delta t
\]

\[
P_{\theta} \leftarrow P_{\theta} + q\Delta t^2
\]

\[
P_{\omega} \leftarrow P_{\omega} + q\Delta t
\]

#### Update

\[
K = \frac{P_{\theta}}{P_{\theta} + R}
\]

\[
e = \theta_{meas} - \theta_t^-
\]

voi `e` duoc wrap ve `[-180, 180]`.

\[
\theta_t = \theta_t^- + Ke
\]

\[
\omega_t = \omega_{t-1} + \frac{Ke}{0.033}
\]

Day la mot Kalman 1D rut gon de:

- lam muot goc
- uoc luong van toc goc an
- cung cap kha nang predict khi GPS mat tam thoi

## 9. Pipeline nang cao da duoc cai dat trong `CVDataSourceImpl`

Nhanh code nay hien chua nam trong execution path chinh, nhung ve mat ky thuat no the hien phien ban nghien cuu-truong thanh hon cua motion estimation.

### 9.1. Khac biet tong quan so voi `CVCore`

So voi `CVCore`, `CVDataSourceImpl` them:

- `MotionEstimator` dua tren RANSAC
- `KalmanFilter2D` cho motion vector
- adaptive point count
- fallback giua Kalman va smoothing heuristic

No cho thay huong phat trien tu heuristic tracking sang robust estimation.

### 9.2. MotionEstimator bang RANSAC

`MotionEstimator` cau hinh:

- `ransacIterations = 80`
- `ransacThreshold = 4.0`
- `minInliers = 8`
- random seed = `42`

#### Nguyen ly

Moi vong, he thong chon mot motion sample:

\[
\mathbf{m}_{sample} = (x^{old} - x^{new}, y^{old} - y^{new})
\]

Voi moi diem:

\[
e_i = \sqrt{[(x_i^{old}-x_i^{new})-m_x]^2 + [(y_i^{old}-y_i^{new})-m_y]^2}
\]

Neu:

\[
e_i < 4.0
\]

thi diem do la inlier.

Mo hinh tot nhat la mo hinh co:

- so inlier lon nhat
- neu hoa nhau thi tong error nho nhat

#### Refinement bang weighted average

Sau khi tim duoc tap inlier tot nhat:

\[
w_i = \frac{1}{1+e_i}
\]

\[
\mathbf{m} = \frac{\sum_i w_i \Delta \mathbf{p}_i}{\sum_i w_i}
\]

voi:

\[
\Delta \mathbf{p}_i = (x_i^{old}-x_i^{new}, y_i^{old}-y_i^{new})
\]

#### Confidence va quality

\[
\text{inlierRatio} = \frac{\#inliers}{N}
\]

\[
\text{motionMagnitude} = \|\mathbf{m}\|
\]

\[
\text{confidence} = \text{inlierRatio}\cdot\min\left(\frac{\text{motionMagnitude}}{3.0}, 1.0\right)
\]

\[
\text{quality} =
\text{inlierRatio}
\begin{cases}
1.0, & \#inliers \ge 8 \\
\#inliers/8, & \#inliers < 8
\end{cases}
\]

So voi `CVCore`, confidence o day co nghia hinh hoc hon vi da phan anh muc do dong thuan cua chuyen dong.

### 9.3. KalmanFilter2D cho motion vector

`CVDataSourceImpl` tao:

- `KalmanFilter2D(processNoise: 0.08, measurementNoise: 1.5)`

State:

\[
\mathbf{x} = [x, y, v_x, v_y]^T
\]

#### Predict

\[
x_t^- = x_{t-1} + v_{x,t-1}\Delta t
\]
\[
y_t^- = y_{t-1} + v_{y,t-1}\Delta t
\]

Covariance duoc cap nhat rut gon tren duong cheo:

- `P_x += qdt^2`
- `P_y += qdt^2`
- `P_{vx} += qdt`
- `P_{vy} += qdt`

#### Update

\[
K_x = \frac{P_x}{P_x + R}
\]
\[
K_y = \frac{P_y}{P_y + R}
\]

\[
x_t = x_t^- + K_x(z_x - x_t^-)
\]
\[
y_t = y_t^- + K_y(z_y - y_t^-)
\]

\[
v_{x,t} = v_{x,t-1} + \frac{K_x(z_x - x_t^-)}{0.033}
\]
\[
v_{y,t} = v_{y,t-1} + \frac{K_y(z_y - y_t^-)}{0.033}
\]

Do bat dinh:

\[
\text{uncertainty} = \sqrt{P_x + P_y}
\]

Kalman nay cho phep:

- lam muot vector motion
- du bao motion frame tiep theo
- luong hoa muc do khong chac chan

### 9.4. Dieu kien dung Kalman hay fallback

Trong `CVDataSourceImpl`, Kalman chi duoc tin dung neu:

- `result.inliers >= 8`
- `result.confidence > 0.3`

Sau update, neu:

- `uncertainty < 10.0`
- `rawMoveVector.distance < 50.0`

thi ket qua Kalman duoc chap nhan.

Neu khong, he thong quay lai bo loc legacy.

Logic nay rat hop ly theo goc nhin he thong:

- khi du lieu dep thi dung estimator manh hon
- khi du lieu xau thi fallback ve heuristic on dinh

### 9.5. Adaptive point count

Khac voi `CVCore` co `60` diem co dinh, `CVDataSourceImpl` tu dieu chinh:

- confidence `> 0.7` -> `42` diem
- confidence `> 0.5` -> `51` diem
- confidence `> 0.3` -> `60` diem
- con lai -> `72` diem

Y tuong:

- tracking tot -> giam diem de tiet kiem tinh toan
- tracking xau -> tang co hoi tim lai feature

### 9.6. Confidence sau Kalman

Neu Kalman hop le:

\[
\text{confidence}_{final} = \text{confidence}_{ransac}\left(1-\frac{\text{uncertainty}}{10}\right)
\]

Neu fallback:

- confidence bi giam con `0.5` lan hoac `0.3` lan so voi `result.confidence`

Day la mot co che phat hop ly cho nhung frame ma uncertainty qua cao.

## 10. FeatureTracker da duoc cai dat

`FeatureTracker` hien chua noi vao runtime chinh, nhung no la mot module quan trong de quan ly spatial distribution cua feature points.

### 10.1. Cau hinh

- grid X = `4`
- grid Y = `3`
- tong so o = `12`
- `maxPointsPerCell = 5`
- `minPointsPerCell = 1`
- `maxLifetime = 90`
- `minQuality = 0.01`
- threshold ghep diem cu/moi = `15 px`

### 10.2. Y tuong thiet ke

Neu feature points tap trung qua nhieu vao mot vung, motion vector trung binh se:

- mat can bang khong gian
- de bi mot vat dong chi phoi
- giam kha nang dai dien cho chuyen dong toan cuc

Chia luoi va quan ly mat do theo tung o giup:

- phan bo diem deu hon
- tang spatial coverage
- theo doi diem ben vung hon qua nhieu frame

### 10.3. Tracking quality

`FeatureTracker` tinh:

\[
\text{coverageScore} = \frac{\text{activeCells}}{\text{totalCells}}
\]

\[
\text{qualityScore} = \text{mean(point quality)}
\]

\[
\text{trackingQuality} = 0.4\cdot \text{coverageScore} + 0.6\cdot \text{qualityScore}
\]

Neu duoc noi vao runtime, metric nay se hop ly hon so voi `trackedCount / 60`.

## 11. Quan he voi Clean Architecture

### 11.1. Cac thanh phan da duoc scaffold

Trong `lib/features/vision`, du an da co:

- `domain/entities`
- `domain/repositories`
- `domain/usecases`
- `data/datasources`
- `data/repositories`
- `presentation/bloc`

### 11.2. Trang thai thuc te

Du da co scaffold, cac thanh phan sau van chua hoat dong day du:

- `VisionRepositoryImpl` phan lon la `Not implemented`
- `VisionBloc` moi xu ly event/state o muc scaffold
- runtime page hien van dung `FlowController` + `Provider`

Do do, trong bao cao ky thuat can viet trung thuc:

- clean architecture da duoc dat khung
- nhung execution path cua vision hien chua duoc migrate hoan tat

## 12. Tong hop tham so ky thuat tu code

| Hang muc | Gia tri |
|---|---|
| Resize width | `240 px` |
| Playback target | `30 FPS` |
| JPEG quality | `50` |
| Feature detector | Shi-Tomasi |
| `maxCorners` | `60` |
| `qualityLevel` | `0.03` |
| `minDistance` | `8.0` |
| ROI bat dau tu | `0.4H` |
| LK `winSize` | `(15, 15)` |
| LK `maxLevel` | `2` |
| Nguong so diem toi thieu | `8` |
| Legacy `posAlpha` | `0.15` |
| Legacy `velAlpha` | `0.15` |
| YOLO model | `yolov8n.tflite` |
| YOLO threads | `4` |
| YOLO GPU | `true` |
| YOLO `iouThreshold` | `0.4` |
| YOLO `confThreshold` | `0.2` |
| Chu ky AI | `10` frame |
| Tan suat AI xap xi | `3 Hz` |
| Forbidden zone expansion | `15%` |
| Bo qua box qua lon | `> 70%` frame width/height |
| Xoa obstacle cache sau | `20` frame |
| Nguong bump IMU | `|accelY| > 3.0` |
| Vision-to-heading gain | `0.3` |
| Angle Kalman process noise | `0.05` |
| Angle Kalman measurement noise | `2.5` |
| Motion Kalman process noise | `0.08` |
| Motion Kalman measurement noise | `1.5` |
| RANSAC iterations | `80` |
| RANSAC threshold | `4.0` |
| RANSAC min inliers | `8` |
| Feature grid | `4 x 3` |
| Max points/cell | `5` |
| Min points/cell | `1` |
| Max lifetime | `90` |
| Min point quality | `0.01` |
| Match threshold | `15 px` |

## 13. Danh gia ky thuat

### 13.1. Diem manh

- Kien truc isolate la lua chon dung cho Flutter CV pipeline
- Optical flow sparse va Shi-Tomasi rat nhe, de chay thuc te
- ROI phan duoi frame phu hop voi bai toan phuong tien mat dat
- Semantic masking la mot bo tro rat manh cho optical flow
- Sensor fusion da tinh den GPS accuracy, IMU bump, tracking confidence
- Codebase da co huong nang cap ro rang sang RANSAC + Kalman 2D

### 13.2. Gioi han

- Motion estimator trong luong runtime chinh van la trung binh cong, de bi outlier
- Confidence cua `CVCore` con don gian
- He so quy doi pixel sang heading hien chua duoc calibration
- Chua co mo hinh camera/noi suy perspective
- Chua co danh gia dinh luong nhu ATE/RPE/heading RMSE trong repo
- Nhieu module nang cao chua duoc noi vao runtime

### 13.3. Rui ro ky thuat

He thong co the bi giam chat luong trong cac tinh huong:

- camera rung manh
- mat duong it texture
- ban dem, anh mo, motion blur
- traffic dong dac che khu vuc ROI
- GPS heading sai va vision cung dang yef

### 13.4. Muc do hoc thuat

Ve mat nghien cuu, he thong hien tai phu hop de mo ta nhu:

- `vision-assisted heading estimation`
- `sparse optical-flow-based directional cue extraction`
- `semantic-masked motion estimation with adaptive GPS/IMU fusion`

Khong nen mo ta qua muc thanh:

- visual SLAM
- monocular odometry day du
- 6-DoF ego-motion estimation

Neu viet trong DATN/bao cao nghien cuu, cach dat van de tren se trung thuc va chat che hon.

## 14. Huong cai tien de xuat

Neu tiep tuc phat trien, cac huong hop ly nhat la:

### 14.1. Dua `CVDataSourceImpl` vao runtime chinh

Day la buoc nang cap lon nhat vi no da co:

- RANSAC
- Kalman 2D
- adaptive point count

### 14.2. Noi `FeatureTracker` vao pipeline

Muc tieu:

- dam bao phan bo feature deu hon
- tang spatial robustness
- tao quality metric tot hon

### 14.3. Hieu chinh vision-to-heading gain

Can thay he so `0.3` bang gain co co so vat ly hon, dua tren:

- focal length
- FOV
- crop ratio
- van toc
- geometry cua ground plane

### 14.4. Danh gia dinh luong

Nen bo sung quy trinh do:

- heading RMSE so voi ground truth
- so sanh GPS-only, Vision-only, Fusion
- latency moi frame
- track survival ratio
- inlier ratio theo dieu kien moi truong

### 14.5. Hoan tat migration sang BLoC + repository

Dieu nay giup:

- luong xu ly de test hon
- tach biet presentation / domain / data
- de mo rong camera live feed ve sau

## 15. Ket luan

Module `vision` hien tai da dat duoc mot nen tang ky thuat kha ro rang cho bai toan ho tro dan duong GNSS bang thi giac may tinh. Phan dang chay thuc te dua tren:

- sparse optical flow Lucas-Kanade
- Shi-Tomasi feature selection trong ROI phan duoi frame
- semantic obstacle masking bang YOLOv8
- adaptive fusion voi GPS va IMU

Tu goc nhin he thong, day la mot thiet ke dung huong:

- nhe
- de chay tren Flutter
- co tinh mo rong
- da tinh den cac van de thuc te nhu vat the dong, rung camera va GPS khong on dinh

Tu goc nhin nghien cuu, he thong hien van la mot giai phap `heading assistance` dua tren vision, chua phai visual odometry day du. Tuy nhien, repo da co san cac thanh phan nang cao nhu `MotionEstimator`, `KalmanFilter2D` va `FeatureTracker`, cho thay huong nang cap tiep theo la kha ro rang va kha thi.

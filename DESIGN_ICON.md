# 🛰️ GNSS Vision — Icon Design Document

> **Phiên bản:** 1.0  
> **Ngày:** 30/04/2026  
> **Trạng thái:** Draft — Cần review & chọn concept cuối

---

## 1. Brand Identity

| Thuộc tính | Giá trị |
|------------|---------|
| **Tên ứng dụng** | GNSS Vision |
| **Tên gói (package)** | `com.gnss.vision` |
| **Tagline** | Định vị thông minh — Nhìn thấy đúng hướng |
| **Slogan (EN)** | See Beyond GPS |
| **Mission** | Kết hợp GNSS + Computer Vision + IMU sensor fusion để điều hướng chính xác trong môi trường đô thị phức tạp — nơi GPS đơn thuần không đủ độ tin cậy |
| **Core Values** | Chính xác • Thông minh • Tin cậy • Hiện đại |

### Đặc điểm khác biệt của GNSS Vision

Ứng dụng **không phải** chỉ là map navigation thông thường. Điểm khác biệt cốt lõi:

1. **Sensor Fusion** — Kết hợp 3 nguồn: GNSS satellite + Camera Vision + IMU accelerometer
2. **Vision-Based Heading** — Sử dụng optical flow (Lucas-Kanade) để xác định hướng di chuyển khi GPS yếu
3. **YOLO Obstacle Detection** — Nhận diện chướng ngại vật thời gian thực (xe, người, xe máy)
4. **Adaptive Weighting** — Tự động chuyển đổi GPS/Vision trọng số dựa trên chất lượng tín hiệu
5. **Urban Canyon Solution** — Hoạt động chính xác trong tunnel, ngõ hẹp, khu cao tầng

---

## 2. Design Principles

### 2.1 Nguyên tắc thiết kế

| # | Nguyên tắc | Mô tả |
|---|-----------|-------|
| 1 | **Instant Recognition** | Phân biệt được ngay ở kích thước 48×48px trên home screen |
| 2 | **Core Identity** | Phải thể hiện ít nhất 2/3 yếu tố: Vệ tinh (GNSS) + Mắt/Camera (Vision) + Định hướng (Navigation) |
| 3 | **Gradient DNA** | Sử dụng gradient `Purple → Cyan` là dấu ấn thương hiệu, nhất quán với splash screen hiện tại |
| 4 | **Dark-First** | Tối ưu cho dark background trước (default theme), sau đó làm light variant |
| 5 | **Scalability** | Rõ nét từ 32px (favicon) đến 1024px (App Store) |
| 6 | **Simplicity** | Tối đa 3 visual elements, tránh chi tiết nhỏ biến mất khi thu nhỏ |
| 7 | **No Text** | Không dùng chữ trong icon — "GNSS" hoặc "V" chỉ ở splash, không ở launcher |
| 8 | **Flat + Subtle Depth** | Phẳng为主, có thể dùng nhẹ gradient/shadow cho chiều sâu |

### 2.3 Kiểu dáng tham khảo (Visual Style Reference)

```
✅ Phong cách nên theo:
   - Material Design 3 icon guidelines
   - Duotone / Gradient flat
   - Geometric, đường nét clean
   - Symmetric hoặc near-symmetric

❌ Phong cách nên tránh:
   - Skeuomorphic (quá nhiều bóng, phản chiếu)
   - Detailed illustration (chi tiết nhỏ)
   - Photo-realistic
   - Chỉ dùng chữ (lettermark)
```

---

## 3. Color System

### 3.1 Primary Palette (from `app_theme.dart`)

| Token | HEX | RGB | Mô tả |
|-------|-----|-----|-------|
| `primaryColor` | `#7C6AFF` | (124, 106, 255) | Purple — màu chính GNSS |
| `primaryLight` | `#9B8AFF` | (155, 138, 255) | Purple nhạt |
| `primaryDark` | `#5F52E0` | (95, 82, 224) | Purple đậm |
| `secondaryColor` | `#22D3EE` | (34, 211, 238) | Cyan — màu Vision |
| `secondaryLight` | `#67E8F9` | (103, 232, 249) | Cyan nhạt |
| `secondaryDark` | `#0891B2` | (8, 145, 178) | Cyan đậm |
| `accentColor` | `#F87171` | (248, 113, 113) | Red accent |

### 3.2 Icon Gradients

| Gradient | Stops | Hướng | Dùng cho |
|----------|-------|-------|----------|
| **Primary Gradient** | `#7C6AFF` → `#22D3EE` | Top-Left → Bottom-Right | Icon chính, foreground |
| **Background Gradient** | `#0C1222` → `#111A2E` | Top → Bottom | Android adaptive icon bg |
| **Glow Gradient** | `#5F52E0` → `#0891B2` | Radial (center → edge) | Icon glow effect |
| **Monochrome** | `#FFFFFF` → `#B0B8D1` | Vertical | Notification / splash silhouette |

### 3.3 Adaptive Icon Variants

```
┌──────────────────────────────────────┐
│  DARK MODE (default)                 │
│  ┌──────────────────────────────┐    │
│  │  Background: #0C1222         │    │
│  │  Icon: Primary Gradient      │    │
│  │  Glow: subtle cyan outline   │    │
│  └──────────────────────────────┘    │
│                                      │
│  LIGHT MODE                          │
│  ┌──────────────────────────────┐    │
│  │  Background: #F5F7FB         │    │
│  │  Icon: primaryDark + cyanDark│    │
│  │  Shadow: subtle purple shadow│    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

### 3.4 Accessibility

- Icon phải nhận diện được **không cần màu** (shape-first design)
- Gradient chỉ là enhancement, không là yếu tố duy nhất phân biệt
- Contrast ratio tối thiểu **3:1** cho large icons (WCAG 2.1 AA Large)
- Kiểm tra icon ở grayscale để đảm bảo shape đủ mạnh

---

## 4. Icon Concepts

---

### Concept A — "🛰️ Satellite Eye"

#### Ý tưởng
Kết hợp **con mắt** (Vision) với **tín hiệu vệ tinh** (GNSS) — pupil của mắt là 3 vòng sóng vệ tinh đồng tâm, tạo ra biểu tượng vừa thể hiện khả năng "nhìn thấy" vừa thể hiện kết nối vệ tinh.

#### Mô tả hình khối

```
         ╭──────────╮
       ╱    ╭────╮    ╲       ← Viền ngoài: Eye shape (hạnh nhân)
      │   ╱ ~~~~ ~~~~ ╲   │       ← Iris: Gradient Purple→Cyan
      │  │  ◎  ◎  ◎  │  │       ← Pupil: 3 concentric satellite arcs
      │   ╲ ~~~~ ~~~~ ╱   │            thay vì hình tròn đơn điệu
       ╲    ╰────╯    ╱
         ╰──────────╯
              │
         ╰────╯ ← Tia sáng phản chiếu (catchlight)
```

#### Breakdown thành phần

| Phần | Hình khối | Màu sắc | Ý nghĩa |
|------|-----------|---------|---------|
| Viền ngoài (eye outline) | Hạnh nhân (almond shape) | `#9B8AFF` stroke 2.5px | Khả năng nhìn — Vision |
| Iris (tròng mắt) | Hình tròn, fill gradient radial | `#7C6AFF` → `#22D3EE` | Sự融合 GNSS+Vision |
| Pupil (đồng tử) | 3 vòng cung đồng tâm, mở về phải | `#0C1222` (dark) với glow cyan | Tín hiệu vệ tinh GNSS — 3 hệ: GPS, Galileo, BeiDou |
| Catchlight | Đường chéo trắng nhỏ góc 45° | `#FFFFFF` opacity 0.6 | Tính linh hoạt, phản xạ |
| Outer glow | Drop shadow radial | `#22D3EE` opacity 0.15 | Tầm nhìn xa, accuracy |

#### Ý nghĩa biểu tượng

- **Con mắt** = Vision (computer vision, camera, nhận diện)
- **Sóng vệ tinh trong pupil** = GNSS (GPS + GLONASS + Galileo + BeiDou)
- **Gradient Purple→Cyan** = Sensor fusion — GNSS nhường chỗ cho Vision khi tín hiệu yếu
- **Catchlight** = Sự chính xác, phản ứng nhanh

#### Đánh giá

| Tiêu chí | Điểm (1-5) | Ghi chú |
|----------|------------|---------|
| Simplicity | ⭐⭐⭐⭐ | Eye shape dễ nhận diện, pupil hơi phức tạp |
| Uniqueness | ⭐⭐⭐ | Eye icon phổ biến trong AI, cần satellite arcs để khác biệt |
| Scalability | ⭐⭐⭐⭐ | Eye shape vẫn rõ ở 48px, nhưng pupil arcs cần test ở 32px |
| Brand Alignment | ⭐⭐⭐⭐⭐ | Thể hiện hoàn hảo cả GNSS + Vision |
| Recognition | ⭐⭐⭐⭐ | Eye = nhìn/navigation, arcs = tech/satellite |

#### Biến thể

- **Dark mode**: Dark background, cyan glow outline quanh eye
- **Light mode**: White pupil arcs, deeper purple iris
- **Monochrome**: Outline-only, fill white
- **Adaptive Android**: Circular crop-safe — eye phải nằm trong safe zone 72×72dp

---

### Concept B — "🧭 Vision Compass"

#### Ý tưởng
**La bàn** (Navigation) với **camera lens aperture** (Vision) ở tâm — 8 hướng la bàn kết hợp với 6 lá aperture tạo thành hybrid vừa điều hướng vừa "nhìn thấy".

#### Mô tả hình khối

```
           N
           ▲
          ╱│╲            ← Compass points: 8 hướng, nét mỏng
      NW ╱ │ ╲ NE
        ╱  │  ╲
       ╱───●───╲         ← Center: Camera lens aperture (6 lá)
      ╱  ╱ │ ╲  ╲           Purple→Cyan gradient fill
    SW╱ ╱  │  ╲ ╲SE
      ╲    │    ╱
       ╲   │   ╱            ← Outer ring: Thin orbit ring
        ╲  │  ╱                cyan glow, 1.5px
         ╲ │ ╱
           ▼
           S
```

#### Breakdown thành phần

| Phần | Hình khối | Màu sắc | Ý nghĩa |
|------|-----------|---------|---------|
| Compass points (N/S/E/W) | 4 mũi tên tam giác dài | `#9B8AFF` stroke | 4 hướng chính — Navigation |
| Compass points (NE/SE/SW/NW) | 4 mũi tên tam giác ngắn | `#5F52E0` fill | 8 hướng phụ — Precision |
| Center lens | 6-blade aperture (hexagonal inner) | `#7C6AFF` → `#22D3EE` radial grad | Camera lens — Vision |
| Inner dot | Hình tròn nhỏ | `#22D3EE` bright | Accuracy point — destination |
| Outer ring | Vòng tròn mỏng | `#22D3EE` opacity 0.4 | Orbit vệ tinh — GNSS |
| North arrow highlight | Mũi Bắc phát sáng hơn | `#22D3EE` fill | Điểm định hướng chính |

#### Ý nghĩa biểu tượng

- **La bàn 8 hướng** = Navigation, định hướng không gian
- **Camera aperture** = Vision, computer vision, "nhìn thấy" đường đi
- **6 lá aperture** = Số người dùng có thể chỉnh tầm nhìn (zoom in/out)
- **North highlight** = Luôn biết phương hướng
- **Outer ring orbit** = Vệ tinh GNSS xoay quanh

#### Đánh giá

| Tiêu chí | Điểm (1-5) | Ghi chú |
|----------|------------|---------|
| Simplicity | ⭐⭐⭐ | Nhiều chi tiết (8 points + aperture) |
| Uniqueness | ⭐⭐⭐⭐ | Compass+lens là combo hiếm |
| Scalability | ⭐⭐⭐ | 8 direction arrows khó thấy ở 32-48px |
| Brand Alignment | ⭐⭐⭐⭐⭐ | Đầy đủ Navigation + Vision + GNSS orbit |
| Recognition | ⭐⭐⭐⭐ | Compass = navigation/navigation/định vị |

#### Biến thể

- **Dark mode**: Full detail, cyan glow
- **Light mode**: Thicker strokes, filled compass points
- **Simplified small**: Chỉ 4 hướng + aperture tròn (loại 4 hướng phụ)
- **Adaptive Android**: Circular crop — chỉ hiện inner compass + lens

---

### Concept C — "📡 Signal Flow"

#### Ý tưởng
**Location pin** (Navigation) kết hợp **tín hiệu vệ tinh** phát ra từ đỉnh (GNSS) và **optical flow arrows** bên trong (Vision) — biểu tượng thể hiện sự hội tụ của 3 nguồn dữ liệu vào một điểm duy nhất.

#### Mô tả hình khối

```
        ╭───╮
    ╱~~~│ ◎ │~~~╲         ← Pin head: tròn + 3 satellite wave arcs
   ╱    ╰───╯    ╲           phát ra 2 bên
  │  ╱  ───▶  ╲  │       ← Pin body: optical flow arrows (→)
  │ ╱   ───▶   ╲  │          hướng xuống, thể hiện motion vector
  │╱    ───▶    ╲ │
   ╲            ╱
    ╲          ╱
      ╲      ╱            ← Pin point: đỉnh nhọn trỏ xuống
        ╲  ╱                 = exact location
         ▼
```

#### Breakdown thành phần

| Phần | Hình khối | Màu sắc | Ý nghĩa |
|------|-----------|---------|---------|
| Pin head | Hình tròn | `#7C6AFF` fill | Vị trí — Location |
| Pin inner dot | Hình tròn nhỏ | `#22D3EE` fill | Accuracy point — vị trí chính xác |
| Satellite waves | 3 cung tròn đồng tâm, 2 bên | `#22D3EE` stroke 2px, opacity giảm dần | Tín hiệu GNSS phát ra |
| Pin body | Hình tam giác/chân pin | Gradient `#7C6AFF` → `#5F52E0` | Vùng phủ của vị trí |
| Optical flow arrows | 3 mũi tên song song → hướng xuống | `#22D3EE` fill, opacity 0.8 | Optical flow — Vision tracking |
| Pin point | Đỉnh nhọn | `#5F52E0` | Vị trí chính xác destination |

#### Ý nghĩa biểu tượng

- **Location pin** = Navigation, định vị, "bạn ở đây"
- **Satellite waves** = GNSS signal broadcast — kết nối vệ tinh
- **Optical flow arrows bên trong** = Vision data flowing alongside GPS — sensor fusion
- **Pin narrowing down** = Độ chính xác tăng khi kết hợp nhiều nguồn
- **Purple body + Cyan accents** = GNSS gốc → Vision bổ trợ

#### Đánh giá

| Tiêu chí | Điểm (1-5) | Ghi chú |
|----------|------------|---------|
| Simplicity | ⭐⭐⭐⭐ | Pin shape quen thuộc, waves và arrows đơn giản |
| Uniqueness | ⭐⭐⭐⭐ | Pin + waves + arrows là combo độc đáo |
| Scalability | ⭐⭐⭐⭐ | Pin shape rõ ở mọi kích thước, arrows cần test ở 32px |
| Brand Alignment | ⭐⭐⭐⭐ | Thể hiện GNSS + Navigation rõ, Vision qua arrows hơi gián tiếp |
| Recognition | ⭐⭐⭐⭐⭐ | Pin = location/navigation, hiểu ngay |

#### Biến thể

- **Dark mode**: Full gradient, cyan waves glow
- **Light mode**: Solid purple pin, darker cyan accents
- **Simplified small**: Bỏ arrows, chỉ pin + waves
- **Adaptive Android**: Pin nằm trong circular safe zone, waves crop-friendly

---

### Concept D — "🌍 Orbit Navigator"

#### Ý tưởng
**Location pin** ở trung tâm + **3 vòng quỹ đạo nghiêng** (GNSS + IMU + Vision) xung quanh — nhất quán với **logo in-app hiện tại** đang dùng `Icons.explore_rounded` + 3 orbital circles trong splash screen và onboarding.

#### Mô tả hình khối

```
        ╭─────────────╮
      ╱ ~~~~ ╭───╮ ~~~~ ╲      ← 3 orbital rings nghiêng khác nhau
     │  ~~~  │ ▼ │  ~~~  │         mỗi ring = 1 sensor source
     │  ~~~  ╰───╯  ~~~  │         Ring 1 (horizontal): GNSS
     │   ~~~   │   ~~~   │         Ring 2 (tilt 60°): Camera/Vision  
      ╲  ~~~  │  ~~~   ╱          Ring 3 (tilt -60°): IMU
        ╲  ~~~│~~~  ╱
          ╲   ▼   ╱          ← Pin point ở dưới
            ╲ │ ╱
             ▼
```

#### Bản vẽ chi tiết — Front View

```
              ╭───╮
         ╱~~  │ ▼ │  ~~╲        ← Top ring: tilted 60°
        ╱     ╰───╯     ╲          Canvas/Vision
       │      ╱ │ ╲      │
       │    ╱   │   ╲    │       ← Middle ring: horizontal
       │   │    ▼    │   │          GNSS satellites
       │    ╲   │   ╱    │
       │      ╲ │ ╱      │       ← Bottom ring: tilted -60°
        ╲      ▼      ╱           IMU sensors
          ╲    │    ╱
             ╲ │ ╱
               ▼               ← Pin point
```

#### Breakdown thành phần

| Phần | Hình khối | Màu sắc | Ý nghĩa |
|------|-----------|---------|---------|
| Central pin | Location pin (teardrop) | `#7C6AFF` → `#22D3EE` gradient | Vị trí — Navigation + fusion |
| Pin inner icon | Small compass/explore icon | `#FFFFFF` fill | Khả năng định hướng |
| Ring 1 (horizontal) | Ellipse ngang, stroke 2px | `#22D3EE` | GNSS — vệ tinh định vị |
| Ring 2 (tilt 60°) | Ellipse nghiêng phải | `#9B8AFF` | Vision — camera nhìn thấy |
| Ring 3 (tilt -60°) | Ellipse nghiêng trái | `#67E8F9` opacity 0.7 | IMU — cảm biến chuyển động |
| Pin shadow | Drop shadow | `#7C6AFF` opacity 0.3 | Depth effect |

#### Ý nghĩa biểu tượng

- **Location pin trung tâm** = Bạn ở đây — vị trí chính xác nhờ fusion
- **3 orbital rings** = 3 nguồn dữ liệu sensor (GNSS + Vision + IMU), mỗi nguồn một ring
- **Rings intersecting** = Tại điểm giao nhau (pin) — dữ liệu được **fusion** lại
- **Gradient trên pin** = Từ GNSS (purple) chuyển sang Vision (cyan) — đúng logic của app
- ** Nhất quán với splash screen hiện tại** — 3 rotating orbital circles đã có trong code

#### Ưu điểm đặc biệt: Nhất quán với codebase hiện tại

Trong `splash_screen.dart` và `onboarding_screen.dart`, logo đã được triển khai:

```dart
// Hiện tại trong code:
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      colors: [primaryColor, secondaryColor],  // #7C6AFF → #22D3EE
    ),
  ),
  child: Icons.explore_rounded,  // ← Compass/navigation icon
)
// + 3 rotating orbital circles
```

**Concept D nâng cấp logo hiện tại** bằng cách:
- Giữ nguyên 3 orbital rings (quen thuộc với người dùng đã thấy splash)
- Thay `Icons.explore_rounded` bằng **location pin** chuyên biệt (không dùng material icon nữa)
- Gradient chuyển từ nằm trong vòng tròn sang nằm trên pin (sleeker)

#### Đánh giá

| Tiêu chí | Điểm (1-5) | Ghi chú |
|----------|------------|---------|
| Simplicity | ⭐⭐⭐⭐ | Pin quen thuộc, rings đơn giản |
| Uniqueness | ⭐⭐⭐⭐⭐ | Pin + 3 orbital rings là unique, không trùng app nào |
| Scalability | ⭐⭐⭐ | Rings biến mất ở 32-48px, cần simplified variant |
| Brand Alignment | ⭐⭐⭐⭐ | Navigation + GNSS rõ, Vision gián tiếp qua ring |
| Recognition | ⭐⭐⭐⭐ | Pin = location, rings = tech/orbital |

#### Biến thể

- **Dark mode**: Full rings, cyan glow, gradient pin
- **Light mode**: Thicker rings, solid purple pin
- **Simplified small (≤48px)**: Pin + 1 ring duy nhất (horizontal) — bỏ 2 ring nghiêng
- **Simplified tiny (≤32px)**: Chỉ pin + inner compass icon — không rings
- **Adaptive Android**: Rings bị crop khi circular → cần background gradient环比

---

## 5. Concept Comparison Matrix

```
╔══════════════════╦═════════════╦═══════════════╦═══════════════╦═══════════════╗
║     Tiêu chí     ║  Concept A  ║  Concept B    ║  Concept C    ║  Concept D    ║
║                  ║ Satellite   ║  Vision       ║  Signal       ║  Orbit        ║
║                  ║ Eye         ║  Compass       ║  Flow         ║  Navigator    ║
╠══════════════════╬═════════════╬═══════════════╬═══════════════╬═══════════════╣
║ Simplicity       ║   ★★★★☆    ║   ★★★☆☆      ║   ★★★★☆      ║   ★★★★☆      ║
║ Uniqueness       ║   ★★★☆☆    ║   ★★★★☆      ║   ★★★★☆      ║   ★★★★★      ║
║ Scalability      ║   ★★★★☆    ║   ★★★☆☆      ║   ★★★★☆      ║   ★★★☆☆      ║
║ Brand Alignment  ║   ★★★★★    ║   ★★★★★      ║   ★★★★☆      ║   ★★★★☆      ║
║ Recognition      ║   ★★★★☆    ║   ★★★★☆      ║   ★★★★★      ║   ★★★★☆      ║
║ Codebase Sync    ║   ★★☆☆☆    ║   ★★☆☆☆      ║   ★★☆☆☆      ║   ★★★★★      ║
╠══════════════════╬═════════════╬═══════════════╬═══════════════╬═══════════════╣
║ TỔNG ĐIỂM       ║    21/30    ║    21/30      ║    22/30      ║    24/30      ║
╚══════════════════╩═════════════╩═══════════════╩═══════════════╩═══════════════╝
```

### Khuyến nghị: **Concept D — Orbit Navigator** 🏆

**Lý do:**
1. **Điểm tổng cao nhất** (24/30)
2. **Nhất quán với codebase** — 3 orbital circles đã có trong splash/onboarding, người dùng quen thuộc
3. **Unique nhất** — Pin + 3 orbital rings không trùng AI/navigation app nào
4. **Thể hiện đủ 3 sensor sources** — Mỗi ring = GNSS, Vision, IMU
5. **Migration dễ nhất** — Chỉ cần nâng cấp logo hiện tại thay vì thiết kế hoàn toàn mới

**Nhược điểm & Giải pháp:**
- Rings biến mất ở size nhỏ → Cần simplified variants (xem mục 4.4 Variants)
- Circular crop trên Android → Gradient background xử lý

**Concept thay thế: Concept C — Signal Flow** (nếu muốn nhấn mạnh hơn vào Navigation/location)

---

## 6. Size Specifications

### 6.1 Android Adaptive Icon

```
┌─────────────────────────────────────────┐
│  Full bleed area: 108 × 108 dp          │
│  ┌─────────────────────────────────┐    │
│  │  Safe zone: 72 × 72 dp          │    │
│  │  (centered, icon foreground     │    │
│  │   must be fully visible here)    │    │
│  │                                  │    │
│  │       ╭──────────╮              │    │
│  │       │  ICON    │              │    │
│  │       │  CORE    │              │    │
│  │       ╰──────────╯              │    │
│  │                                  │    │
│  └─────────────────────────────────┘    │
│  (18dp margin each side can be cropped) │
└─────────────────────────────────────────┘

Background layer: Gradient #0C1222 → #111A2E (dark theme)
Foreground layer: Icon on transparent background
Monochrome: White silhouette for themed icon
```

### 6.2 iOS App Icon

```
iOS icon: 1024 × 1024 px (master)
Rounded corners: iOS auto-applies superellipse mask

Required sizes:
┌────────────┬───────────────┐
│ Usage      │ Size (px)      │
├────────────┼───────────────┤
│ App Store  │ 1024 × 1024    │
│ iPhone     │ 180 × 180 (3x) │
│ iPhone     │ 120 × 120 (2x) │
│ iPad Pro   │ 167 × 167 (2x) │
│ iPad       │ 152 × 152 (2x) │
│ Spotlight  │ 120 × 120      │
│ Settings   │ 87 × 87        │
│ Notification│ 60 × 60       │
└────────────┴───────────────┘
```

### 6.3 Web & Other Platforms

| Platform | Size | Ghi chú |
|----------|------|---------|
| Web favicon | 32×32, 16×16 | Monochrome hoặc simplified |
| Web icon (pwa) | 192×192 | Full icon |
| Web icon (pwa) | 512×512 | Full icon |
| Web maskable | 192×192, 512×512 | Safe zone 80%, padding 10% |
| Windows | 44×44, 50×50, 150×150, 310×310 | Tile icon |
| macOS | 16→1024 (all sizes) | Rounded rect auto |

### 6.4 Simplified Variants theo Size

```
╔══════════════╦═══════════════════════════════════════════╗
║  Size Range  ║  Detail Level (Concept D — Orbit Navigator) ║
╠══════════════╬═══════════════════════════════════════════╣
║  1024px      ║  Full: Pin + inner icon + 3 rings + glow  ║
║  512px       ║  Full: Pin + inner icon + 3 rings           ║
║  192px       ║  Standard: Pin + inner icon + 3 rings       ║
║  180px       ║  Standard: Pin + inner icon + 3 rings       ║
║  152px       ║  Standard: Pin + inner icon + 3 rings       ║
║  120px       ║  Simplified: Pin + inner dot + 3 rings      ║
║  87px        ║  Simplified: Pin + inner dot + 1 ring        ║
║  60px        ║  Minimal: Pin + inner dot + 1 ring           ║
║  48px        ║  Minimal: Pin + gradient fill only            ║
║  32px        ║  Micro: Pin outline only                     ║
║  16px        ║  Micro: Single dot (favicon)                 ║
╚══════════════╩═══════════════════════════════════════════╝
```

---

## 7. Technical Implementation

### 7.1 Master File Format

```
Khuyến nghị: Tạo icon dưới dạng SVG vector master file

Cấu trúc file:
assets/
├── branding/
│   ├── icon_master.svg          ← Master vector file
│   ├── icon_foreground.svg      ← Android adaptive foreground
│   ├── icon_background.svg      ← Android adaptive background
│   ├── icon_monochrome.svg      ← Themed icon silhouette
│   ├── icon_ios_1024.png        ← iOS App Store
│   └── icon_source/             ← Figma/Sketch source
│       ├── concept_D.fig
│       └── variants.fig
```

### 7.2 `flutter_launcher_icons` Configuration

Thêm vào `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  web:
    generate: true
  windows:
    generate: true
  macos:
    generate: true

  image_path: "assets/branding/icon_master_1024.png"

  adaptive_icon_foreground: "assets/branding/icon_foreground.png"
  adaptive_icon_background: "assets/branding/icon_background.png"
  adaptive_icon_monochrome: "assets/branding/icon_monochrome.png"

  web_manifest:
    background_color: "#0C1222"
    theme_color: "#7C6AFF"
```

### 7.3 Generation Commands

```bash
# Sau khi có file PNG master:
flutter pub get
flutter pub run flutter_launcher_icons

# Hoặc dùng flutter_app_icons (khuyến nghị cho adaptive icons):
# dart run flutter_app_icons
```

### 7.4 Splash Screen Consistency

Sau khi có icon, cần cập nhật logo trong code đồng bộ:

**File cần cập nhật:**
1. `lib/screens/splash_screen.dart` — Thay `Icons.explore_rounded` bằng icon mới
2. `lib/screens/onboarding_screen.dart` — Thay `Icons.explore_rounded` bằng icon mới
3. `lib/core/app_theme.dart` — Nếu cần điều chỉnh gradient cho khớp

**Approach:**
- Giữ 3 orbital circles animation (đã có sẵn)
- Thay `Icons.explore_rounded` bằng **CustomPaint** vẽ pin shape từ icon design
- Hoặc dùng `SvgPicture.asset` nếu có SVG asset

--- 

## 8. Design Checklist

Trước khi finalize, đảm bảo:

- [ ] Icon nhận diện được ở 48×48px mà không cần chữ
- [ ] Icon khác biệt với Google Maps, Waze, Mapbox, OSM icons
- [ ] Gradient Purple→Cyan đúng palette (`#7C6AFF` → `#22D3EE`)
- [ ] Icon work trên cả dark và light background
- [ ] Adaptive icon safe zone (72×72dp) không crop detail quan trọng
- [ ] Simplified variants đã được thiết kế cho 32px và 16px
- [ ] iOS superellipse crop không cắt mất detail
- [ ] Monochrome version đủ rõ cho notification/themed icon
- [ ] File SVG master giữ full vector, stroke-based khi có thể
- [ ] Export PNG ở 1024×1024 pixels,  transparent background
- [ ] `flutter_launcher_icons` config trong `pubspec.yaml`
- [ ] Splash screen logo cập nhật cho khớp

---

## 9. Timeline & Next Steps

| Bước | Công việc | Thời gian dự kiến |
|------|-----------|-------------------|
| 1 | Chọn concept cuối (review team) | 1-2 ngày |
| 2 | Phác thảo vector draft (SVG) | 2-3 ngày |
| 3 | Chỉnh sửa chi tiết & gradient | 1-2 ngày |
| 4 | Export variants cho mọi size | 1 ngày |
| 5 | Cấu hình `flutter_launcher_icons` | 0.5 ngày |
| 6 | Generate & verify trên mỗi platform | 1 ngày |
| 7 | Cập nhật splash screen để nhất quán | 1 ngày |
| 8 | QA trên thiết bị thật (Android + iOS) | 1-2 ngày |
| **Tổng** | | **9-13 ngày** |

---

## 10. References

### In-App Color Palette
- Primary gradient: `RadialGradient(colors: [Color(0xFF7C6AFF), Color(0xFF22D3EE)])`
- Background dark: `Color(0xFF0C1222)`
- Surface dark: `Color(0xFF111A2E)`

### Competitor Icons (for differentiation)
- **Google Maps**: Xe đường màu (navigation pin)
- **Waze**: Smile balloon (social navigation)
- **Mapbox**: Hexagon (developer platform)
- **HERE**: Blue circle dot (location)
- **OsmAnd**: Map với compass (open source)

**GNSS Vision khác biệt**: Kết hợp **orbital rings** (satellite) + **location pin** (navigation) + **gradient fusion** (sensor combining) — không competitor nào có 3 yếu tố này cùng lúc.

---

## 11. Implementation Status

### Files Created

| File | Mô tả |
|------|-------|
| `assets/branding/icons/concept_D_orbit_navigator.svg` | **Concept D master** — Full icon with dark background, all effects |
| `assets/branding/icons/concept_A_satellite_eye.svg` | Concept A — Satellite Eye alternative |
| `assets/branding/icons/concept_B_vision_compass.svg` | Concept B — Vision Compass alternative |
| `assets/branding/icons/concept_C_signal_flow.svg` | Concept C — Signal Flow alternative |
| `assets/branding/icons/icon_foreground.svg` | Android adaptive icon foreground (no background) |
| `assets/branding/icons/icon_background.svg` | Android adaptive icon background (gradient) |
| `assets/branding/icons/icon_monochrome.svg` | Monochrome silhouette for themed icons |
| `lib/core/widgets/gnss_vision_icon.dart` | Flutter CustomPainter widget (`GnssVisionIcon` + `AnimatedGnssVisionIcon`) |

### Files Modified

| File | Thay đổi |
|------|----------|
| `pubspec.yaml` | Added `flutter_launcher_icons` dev dependency + config + branding assets |
| `lib/core/pages/splash_screen.dart` | Replaced `Icons.explore_rounded` with `AnimatedGnssVisionIcon` |
| `lib/core/pages/onboarding_screen.dart` | Replaced `Icons.explore_rounded` with `GnssVisionIcon` |

### Flutter Widget Usage

```dart
// Static icon (simplified, no animation)
GnssVisionIcon(
  size: 120,
  showOrbits: true,
  showSatellites: true,
  showGlow: true,
)

// Animated icon (orbits rotate slowly)
AnimatedGnssVisionIcon(
  size: 120,
  showOrbits: true,
  showSatellites: true,
  showGlow: true,
)

// Simplified for small sizes
GnssVisionIcon(
  size: 48,
  showOrbits: false,
  showSatellites: false,
  showGlow: false,
)
```

### Icon Generation Steps (Next)

Để generate launcher icons từ SVG master:

```bash
# 1. Convert SVG to PNG 1024x1024 (dùng Inkscape, Figma, hoặc online tool)
#    Khuyến nghị: Inkscape CLI
inkscape assets/branding/icons/concept_D_orbit_navigator.svg -w 1024 -h 1024 -o assets/branding/icons/concept_D_orbit_navigator.png
inkscape assets/branding/icons/icon_foreground.svg -w 1024 -h 1024 -o assets/branding/icons/icon_foreground.png
inkscape assets/branding/icons/icon_background.svg -w 1024 -h 1024 -o assets/branding/icons/icon_background.png
inkscape assets/branding/icons/icon_monochrome.svg -w 1024 -h 1024 -o assets/branding/icons/icon_monochrome.png

# 2. Generate launcher icons cho tất cả platforms
flutter pub get
dart run flutter_launcher_icons

# 3. Verify icons trên thiết bị/device emulator
flutter run
```

---

*Tài liệu này thuộc dự án GNSS Vision Navigation App — DATN 2026*
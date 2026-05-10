# GuidePoint: Revised Architecture — Sensor Fusion Indoor Navigation

**Document Version:** 1.0  
**Last Updated:** January 27, 2025  
**Status:** Technical Specification

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Context Diagram](#2-system-context-diagram)
3. [High-Level Architecture](#3-high-level-architecture)
4. [Detailed Component Diagrams](#4-detailed-component-diagrams)
5. [Data Flow Specifications](#5-data-flow-specifications)
6. [Technology Stack & Interfaces](#6-technology-stack--interfaces)
7. [Enhancement Specifications](#7-enhancement-specifications)
8. [Implementation Notes & Constraints](#8-implementation-notes--constraints)
9. [Phasing & Milestones](#9-phasing--milestones)

---

## 1. Executive Summary

GuidePoint uses **sensor fusion** to provide indoor navigation for visually impaired users. The architecture combines:

| Modality | Component | Role |
|----------|-----------|------|
| **Initialization** | QR Code Scan | Establishes map + building context |
| **Continuous Tracking** | ARCore (Android) / ARKit (iOS) VIO | Position + orientation in real time |
| **Waypoint Confirmation** | Scene Classification CNN (cloud) | Validates arrival, corrects drift |
| **Fallback** | Pedometer (step count) | Distance when VIO unavailable |
| **Output** | TTS + Haptics | Audio and tactile guidance |

**Critical Fix:** The app currently hardcodes `startId = 'main_entrance'` in `qr_scanner_screen.dart` (line 149). The architecture replaces this with **QR-derived or CNN-derived** start location.

---

## 2. System Context Diagram

```
                                    EXTERNAL SYSTEMS
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                       │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │
│   │ QR Code     │    │ Cloud APIs  │    │ Map Host    │    │ FCM / Alerts│           │
│   │ (physical)  │    │ (Scene CNN) │    │ (HTTP)      │    │ (push)      │           │
│   └──────┬──────┘    └──────▲──────┘    └──────▲──────┘    └──────▲──────┘           │
│          │                  │                  │                  │                   │
└──────────┼──────────────────┼──────────────────┼──────────────────┼───────────────────┘
           │                  │                  │                  │
           │ scan             │ POST /classify   │ GET map JSON     │ push notification
           │                  │                  │                  │
           ▼                  │                  │                  │
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                           GUIDEPOINT MOBILE APP                                       │
│                                                                                       │
│   USER  ──►  Camera │ Mic │ Touch  ──►  App  ──►  TTS │ Haptics │ Screen             │
│                                                                                       │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**Actors:**
- **User:** Visually impaired; uses voice, camera, haptics.
- **QR Code:** Encodes map URL or inline JSON (e.g. `{"building":{"name":"ATL","floors":[...]}}`).
- **Cloud:** Scene CNN API, optional map host, FCM.

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              GUIDEPOINT SENSOR FUSION ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                          FLUTTER APPLICATION LAYER                                │   │
│  │                                                                                   │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │   │
│  │  │   INPUT        │  │   TRACKING     │  │   NAVIGATION   │  │   OUTPUT       │  │   │
│  │  │   ───────      │  │   ───────      │  │   ───────      │  │   ───────      │  │   │
│  │  │ • QR Scanner   │  │ • VIO Engine   │  │ • Route Mgmt   │  │ • TTS          │  │   │
│  │  │ • Voice (STT)  │  │ • Position     │  │ • Waypoint     │  │ • Haptics      │  │   │
│  │  │ • Camera       │  │   Estimator    │  │   Detection    │  │ • Audio cues   │  │   │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘  └───────▲────────┘  │   │
│  │          │                   │                   │                   │           │   │
│  │          └───────────────────┼───────────────────┘                   │           │   │
│  │                              │                                       │           │   │
│  │                              ▼                                       │           │   │
│  │                    ┌─────────────────────┐                           │           │   │
│  │                    │  NAVIGATION         │───────────────────────────┘           │   │
│  │                    │  CONTROLLER         │                                        │   │
│  │                    │  (Orchestrator)     │                                        │   │
│  │                    └─────────┬───────────┘                                        │   │
│  │                              │                                                    │   │
│  └──────────────────────────────┼────────────────────────────────────────────────────┘   │
│                                 │                                                         │
│                                 │ HTTPS / REST                                            │
│                                 ▼                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                          CLOUD / BACKEND LAYER                                    │   │
│  │                                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │ Scene CNN    │  │ Map Store    │  │ STT (opt)    │  │ Alerts       │          │   │
│  │  │ API          │  │ Firestore    │  │ Deepgram     │  │ FCM          │          │   │
│  │  │ /classify    │  │ maps/{id}    │  │ /transcribe  │  │ push         │          │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘          │   │
│  │                                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Detailed Component Diagrams

### 4.1 Sensor Layer (Hardware Abstraction)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SENSOR LAYER                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   CAMERA     │  │     IMU      │  │   COMPASS    │  │  PEDOMETER   │         │
│  │   ──────     │  │   ──────     │  │   ──────     │  │   ──────     │         │
│  │ • RGB frames │  │ • Accel      │  │ • Heading    │  │ • Step count │         │
│  │ • 30 fps     │  │ • Gyro       │  │ • 10 Hz      │  │ • Event-based│         │
│  │ • For VIO +  │  │ • 100 Hz     │  │ • Mag north  │  │ • ~0.7m/step │         │
│  │   CNN frames │  │ • Fused in   │  │ • When       │  │ • Fallback   │         │
│  │              │  │   ARCore     │  │   stationary │  │   only       │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                 │                  │
│         └─────────────────┼─────────────────┼─────────────────┘                  │
│                           │                 │                                    │
│                           ▼                 ▼                                    │
│                  ┌────────────────────────────────────┐                          │
│                  │  ARCore (Android) / ARKit (iOS)     │                          │
│                  │  Visual-Inertial Odometry (VIO)     │                          │
│                  │  Output: pose (x,y,z, qx,qy,qz,qw)  │                          │
│                  │  Drift: ~1-2% of traveled distance  │                          │
│                  └────────────────────────────────────┘                          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Sensor Specifications:**

| Sensor | Platform API | Update Rate | Units | Notes |
|--------|--------------|-------------|-------|-------|
| Camera | ARCore/ARKit | 30–60 Hz | RGB frames | Used for VIO + scene capture |
| Accelerometer | System IMU | ~100 Hz | m/s² | Fused inside ARCore/ARKit |
| Gyroscope | System IMU | ~100 Hz | rad/s | Fused inside ARCore/ARKit |
| Magnetometer | Compass API | ~10 Hz | degrees | Heading when stationary |
| Pedometer | `step_counter` (Android) / `CMPedometer` (iOS) | Event | steps | Fallback when VIO unavailable |

---

### 4.2 Position Estimator (Fusion Logic)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        POSITION ESTIMATOR (Sensor Fusion)                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  INPUTS                                                                          │
│  ──────                                                                          │
│  • VIO pose (x, y, z, qx, qy, qz, qw) — from ARCore/ARKit                        │
│  • Pedometer step count — when VIO unavailable                                    │
│  • Scene CNN confirmation — (location_id, confidence) when near waypoint          │
│  • Initial origin — from QR scan (node_id, map coordinates)                       │
│                                                                                  │
│  FUSION RULES                                                                    │
│  ───────────                                                                    │
│  1. PRIMARY: Use VIO pose when ARCore/ARKit tracking state == TRACKING            │
│  2. FALLBACK: Use pedometer (steps × 0.7 m) when VIO == PAUSED or STOPPED         │
│  3. RESET: On Scene CNN confirmation (confidence ≥ 0.85):                         │
│     - Set origin to confirmed waypoint coordinates                                │
│     - Reset VIO drift relative to new origin                                      │
│  4. COORDINATE FRAME: Map coordinates (meters) — aligned at QR scan               │
│                                                                                  │
│  OUTPUTS                                                                         │
│  ───────                                                                         │
│  • current_position: (x, y) in map meters                                         │
│  • current_heading: degrees (0 = North, 90 = East)                                │
│  • tracking_source: "vio" | "pedometer" | "unknown"                               │
│  • last_confirmed_waypoint: node_id | null                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.3 Navigation Controller

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         NAVIGATION CONTROLLER                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  STATE                                                                           │
│  ─────                                                                           │
│  • route: [node_id_1, node_id_2, ...]  — from A* pathfinding                     │
│  • current_waypoint_index: int                                                   │
│  • target_node_id: string                                                        │
│  • position_estimator: PositionEstimator                                         │
│  • map: BuildingMap (nodes, edges)                                               │
│                                                                                  │
│  LOGIC (runs every ~100 ms)                                                      │
│  ─────────────────────────                                                       │
│  1. Get current (x, y), heading from PositionEstimator                            │
│  2. next_waypoint = route[current_waypoint_index + 1]                             │
│  3. dist_to_next = distance(current, next_waypoint)                               │
│                                                                                  │
│  4. IF dist_to_next < WAYPOINT_THRESHOLD (e.g. 2.0 m):                            │
│       a. Capture camera frame                                                    │
│       b. Call Scene CNN API with frame                                           │
│       c. IF CNN returns next_waypoint with confidence ≥ 0.85:                     │
│          - Confirm arrival at next_waypoint                                       │
│          - Reset PositionEstimator origin to next_waypoint                        │
│          - current_waypoint_index += 1                                            │
│          - Play "You have reached {waypoint_name}"                                │
│          - If more waypoints: play next instruction                               │
│          - If destination: play "You have reached your destination"               │
│                                                                                  │
│  5. ELSE:                                                                        │
│       - Play distance/heading cue (e.g. "Continue straight, 3 meters to junction")│
│                                                                                  │
│  6. IF off_route_detected():                                                      │
│       - Re-run A* from current_estimated_node to target                           │
│       - Update route, play "Recalculating route"                                  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Constants:**
- `WAYPOINT_THRESHOLD`: 2.0 m (trigger CNN confirmation)
- `CNN_CONFIDENCE_THRESHOLD`: 0.85
- `OFF_ROUTE_THRESHOLD`: 5.0 m (distance from route segment)
- `CONTROL_LOOP_MS`: 100 ms

---

### 4.4 Scene CNN API (Cloud)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SCENE CLASSIFICATION CNN API                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ENDPOINT: POST /classify                                                        │
│  HOST: e.g. https://guidepoint-scene-xxx.run.app                                 │
│                                                                                  │
│  REQUEST                                                                         │
│  ───────                                                                         │
│  Content-Type: application/json                                                  │
│  Body: {                                                                         │
│    "image": "<base64-encoded JPEG>",                                             │
│    "building_id": "ATL",                                                         │
│    "candidate_locations": ["main_entrance", "junction_1", "seminar_hall", ...]   │
│  }                                                                               │
│                                                                                  │
│  RESPONSE                                                                        │
│  ────────                                                                        │
│  {                                                                               │
│    "location_id": "junction_1",                                                  │
│    "confidence": 0.91,                                                           │
│    "alternatives": [                                                             │
│      {"location_id": "seminar_hall", "confidence": 0.07}                         │
│    ]                                                                             │
│  }                                                                               │
│                                                                                  │
│  MODEL: MobileNetV2 or EfficientNet-Lite0, trained on indoor room images         │
│  CLASSES: Map node IDs (main_entrance, junction_1, seminar_hall, idea_labs, …)   │
│  INPUT SIZE: 224×224 or 128×128                                                  │
│  INFERENCE: ~50–100 ms (Cloud Run)                                               │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 4.5 Map Data Model

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         MAP DATA MODEL (JSON / Firestore)                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  EXAMPLE: ATL map (data/maps/ATL_JSON.json)                                            │
│                                                                                  │
│  {                                                                               │
│    "building": {                                                                 │
│      "name": "ATL",                                                              │
│      "floors": [{                                                                │
│        "floor_number": 1,                                                        │
│        "nodes": [                                                                │
│          {"id": "main_entrance", "name": "Main Entrance", "position": [0, 0]},   │
│          {"id": "junction_1", "name": "Hallway Junction", "position": [0, 3]},   │
│          {"id": "seminar_hall", "name": "Seminar Hall", "position": [4, 3]},     │
│          {"id": "idea_labs", "name": "Idea Labs", "position": [-2, 3]}           │
│        ],                                                                        │
│        "edges": [                                                                │
│          {"from_id": "main_entrance", "to_id": "junction_1", "distance": 3},     │
│          {"from_id": "junction_1", "to_id": "seminar_hall", "distance": 4},      │
│          {"from_id": "junction_1", "to_id": "idea_labs", "distance": 2}          │
│        ]                                                                         │
│      }]                                                                          │
│    }                                                                             │
│  }                                                                               │
│                                                                                  │
│  COORDINATE SYSTEM: (x, y) in meters; origin at main_entrance (0,0)              │
│  EDGE: from_id, to_id, distance (meters)                                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Data Flow Specifications

### 5.1 Flow 1: Navigation Start (Replace Hardcoded main_entrance)

```
┌─────────┐     ┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  USER   │     │  QR SCAN    │     │  MAP LOAD       │     │  START LOCATION │
└────┬────┘     └──────┬──────┘     └────────┬────────┘     └────────┬────────┘
     │                 │                     │                        │
     │ Scan QR         │                     │                        │
     │────────────────►│                     │                        │
     │                 │ Parse: URL or       │                        │
     │                 │ inline JSON         │                        │
     │                 │────────────────────►│                        │
     │                 │                     │ Load nodes, edges      │
     │                 │                     │ AStarPathfinder init   │
     │                 │                     │                        │
     │                 │                     │ OPTION A: QR contains  │
     │                 │                     │ node_id (e.g. at       │
     │                 │                     │ junction_1)            │
     │                 │                     │───────────────────────►│
     │                 │                     │ OPTION B: QR generic   │
     │                 │                     │ → use Scene CNN on     │
     │                 │                     │ first frame to get     │
     │                 │                     │ start_id               │
     │                 │                     │───────────────────────►│
     │                 │                     │ OPTION C: Default      │
     │                 │                     │ main_entrance          │
     │                 │                     │───────────────────────►│
     │                 │                     │                        │
     │ Voice: dest     │                     │                        │
     │────────────────►│                     │                        │
     │                 │ _findPathToDest()   │                        │
     │                 │ startId = from QR/  │                        │
     │                 │ CNN or default      │                        │
     │                 │ targetId = from STT │                        │
     │                 │ A* → pathIds        │                        │
     │                 │ _navigateToGuidance │                        │
     │                 │                     │                        │
```

**Enhancement:** Replace `const String startId = 'main_entrance'` (line 149, `qr_scanner_screen.dart`) with:

1. If QR payload contains `start_node_id`, use it.
2. Else, capture one frame and call Scene CNN; use top result if confidence ≥ 0.75.
3. Else, fallback to `main_entrance`.

---

### 5.2 Flow 2: Continuous Navigation (VIO + CNN Confirmation)

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  VIO / PEDO     │     │  POS ESTIMATOR  │     │  NAV CONTROLLER │     │  SCENE CNN API  │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │                       │
         │ pose / steps          │                       │                       │
         │──────────────────────►│                       │                       │
         │                       │ (x,y), heading        │                       │
         │                       │──────────────────────►│                       │
         │                       │                       │ dist_to_next < 2m?    │
         │                       │                       │ YES                   │
         │                       │                       │ Capture frame         │
         │                       │                       │──────────────────────►│
         │                       │                       │                       │
         │                       │                       │ {location_id, conf}   │
         │                       │                       │◄──────────────────────│
         │                       │ Confirm waypoint      │                       │
         │                       │◄──────────────────────│                       │
         │                       │ Reset origin          │                       │
         │                       │                       │                       │
         │                       │                       │ Play TTS              │
         │                       │                       │ Next instruction      │
         │                       │                       │                       │
```

---

### 5.3 Flow 3: Off-Route Detection and Re-Route

```
Current position (from VIO) does not lie on route segment
AND distance to nearest route segment > OFF_ROUTE_THRESHOLD (5 m)

  → Find nearest node to current position (from map)
  → Re-run A* from that node to target
  → Replace route with new path
  → Play "Recalculating route. Turn around and proceed to {nearest_landmark}"
```

---

## 6. Technology Stack & Interfaces

### 6.1 Mobile Stack

| Layer | Technology | Version / Notes |
|-------|------------|-----------------|
| Framework | Flutter | 3.x |
| Language | Dart | 3.x |
| QR Scanner | `mobile_scanner` | Existing |
| STT | `speech_to_text` | Existing |
| TTS | `flutter_tts` | Existing |
| AR (Android) | ARCore | Via `arcore_flutter_plugin` or platform channel |
| AR (iOS) | ARKit | Via `ar_flutter_plugin` or platform channel |
| Pedometer | `pedometer` or `sensors_plus` | Platform-specific |
| HTTP | `http` or `dio` | For Scene CNN API |
| Map Cache | `shared_preferences` or local DB | For offline |

### 6.2 Cloud Stack

| Service | Technology | Purpose |
|---------|------------|---------|
| Scene CNN API | Cloud Run / Firebase Functions | REST /classify |
| Map Store | Firestore | maps/{building_id} |
| STT (optional) | Deepgram API | Better transcription |
| Push | FCM | Alerts, map updates |
| Analytics | Firebase Analytics | Usage tracking |

### 6.3 ML Stack

| Component | Technology | Notes |
|-----------|------------|-------|
| Scene CNN | TensorFlow / Keras | MobileNetV2 or EfficientNet-Lite0 |
| Training | Python 3.10+ | GPU optional |
| Deployment | TFLite (optional on-device) or Cloud Run | Cloud preferred for v1 |
| YOLO | Ultralytics (existing) | 16-class object detection; not used for location |

---

## 7. Enhancement Specifications

### 7.1 Start Location (Critical)

| Current | Enhancement |
|---------|-------------|
| `const String startId = 'main_entrance'` | Dynamic start from QR payload or Scene CNN |
| Single assumption | Support QR with `start_node_id`, CNN fallback, default fallback |

**File:** `flutter_app/lib/Screens/qr_scanner_screen.dart` (line 149)

---

### 7.2 QR Payload Enhancement

**Option:** Extend QR payload to include start node when placed at a waypoint.

```json
{
  "map_url": "https://...",
  "start_node_id": "junction_1"
}
```

If `start_node_id` present → use it. Else → Scene CNN or default.

---

### 7.3 Scene Classification CNN

| Spec | Value |
|------|-------|
| Input | 224×224 or 128×128 RGB |
| Output | Softmax over map node IDs |
| Training data | 50–100 images per room/zone |
| Accuracy target | ≥ 70% (v1), ≥ 85% (production) |
| Deployment | Cloud Run (v1), optional TFLite (offline) |

---

### 7.4 VIO Integration

| Platform | Plugin / Approach |
|----------|-------------------|
| Android | ARCore Flutter plugin or MethodChannel to native Kotlin |
| iOS | ARKit Flutter plugin or MethodChannel to native Swift |
| Output | pose (position + quaternion) at 30–60 Hz |

**Constraint:** ARCore requires Android 7.0+ and ARCore-supported devices. ARKit requires iOS 11+ with A9+ chip.

---

### 7.5 Pedometer Fallback

| Spec | Value |
|------|-------|
| Step length | 0.7 m (configurable) |
| Trigger | When VIO state != TRACKING |
| Direction | Assume user faces route direction (limitation) |

---

### 7.6 Off-Route and Re-Route

| Spec | Value |
|------|-------|
| Off-route threshold | 5.0 m from route segment |
| Re-route | A* from nearest node to target |
| User feedback | "Recalculating route" + new instruction |

---

## 8. Implementation Notes & Constraints

### 8.1 Device Compatibility

| Requirement | Android | iOS |
|-------------|---------|-----|
| ARCore/ARKit | ARCore-supported device | iPhone 6S+ (ARKit) |
| Camera | Required | Required |
| IMU | Required | Required |
| Pedometer | API 19+ | iOS 8+ |

**Fallback path:** If ARCore/ARKit unavailable → pedometer-only or CNN-only at waypoints.

---

### 8.2 Coordinate Alignment

- Map coordinates: (x, y) in meters, origin at `main_entrance` (0, 0).
- VIO origin: Set at QR scan location (or Scene CNN–confirmed node).
- Alignment: Map frame = world frame. VIO pose is transformed into map frame at initialization.

---

### 8.3 Offline vs Online

| Mode | Map | Scene CNN | STT |
|------|-----|-----------|-----|
| Online | Fetch or cache | Cloud API | Cloud (e.g. Deepgram) |
| Offline | Cached from QR | TFLite (if deployed) | On-device (limited) |

**Recommendation (v1):** Online-first. Offline = cached map + static instructions (current behavior).

---

### 8.4 Latency Budget

| Operation | Target |
|-----------|--------|
| VIO pose update | < 50 ms |
| Scene CNN API | < 200 ms |
| TTS playback | Immediate after decision |
| Control loop | 100 ms |

---

## 9. Phasing & Milestones

### Phase 1: Foundation (Weeks 1–4)

| Week | Deliverable |
|------|-------------|
| 1 | ARCore/ARKit integration in Flutter (platform channels) |
| 2 | Basic pose display (x, y, z) in debug UI |
| 3 | Map coordinate alignment with VIO origin |
| 4 | Route overlay on AR view (debug) |

### Phase 2: Navigation Logic (Weeks 5–8)

| Week | Deliverable |
|------|-------------|
| 5 | Waypoint proximity detection from VIO |
| 6 | Instruction flow using position + route |
| 7 | Pedometer fallback implementation |
| 8 | Off-route detection + re-route |

### Phase 3: Scene CNN + Cloud (Weeks 9–12)

| Week | Deliverable |
|------|-------------|
| 9 | Scene CNN training pipeline + model |
| 10 | Cloud Run API for /classify |
| 11 | Waypoint confirmation flow (capture → API → confirm) |
| 12 | Drift correction on confirmation |

### Phase 4: Polish (Weeks 13–16)

| Week | Deliverable |
|------|-------------|
| 13 | End-to-end testing |
| 14 | Edge cases (no AR, poor light, wrong floor) |
| 15 | UX (haptics, better audio cues) |
| 16 | Documentation & deployment |

---

## Appendix A: File Reference

| File | Purpose |
|------|---------|
| `flutter_app/lib/Screens/qr_scanner_screen.dart` | QR scan, STT, pathfinding trigger; **line 149: startId** |
| `flutter_app/lib/Screens/astar_pathfinding.dart` | A* algorithm, graph parsing |
| `flutter_app/lib/Screens/stored_data_screen.dart` | Navigation + TTS playback |
| `data/maps/ATL_JSON.json` | Sample building map |
| `models/yolo/` | YOLO object detection (16 classes); not used for location |
| `models/training/` | UTD: scene CNN training scripts |
| `models/tflite/` | UTD: scene classification TFLite models |

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| VIO | Visual-Inertial Odometry; camera + IMU pose estimation |
| ARCore | Google's AR platform for Android |
| ARKit | Apple's AR platform for iOS |
| Scene CNN | Convolutional neural network for room/location classification |
| Waypoint | A map node (e.g. junction_1, seminar_hall) |
| Drift | Accumulated error in VIO position over time |
| Origin reset | Setting VIO origin to a confirmed waypoint to correct drift |

---

*End of document*

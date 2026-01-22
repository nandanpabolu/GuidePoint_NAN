# GuidePoint_NAN

**AI-Powered Indoor Navigation for the Visually Impaired**

A collaborative project between **B.V. Raju Institute of Technology (BVRIT), India** and **The University of Texas at Dallas (UTD), USA**

---

## Problem Statement

Visually impaired individuals face significant challenges navigating indoor spaces due to the lack of reliable, real-time localization systems. Unlike outdoor environments that rely on GPS, indoor areas like hospitals, college campuses, malls, and offices lack structured, accessible guidance infrastructure.

---

## Project Overview

GuidePoint is an assistive technology solution that enables visually impaired users to navigate indoor environments using AI-based localization and voice guidance. The system uses smartphone cameras and sensors to determine the user's location and provide turn-by-turn navigation instructions.

### Key Features

- **AI-Based Indoor Localization** - Uses camera + IMU sensors to track position without GPS
- **Visual Positioning System (VPS)** - Leverages SLAM for live indoor tracking
- **Voice-Based Navigation** - Natural language step-by-step guidance
- **Pathfinding** - A* algorithm for optimal route calculation
- **Offline Functionality** - Works without internet after map download

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mobile Application                        │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   CameraX/      │   IMU Sensors   │   Voice I/O                 │
│   OpenCV        │   (Accel/Gyro)  │   (Speech Recognition/TTS)  │
└────────┬────────┴────────┬────────┴──────────────┬──────────────┘
         │                 │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AI Engine                                │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   CNN Model     │   A* Navigation │   Navigation Engine         │
│   (TFLite)      │   Algorithm     │   (Turn-by-turn)            │
└────────┬────────┴─────────────────┴─────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Cloud Services                              │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Firebase      │   Trained       │   Building Maps             │
│   Storage       │   AI Models     │   (JSON)                    │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

---

## Workflow

1. **App Launches** - Activates camera, sensors, and voice input
2. **Environment Capture** - User points camera around the area
3. **AI Location Detection** - CNN model predicts current location
4. **Voice Input** - User speaks destination (e.g., "Take me to Seminar Hall")
5. **Pathfinding** - A* algorithm calculates optimal route
6. **Real-Time Navigation** - IMU sensors track movement with periodic camera validation
7. **Dynamic Recalculation** - Re-routes if user deviates from path
8. **Arrival Confirmation** - Voice announcement when destination is reached

---

## Tech Stack

| Component | Technology | Team |
|-----------|------------|------|
| App Development | Android Studio (Java) | BVRIT |
| Camera Integration | CameraX / OpenCV | BVRIT |
| Sensor Access | Android SensorManager | BVRIT |
| Voice Input | Google SpeechRecognizer API | BVRIT |
| Voice Output | Google Text-to-Speech API | BVRIT |
| AI Model | TensorFlow / TensorFlow Lite (CNN) | UTD |
| Navigation Algorithm | A* Pathfinding | UTD |
| Map Format | JSON | Joint |
| Cloud Storage | Firebase / Google Cloud | UTD |

---

## UTD Responsibilities

- Develop CNN model to classify rooms/zones from camera input
- Train model using labeled indoor environment images
- Convert model to TensorFlow Lite (`.tflite`) for Android compatibility
- Provide on-device inference support for real-time scene recognition
- Implement A* algorithm for indoor navigation
- Develop navigation engine for turn-by-turn instructions
- Host trained AI models on Firebase/cloud

---

## BVRIT Responsibilities

- Develop GuidePoint Android app using Android Studio (Java)
- Integrate CameraX/OpenCV for video frame capture
- Integrate phone sensors (accelerometer, gyroscope, magnetometer)
- Implement voice input/output using Speech Recognition and TTS APIs
- Load and manage JSON-based indoor maps
- Combine sensor tracking with AI predictions for real-time updates

---

## Project Structure

```
GuidePoint_NAN/
├── README.md
├── docs/                    # Documentation and design specs
├── models/                  # Trained AI models and training scripts
│   ├── training/           # Model training code
│   └── tflite/             # Converted TFLite models
├── navigation/              # A* algorithm and navigation engine
├── data/                    # Training datasets and map files
│   ├── images/             # Labeled indoor images
│   └── maps/               # JSON map files
└── tests/                   # Unit and integration tests
```

---

## Getting Started

### Prerequisites

- Python 3.8+
- TensorFlow 2.x
- Android Studio (for app integration)

### Installation

```bash
# Clone the repository
git clone https://github.com/nandanpabolu/GuidePoint_NAN.git
cd GuidePoint_NAN

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

---

## Current Status

| Phase | Status |
|-------|--------|
| Research & Planning | 🔄 In Progress |
| CNN Model Development | ⏳ Pending |
| A* Algorithm Implementation | ⏳ Pending |
| Navigation Engine | ⏳ Pending |
| Integration Testing | ⏳ Pending |

---

## Semester Goals (UTD)

1. Research machine learning models and algorithms for image processing
2. Develop detailed design plan
3. Begin CNN model architecture development
4. Implement and test A* pathfinding algorithm

---

## Community Partner

**B.V. Raju Institute of Technology (BVRIT)** - Providing infrastructure, testing environments (Assistive Tech Lab), and mentoring support throughout the project lifecycle.

---

## Contributors

- **UTD Team** - AI/ML Development & Navigation Algorithms
- **BVRIT Team** - Android App Development & Sensor Integration

---

## License

This project is developed as part of the UTDesign EPICS program.

---

## Contact

For questions or collaboration inquiries, please open an issue in this repository.


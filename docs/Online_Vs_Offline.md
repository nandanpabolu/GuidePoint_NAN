# GuidePoint: Online vs Offline Architecture Decision

**Document Version:** 1.0  
**Last Updated:** January 27, 2025  
**Related:** [ARCHITECTURE_SENSOR_FUSION.md](ARCHITECTURE_SENSOR_FUSION.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Component-by-Component Comparison](#2-component-by-component-comparison)
3. [Reasons to Choose Online](#3-reasons-to-choose-online)
4. [Reasons to Choose Offline](#4-reasons-to-choose-offline)
5. [Performance Comparison: Scene CNN](#5-performance-comparison-scene-cnn)
6. [Maps: Fetch vs Offline](#6-maps-fetch-vs-offline)
7. [Hybrid Approach](#7-hybrid-approach)
8. [Recommendation Summary](#8-recommendation-summary)

---

## 1. Overview

GuidePoint's sensor fusion architecture can operate in fully **online**, fully **offline**, or **hybrid** mode. This document compiles the tradeoffs for each approach across maps, Scene CNN, STT, and related components.

| Mode | Maps | Scene CNN | STT | FCM Alerts |
|------|------|-----------|-----|------------|
| **Online** | Fetch from URL / Firestore | Cloud API | Cloud (e.g. Deepgram) | Yes |
| **Offline** | Inline in QR or cached | TFLite on-device | On-device `speech_to_text` | No |
| **Hybrid** | Cached + optional fetch | TFLite or Cloud | On-device or Cloud | Optional |

---

## 2. Component-by-Component Comparison

### 2.1 Maps

| Factor | Online (Fetch) | Offline (Inline / Cached) |
|--------|----------------|---------------------------|
| **Connectivity** | Requires internet at load time | No network required |
| **Indoor reliability** | Can fail in poor signal areas (basements, thick walls) | Always usable |
| **Map updates** | Instant—deploy new map to server, all users get it | Requires app update or re-scan QR |
| **Initial load** | One-time HTTP fetch per map | Instant (inline) or cached |
| **Storage** | QR encodes URL; map cached after fetch | All maps stored locally or in QR |
| **User workflow** | Scan QR → fetch → navigate | Scan QR (inline) → navigate, or use cached map |
| **Multi-building** | Central source; easy to add buildings | Must distribute QR or bundle maps |
| **Typical size** | ~2–10 KB per building (JSON) | Same; storage rarely an issue |

### 2.2 Scene Classification CNN

| Factor | Online (Cloud API) | Offline (TFLite) |
|--------|--------------------|------------------|
| **Latency** | 100–500 ms (network + inference) | 10–50 ms (inference only) |
| **Offline** | No—requires connectivity | Yes |
| **Model updates** | Deploy to cloud; no app release | Requires app update or OTA model download |
| **Model size** | No client impact | 2–10 MB in app bundle |
| **Accuracy** | Can use larger models (EfficientNet, ResNet) | Often smaller models (MobileNet) for speed |
| **Device support** | Works on low-end phones | May be slow on weak devices |
| **Cold start** | Possible Cloud Run cold start (~1–2 s) | Model loads once at app start |

### 2.3 Speech-to-Text (STT)

| Factor | Online (Deepgram, etc.) | Offline (On-device) |
|--------|-------------------------|---------------------|
| **Accuracy** | Generally better, especially for accents | Limited; varies by device |
| **Language support** | Many languages, easy to add | Depends on device |
| **Latency** | 200–500 ms (network) | 100–300 ms |
| **Offline** | No | Yes |
| **Cost** | Per-minute API cost | Free |
| **Current app** | Not used yet | `speech_to_text` package (already integrated) |

### 2.4 Push Notifications / Alerts (FCM)

| Factor | Online | Offline |
|--------|--------|---------|
| **Alerts** | Yes—map updates, hazards, building closures | No—no push without network |
| **Dependency** | Requires Firebase + network | N/A |

---

## 3. Reasons to Choose Online

### 3.1 Faster Model Updates

- Train a new Scene CNN → deploy to Cloud Run → all users get it immediately.
- No app store approval, no waiting for users to update the app.
- Fix accuracy bugs or add new buildings within hours, not weeks.

### 3.2 Easier Development and Experimentation

- No TFLite export pipeline or Flutter integration.
- No need to test model performance across different devices (CPU, GPU, memory).
- Swap model architectures or input sizes without touching the app.
- Backend changes are decoupled from app release cycles.

### 3.3 Larger, More Accurate Models

- Cloud can run heavier models (EfficientNet, ResNet) without phone constraints.
- More parameters → higher capacity → better scene classification accuracy.
- Phones may struggle with large models or require aggressive quantization that hurts accuracy.

### 3.4 Centralized Analytics and Monitoring

- Log which locations are confused or misclassified.
- Monitor failure rates in real time.
- Use logs to improve training data and retrain.
- A/B test different model versions.

### 3.5 Simpler Client Code

- No model versioning or cache invalidation in the app.
- No tradeoffs for model size vs. accuracy in the app bundle.
- No handling of model download, update, or corruption recovery.

### 3.6 Works on Low-End Devices

- Heavy inference runs on the server.
- Weaker or older phones don't need to run the CNN locally.
- More consistent experience across device tiers.

### 3.7 Scalability Across Buildings

- One API serves many buildings.
- Add new buildings by training and deploying—no app changes.
- Suited for universities, hospitals, malls with many locations.

### 3.8 Future Extensibility

- Add object detection, semantic segmentation, or other processing without app changes.
- Integrate with building management (access control, IoT sensors).
- Push alerts, real-time updates, remote configuration.
- Easier to add backend-driven features over time.

---

## 4. Reasons to Choose Offline

### 4.1 Indoor Connectivity Is Unreliable

- WiFi and cellular are often weak or absent indoors (basements, thick walls, crowded areas).
- Users should not depend on network availability for core navigation.

### 4.2 Accessibility and Reliability

- Visually impaired users need predictable, dependable behavior.
- "No signal" or "Failed to load" is unacceptable for a core assistive feature.
- Offline removes connectivity as a single point of failure.

### 4.3 Lower Latency for Scene CNN

- On-device TFLite: ~10–50 ms end-to-end.
- Cloud: ~100–500 ms (upload + inference + response).
- Faster feedback improves waypoint confirmation and user confidence.

### 4.4 No Recurring Cloud Cost

- Cloud Run, Firebase, and STT APIs have usage-based costs.
- On-device inference and STT are free after development.

### 4.5 Privacy

- No need to send images or location data to a server.
- All processing stays on the device.

### 4.6 Maps Are Small

- Building maps are typically 2–10 KB (JSON).
- QR codes can encode map data inline, or store dozens of maps locally without issue.

### 4.7 No Backend to Maintain

- No API hosting, scaling, monitoring, or security hardening.
- Lower operational burden for a small team.

### 4.8 Works in Airplane Mode / Restricted Networks

- Some venues restrict or block external internet.
- Offline works regardless of network policy.

---

## 5. Performance Comparison: Scene CNN

| Scenario | On-Device (TFLite) | Cloud (Firebase / Cloud Run) |
|----------|--------------------|------------------------------|
| **Typical (WiFi)** | 20–40 ms | 150–400 ms |
| **Poor signal** | 20–40 ms | 500+ ms or timeout |
| **Best case** | 20–40 ms | ~100 ms (fast WiFi, warm instance) |

**Verdict:** On-device is consistently faster. Cloud latency is dominated by network round-trip, not inference time.

---

## 6. Maps: Fetch vs Offline

| Factor | Fetch (Online) | Offline (Inline / Cached) |
|--------|----------------|---------------------------|
| **Indoor reliability** | Can fail | Always works |
| **Updates** | Instant from server | Needs app update or new QR |
| **Workflow** | Scan QR → fetch → navigate | Scan QR → navigate (or use cached) |
| **Multi-building** | Easy to add via central store | Must distribute QR or bundle |

**Recommendation for GuidePoint:** Offline-first for maps—inline JSON in QR or cached after first fetch. Indoor connectivity is too unreliable to depend on for core navigation.

---

## 7. Hybrid Approach

A hybrid design combines the strengths of both:

| Component | Primary | Fallback |
|-----------|---------|----------|
| **Maps** | Inline in QR (offline) | Fetch from URL when online, then cache |
| **Scene CNN** | TFLite on-device (offline) | Cloud API when online and TFLite fails |
| **STT** | On-device (offline) | Cloud STT when online for better accuracy |
| **FCM** | Optional; only when online | N/A |

**Benefits:**

- Core navigation works offline.
- Online features improve experience when connectivity is available.
- Gradual migration: start offline, add online enhancements later.

---

## 8. Recommendation Summary

| Priority | Recommendation | Rationale |
|----------|----------------|-----------|
| **Maps** | Offline-first (inline QR or cached) | Indoor connectivity is unreliable; maps are small |
| **Scene CNN** | Prefer TFLite on-device | Lower latency, works offline, better for accessibility |
| **STT** | On-device (already integrated) | Works offline; consider cloud only if accuracy is insufficient |
| **Overall** | Offline-first, online optional | Core navigation must work without network |

**When to add online components:**

- Use Cloud Scene CNN for rapid prototyping or if on-device accuracy is inadequate.
- Use map fetch + cache if many buildings and centralized updates are important.
- Use Cloud STT only if on-device accuracy is not acceptable.

---

*End of document*

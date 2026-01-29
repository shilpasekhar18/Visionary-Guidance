# Visionary Guidance for Blind

Visionary Guidance for Blind is an AI-powered smart glasses system designed to assist visually impaired individuals in safe navigation and object awareness. The system uses real-time computer vision, audio feedback, and a mobile application to improve independence and safety.

---

## 🧠 Project Overview

The project integrates **hardware, AI processing, and mobile application control** to provide real-time obstacle detection and navigation assistance. An ESP32-CAM captures images of the surroundings, a Raspberry Pi processes them using YOLOv8, and a Flutter mobile app delivers audio guidance and emergency features.

---

## 🏗️ System Architecture

The system consists of three main layers:

### 1. Hardware Layer
- ESP32-CAM mounted on smart glasses
- Captures real-time images
- Streams images wirelessly over Wi-Fi using HTTP

### 2. AI Processing Layer
- Raspberry Pi 5 as the central processing unit
- YOLOv8 object detection using OpenCV
- Detects obstacles such as people, chairs, and vehicles
- Applies collision-avoidance logic to generate navigation commands

### 3. Application Control Layer
- Flutter mobile application
- WebSocket-based real-time communication
- Audio-based UI for visually impaired users
- Firebase backend for authentication and data storage

---

## 📱 Mobile Application Features

- Accessibility-focused UI with large buttons
- Single tap announces button name via audio
- Long press executes command with voice confirmation
- Voice-based destination input
- Real-time navigation assistance
- Emergency alert and live location sharing
- Bluetooth audio output to smart glasses

---

## 🔊 Audio Feedback

- Object detection alerts are converted to speech in real time
- Navigation instructions are delivered as step-by-step audio guidance
- Designed for hands-free and non-visual interaction

---

## 🚨 Emergency Module

- Allows the user to trigger an emergency alert
- Shares live location with registered emergency contacts
- Emergency contacts can view recent and current locations

---

## 🛠️ Technologies Used

### Programming Languages
- **Python** – AI processing, YOLOv8 inference, WebSocket server
- **Dart** – Flutter mobile application
- **Embedded C/C++** – ESP32-CAM firmware

### Frameworks & Tools
- YOLOv8
- OpenCV
- Flutter
- Firebase
- WebSockets
- Raspberry Pi OS
- ESP32 SDK

---

## ⚙️ Hardware Components

- ESP32-CAM
- Raspberry Pi 5
- Bluetooth-enabled smart glasses
- Battery module

---

## 📊 Results

- Real-time obstacle detection with acceptable accuracy
- Low-latency audio feedback
- Safe navigation in indoor and outdoor environments
- Successful integration of hardware, AI, and mobile application

---

## ⚠️ Limitations

- Reduced performance in low-light conditions
- Battery life constraints
- Environmental noise can affect voice interaction
- Hardware cost limited further enhancements

---

## 🚀 Future Scope

- Traffic light and crosswalk detection
- Face recognition for familiar people
- Multilingual voice support
- Improved low-light performance using IR cameras
- Hardware miniaturization and power optimization

---

## 👥 Team Contribution

This was a group project.  
My primary contribution was **mobile application development**, including:
- Flutter UI design with accessibility features
- WebSocket communication with Raspberry Pi
- Firebase authentication and emergency module
- Text-to-speech and navigation-related features

---

## 💰 Note on Project Extension

The project cost approximately **₹20,000**, which limited further enhancements during the development phase. However, the system is modular and can be extended in the future with additional funding.

---

## 📌 Conclusion

Visionary Guidance for Blind demonstrates the practical application of AI, embedded systems, real-time communication, and accessibility-focused mobile development to solve a real-world problem with social impact.

# FAST Hostel Management System

A comprehensive **Smart Hostel Management System** built for FAST-NUCES (CFD Campus) university students and administrators. It digitizes and streamlines all hostel-related operations through a modern Flutter web/mobile frontend and a Python FastAPI backend.

---

## Features

### Student Portal
- **Hostel Allotment** — Apply for a hostel room; track application status in real time
- **Mess Attendance** — Mark daily meal attendance; view monthly meal history
- **Gym Registration** — Register for the hostel gym; manage membership status
- **Complaint System** — Submit maintenance/facility complaints; track resolution progress
- **Profile Management** — View and update personal information

### Admin Portal
- **Dashboard** — Overview of occupancy, pending requests, and complaints
- **Student Management** — Approve/reject hostel applications; assign rooms
- **Mess Management** — Monitor attendance records; generate reports
- **Complaint Handling** — Assign, update, and resolve student complaints
- **Announcements** — Broadcast notices to all hostel residents

### Platform Support
- **Flutter Web** (primary deployment target)
- **Android / iOS** mobile apps

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| State Management | Riverpod |
| Routing | GoRouter |
| Backend | Python — FastAPI |
| Database / Auth | Firebase (Firestore, Firebase Auth) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| App Security | Firebase App Check |

---

## Project Structure

```
FastHostel-main/
├── frontend/               # Flutter application
│   ├── lib/
│   │   ├── config/         # Theme, router, environment config
│   │   ├── models/         # Data models
│   │   ├── providers/      # Riverpod providers
│   │   ├── screens/        # UI screens (auth, dashboard, features)
│   │   ├── services/       # Firebase, notification, admin services
│   │   └── widgets/        # Reusable UI components
│   ├── assets/             # Images, icons
│   ├── web/                # Web-specific config (index.html, manifest)
│   └── pubspec.yaml
├── backend/                # FastAPI Python backend
│   ├── main.py
│   ├── routers/
│   └── requirements.txt
├── start.bat               # Quick-start script (Windows)
└── README.md
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.10
- [Dart SDK](https://dart.dev/get-dart) (bundled with Flutter)
- [Node.js](https://nodejs.org/) ≥ 18 (for the static web server)
- [Python](https://www.python.org/) ≥ 3.10 (for the backend)
- A configured **Firebase project** with Firestore, Authentication, FCM, and App Check enabled

### 1. Clone the repository

```bash
git clone https://github.com/AbdulHanan164/FAST-Hostel-Management-System.git
cd FAST-Hostel-Management-System
```

### 2. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Firestore**, **Authentication** (Email/Password), **FCM**, and **App Check**
3. Run `flutterfire configure` inside the `frontend/` directory to generate `lib/firebase_options.dart`
4. For Android: download `google-services.json` → place in `frontend/android/app/`
5. For iOS: download `GoogleService-Info.plist` → place in `frontend/ios/Runner/`

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d chrome          # Web (development)
flutter run                    # Mobile (connected device/emulator)
```

#### Build for Web (production)

```bash
flutter build web --release --base-href /
node serve_flutter.js          # Serves on http://localhost:3000
```

### 4. Backend Setup

```bash
cd backend
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

pip install -r requirements.txt
uvicorn main:app --reload      # Starts on http://localhost:8000
```

### 5. Quick Start (Windows)

Double-click **`start.bat`** to launch both the frontend server and the backend simultaneously.

---

## Environment Variables

Create a `.env` file in `frontend/` (never commit this):

```
# Example — replace with real values
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m "Add your feature"`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

This project is developed for academic purposes at **FAST-NUCES, CFD Campus**.

---

*Built with Flutter & Firebase*

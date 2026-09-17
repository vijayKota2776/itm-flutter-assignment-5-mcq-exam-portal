# ITM Skills University - MCQ Examination Portal

A complete, production-quality, full-stack MCQ Examination Platform built for **ITM Skills University**.

Features a **Flutter** client (Web/Desktop/Mobile), a **Node.js + Express** REST API, **Firebase Authentication & Cloud Firestore**, **Cloudinary** cloud storage, Excel/CSV question parsing, server-side grading with negative marking, synchronized countdown timers, answer autosave, result PDF generation, and administrative analytics.

---

## 🏛️ System Overview

The portal supports two primary roles:
1. **ADMINISTRATOR**:
   - Creates and manages examinations with detailed rules (duration, negative marking, passing marks).
   - Uploads question sheets via Excel (`.xlsx`) or CSV (`.csv`).
   - Previews parsed questions and detects row-level spreadsheet errors.
   - Publishes, unpublishes, and deletes exams (with automatic Cloudinary asset cleanup).
   - Views registered student rosters and attempt counts.
   - Accesses real-time analytics reports (score distribution charts, pass/fail rates, student leaderboards).
   - Exports reports to Excel, CSV, or PDF, uploaded directly to Cloudinary.

2. **STUDENT**:
   - Secure registration, login, and password recovery via Firebase Auth.
   - Dynamic dashboard organizing tests into **Active**, **Upcoming**, and **Completed**.
   - Dedicated high-focus examination interface with:
     - Real-time countdown timer synchronized with server expiration.
     - Color-coded question palette (**Green** = Answered, **Red** = Visited/Unanswered, **Purple** = Marked for Review, **Gray** = Not Visited).
     - Continuous background answer autosave.
     - Auto-submission upon time expiration.
   - Instant server-side evaluation:
     - Score calculation with negative marking deductions.
     - Academic letter grade assignment (O, A+, A, B+, B, C, F).
     - Question-by-question review with correct vs student answer comparisons.
     - One-click official PDF scorecard download.
   - Historical attempt logs.

---

## 🔒 Security Architecture

- **Answer Shielding**: The backend **never** transmits correct answers to the client during an active test attempt (`/api/student/exam/:id/start` strips `correctAnswer`).
- **Server-Side Grading**: Final grading is computed exclusively on the backend (`/api/student/exam/:id/submit`).
- **Server-Side Expiration**: Attempt start and expiration timestamps are enforced by the server; clients cannot manipulate test timers.
- **Role Verification**: Roles are authenticated directly from the user document in Firestore and never trusted from client payloads.
- **Secret Isolation**: Cloudinary API secret and Firebase Admin private keys are contained in `backend/.env` and never bundled into the Flutter application.

---

## 📁 Repository Structure

```
Assignment-5/
├── backend/
│   ├── src/
│   │   ├── config/
│   │   │   ├── firebase.js          # Firebase Admin & in-memory dev fallback
│   │   │   └── cloudinary.js        # Cloudinary SDK client
│   │   ├── controllers/
│   │   │   ├── adminController.js   # Excel upload, exam CRUD, reports
│   │   │   ├── authController.js    # User sync & profile
│   │   │   └── studentController.js # Exam attempts, autosave, grading
│   │   ├── middleware/
│   │   │   ├── auth.js              # Token validation & user lookup
│   │   │   ├── errorHandler.js      # Centralized error handler
│   │   │   ├── roles.js             # Role enforcement (requireAdmin, requireStudent)
│   │   │   └── upload.js            # Multer memory upload (15MB limit)
│   │   ├── routes/
│   │   │   ├── adminRoutes.js
│   │   │   ├── authRoutes.js
│   │   │   └── studentRoutes.js
│   │   ├── services/
│   │   │   ├── cloudinaryService.js # Asset upload and deletion lifecycle
│   │   │   ├── excelService.js      # XLSX/CSV parsing and row validation
│   │   │   ├── gradingService.js    # Score, negative marking, and grade engine
│   │   │   └── pdfService.js        # PDFKit result & report generation
│   │   ├── scripts/
│   │   │   ├── generateSampleExcel.js # Generates test .xlsx and .csv files
│   │   │   └── seedAdmin.js         # Safe CLI administrator seeding
│   │   └── server.js                # Express app with Helmet, CORS, rate limits
│   ├── test/
│   │   └── backend.test.js          # Automated backend integration tests
│   ├── .env.example
│   ├── .gitignore
│   ├── firestore.rules              # Production Firestore security rules
│   └── package.json
│
├── frontend/
│   ├── lib/
│   │   ├── models/                  # UserModel, ExamModel, QuestionModel, ResultModel, ReportModel
│   │   ├── providers/               # AuthProvider, AdminProvider, ExamProvider, AttemptProvider
│   │   ├── screens/
│   │   │   ├── admin/               # AdminDashboard, CreateExam, AdminExams, AdminReports, AdminStudents
│   │   │   ├── auth/                # LoginScreen, RegisterScreen, ForgotPasswordScreen
│   │   │   └── student/             # StudentDashboard, ExamInterface, ExamResult, StudentHistory, StudentProfile
│   │   ├── services/                # ApiService, AuthService, PdfService
│   │   ├── theme/                   # AppTheme (ITM Navy #0F172A, Royal Blue #1E40AF)
│   │   ├── utils/                   # AppConfig
│   │   ├── widgets/                 # TimerWidget, QuestionPalette, StatCard, StatusBadge
│   │   └── main.dart                # AuthGate & entrypoint
│   └── pubspec.yaml
│
├── docs/
│   └── API.md                       # Comprehensive REST API reference
├── sample_exam_questions.xlsx       # Sample question spreadsheet (10 questions)
├── sample_exam_questions.csv        # Sample question CSV
└── README.md
```

---

## ⚙️ Prerequisites

- **Node.js**: v18 or later (tested on v24)
- **npm**: v9 or later
- **Flutter SDK**: v3.24 or later (tested on 3.44.9 / Dart 3.12.2)

---

## 🚀 Getting Started

### 1. Backend Setup

```bash
cd backend
npm install
```

Configure `backend/.env` (a template is provided in `backend/.env.example`):
```ini
PORT=5000
NODE_ENV=development

# Firebase Project
FIREBASE_PROJECT_ID=mcq-exam-b768d
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

# Cloudinary Credentials
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=BdxDSmafLr9KUzOdL8-unBYhRhk
CLOUDINARY_API_SECRET=

# JWT Secret
JWT_SECRET=itm_skills_university_super_secure_jwt_secret_2026_mcq_portal

# Default Admin
DEFAULT_ADMIN_EMAIL=admin@itm.edu
DEFAULT_ADMIN_PASSWORD=AdminPass@2026
```

> **Note on Resilient Development Mode**: The backend automatically falls back to an in-memory Firestore adapter and simulated Cloudinary storage if external cloud credentials are not yet configured. This ensures all tests and local development runs work immediately out of the box.

Run backend tests:
```bash
npm test
```

Seed initial administrator:
```bash
npm run seed:admin
```

Start backend development server:
```bash
npm run dev
# Server listening on http://localhost:5000
# Health check: http://localhost:5000/api/health
```

---

### 2. Frontend Setup

```bash
cd frontend
flutter pub get
```

Run static analysis and tests:
```bash
flutter analyze
flutter test
```

Launch the Flutter application:
```bash
# Run on Chrome / Web:
flutter run -d chrome

# Run on macOS Desktop:
flutter run -d macos

# Run on connected Mobile Emulator:
flutter run
```

---

## 📊 Spreadsheet Format for Question Upload

When uploading questions via **Create Exam**, the spreadsheet (`.xlsx` or `.csv`) must have the following header columns:

| Question No. | Question | Option A | Option B | Option C | Option D | Correct Answer |
| :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| 1 | What is the capital city of India? | Mumbai | New Delhi | Kolkata | Chennai | **B** |
| 2 | Which planet is known as the Red Planet? | Venus | Mars | Jupiter | Saturn | **B** |
| 3 | What does HTML stand for? | Hyper Text Markup Language | High Text Machine Language | Hyper Tabular Markup Language | None of these | **A** |

- **Header names** are case-insensitive and whitespace-tolerant.
- **Correct Answer** must strictly be one of: `A`, `B`, `C`, or `D`.
- Ready-to-use sample spreadsheets are included at `sample_exam_questions.xlsx` and `sample_exam_questions.csv`.

---

## 🔑 Demo Access (1-Click Login)

The login screen provides direct evaluation buttons for convenience:
- **Admin Demo**: Instantly signs in as Administrator (`admin@itm.edu`).
- **Student Demo**: Instantly signs in as Student (`student@itm.edu`).

---

## 📄 License & Attribution

Built for **ITM Skills University**. All rights reserved.

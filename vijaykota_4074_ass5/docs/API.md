# ITM Skills University - MCQ Examination Portal API Specification

Base URL: `http://localhost:5000/api`

All authenticated requests require the header:
```
Authorization: Bearer <Firebase_ID_Token_Or_JWT>
```

---

## 1. System Health

### `GET /api/health`
Returns system status, service health, and API version.
- **Auth**: None
- **Response**: `200 OK`
```json
{
  "success": true,
  "message": "ITM Skills University MCQ Examination Portal API is healthy and operational",
  "timestamp": "2026-09-15T12:00:00.000Z",
  "version": "1.0.0"
}
```

---

## 2. Authentication & Profile Routes (`/api/auth`)

### `GET /api/auth/me`
Retrieves the profile and authoritative role (`admin` or `student`) of the current authenticated user.
- **Auth**: Authenticated User (`admin` or `student`)
- **Response**: `200 OK`
```json
{
  "success": true,
  "message": "User profile retrieved successfully",
  "data": {
    "uid": "user_xyz123",
    "email": "student@itm.edu",
    "name": "Rahul Sharma",
    "role": "student",
    "photoUrl": "",
    "createdAt": "2026-09-15T10:00:00.000Z",
    "lastLogin": "2026-09-15T11:30:00.000Z"
  }
}
```

### `POST /api/auth/sync-user`
Synchronizes user record into Firestore upon sign-up or login. Role cannot be manipulated by client; authoritative role is verified against administrator privileges.
- **Auth**: Authenticated User
- **Body**:
```json
{
  "email": "student@itm.edu",
  "name": "Rahul Sharma"
}
```
- **Response**: `200 OK`

---

## 3. Administrator Routes (`/api/admin`)
*All routes in this group strictly require the `admin` role.*

### `POST /api/admin/upload-excel`
Uploads `.xlsx` or `.csv` question sheet, streams original to Cloudinary, validates headers and rows, and returns question preview with row-level validation status.
- **Auth**: Administrator
- **Content-Type**: `multipart/form-data`
- **Field**: `file` (Excel or CSV file, up to 15MB)
- **Response**: `200 OK`
```json
{
  "success": true,
  "message": "Spreadsheet processed successfully",
  "data": {
    "fileName": "sample_exam_questions.xlsx",
    "excelUrl": "https://res.cloudinary.com/.../questions.xlsx",
    "excelPublicId": "mcq-portal/excel-sheets/...",
    "isValid": true,
    "totalRows": 10,
    "validCount": 10,
    "errorCount": 0,
    "errors": [],
    "questions": [
      {
        "questionNo": 1,
        "question": "What is the capital city of India?",
        "options": {
          "A": "Mumbai",
          "B": "New Delhi",
          "C": "Kolkata",
          "D": "Chennai"
        },
        "correctAnswer": "B"
      }
    ]
  }
}
```

### `POST /api/admin/exam`
Creates examination document in Firestore and commits its questions in a batch write.
- **Auth**: Administrator
- **Body**:
```json
{
  "title": "General Knowledge Examination 2026",
  "subject": "General Studies",
  "description": "Comprehensive assessment.",
  "duration": 30,
  "totalMarks": 10.0,
  "marksPerQuestion": 1.0,
  "negativeMarking": 0.25,
  "passingMarks": 4.0,
  "instructions": "Read all questions carefully.",
  "startDate": "2026-09-15T00:00:00.000Z",
  "endDate": "2026-09-22T23:59:59.000Z",
  "excelUrl": "https://res.cloudinary.com/...",
  "excelPublicId": "mcq-portal/excel-sheets/...",
  "questions": [...]
}
```
- **Response**: `201 Created`

### `GET /api/admin/exams`
Lists all examinations with optional status and title search filters.
- **Auth**: Administrator
- **Query Params**:
  - `status` (optional): `all` | `draft` | `published`
  - `search` (optional): Search query string
- **Response**: `200 OK`

### `GET /api/admin/exam/:id`
Retrieves exam metadata and full question list including `correctAnswer` (accessible strictly to admins).
- **Auth**: Administrator
- **Response**: `200 OK`

### `PUT /api/admin/exam/:id`
Updates examination metadata or toggles status between `draft` and `published`.
- **Auth**: Administrator
- **Body**: `{ "status": "published" }`
- **Response**: `200 OK`

### `DELETE /api/admin/exam/:id`
Permanently deletes exam document, question documents, and associated Cloudinary spreadsheet file.
- **Auth**: Administrator
- **Response**: `200 OK`

### `GET /api/admin/students`
Lists all registered students, total examinations attempted, and average score.
- **Auth**: Administrator
- **Response**: `200 OK`

### `GET /api/admin/report/:examId`
Computes aggregate performance analytics: total attempts, average score, highest, lowest, pass rate, score distribution bins, and student ranking table.
- **Auth**: Administrator
- **Response**: `200 OK`

### `POST /api/admin/report/:examId/export`
Exports examination report to CSV, Excel, or PDF, uploads the file to Cloudinary, and returns the secure URL.
- **Auth**: Administrator
- **Body**: `{ "format": "csv" | "excel" | "pdf" }`
- **Response**: `200 OK`

---

## 4. Student Routes (`/api/student`)
*All routes in this group require the `student` role.*

### `GET /api/student/exams`
Lists published examinations categorized dynamically into `Active`, `Upcoming`, `Completed`, or `Expired`.
- **Auth**: Student
- **Response**: `200 OK`

### `POST /api/student/exam/:id/start`
Starts a new attempt or resumes an active attempt.
> **SECURITY GUARANTEE**: Correct answers are STRICTLY stripped from question objects in the response.
- **Auth**: Student
- **Response**: `200 OK`
```json
{
  "success": true,
  "data": {
    "attemptId": "attempt_123",
    "exam": {
      "id": "exam_abc",
      "title": "General Knowledge Examination 2026",
      "duration": 30,
      "totalMarks": 10.0,
      "marksPerQuestion": 1.0,
      "negativeMarking": 0.25
    },
    "questions": [
      {
        "id": "q1",
        "questionNo": 1,
        "question": "What is the capital city of India?",
        "options": {
          "A": "Mumbai",
          "B": "New Delhi",
          "C": "Kolkata",
          "D": "Chennai"
        }
      }
    ],
    "studentAnswers": {},
    "startedAt": "2026-09-15T12:00:00.000Z",
    "expiresAt": "2026-09-15T12:30:00.000Z",
    "remainingSeconds": 1800
  }
}
```

### `POST /api/student/exam/:id/save-answer`
Continuous autosave endpoint. Persists chosen answers as student progresses.
- **Auth**: Student
- **Body**:
```json
{
  "attemptId": "attempt_123",
  "answers": {
    "q1": "B",
    "q2": "A"
  }
}
```
- **Response**: `200 OK`

### `POST /api/student/exam/:id/submit`
Performs server-side grading, validates submission timestamp, calculates score with negative marking, generates result scorecard PDF, uploads to Cloudinary, and saves result.
- **Auth**: Student
- **Body**:
```json
{
  "attemptId": "attempt_123",
  "answers": { ... },
  "isAutoSubmit": false
}
```
- **Response**: `200 OK`
```json
{
  "success": true,
  "message": "Examination submitted and evaluated successfully",
  "data": {
    "id": "res_789",
    "attemptId": "attempt_123",
    "score": 9.75,
    "totalMarks": 10.0,
    "percentage": 97.5,
    "status": "PASS",
    "grade": "O",
    "correct": 10,
    "wrong": 0,
    "unattempted": 0,
    "resultPdfUrl": "https://res.cloudinary.com/.../result.pdf",
    "questionAnalysis": [ ... ]
  }
}
```

### `GET /api/student/result/:resultId`
Retrieves detailed result scorecard and question-wise breakdown.
- **Auth**: Student (owner) or Admin
- **Response**: `200 OK`

### `GET /api/student/history`
Returns all completed examination attempts and scores for current student.
- **Auth**: Student
- **Response**: `200 OK`

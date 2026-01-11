# AI Learning Coach - iOS App

A SwiftUI app for iPhone, iPad, and Mac that provides an AI-powered learning experience.

## Requirements

- Xcode 15.0+
- iOS 17.0+ / iPadOS 17.0+ / macOS 14.0+
- Backend server running (see `backend/` folder)

## Setup

1. Open `AILearningCoach.xcodeproj` in Xcode
2. Select your target device (iPhone, iPad, or Mac)
3. Build and run (Cmd + R)

## Features

### 📚 Flashcard Study (Anki Mode)
- SM-2 spaced repetition algorithm
- Card flipping animations
- Rating system: Again / Hard / Good / Easy
- Offline review support with local SwiftData storage
- Automatic sync and deduplication logic
- **Remediation Support**: Loads targeted cards automatically if a milestone exam is failed

### 🩺 Diagnostic Mode
- 10-question knowledge assessment
- AI-graded responses
- Detailed feedback on strengths and weaknesses

### 📝 Examiner Mode
- Milestone assessments with 80% pass threshold
- Active recall questions from previous milestones
- Progress tracking and advancement
- **Project Persistence**: Remembers your selected project and stores full milestone details locally (UserDefaults + SwiftData)
- **Reactive Sync**: Seamlessly updates all views when switching projects via `.onChange` reactive bindings

## Architecture

```
AILearningCoach/
├── Models/              # Data models (Project, Flashcard, Question)
├── Views/               # SwiftUI views
│   ├── HomeView         # Project selection
│   ├── FlashcardStudyView # Anki-style study
│   ├── DiagnosticView   # Diagnostic quiz
│   ├── ExamView         # Milestone exams
│   └── Components/      # Reusable components
├── Services/            # API communication
├── Persistence/         # SwiftData for offline storage
├── Notifications/       # Push notification handling
└── Theme/               # Design system and colors
```

## Running with Backend

1. Start the backend server:
   ```bash
   cd ../backend
   pip install -r requirements.txt
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

2. Run the iOS app in Xcode

The app connects to `localhost:8000` by default.

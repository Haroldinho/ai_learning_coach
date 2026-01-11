# AI Learning Coach - Backend API

This is the FastAPI backend that powers the iOS Learning Coach app. It orchestrates the AI Agents, manages user-specific persistence, and implements a server-side caching layer for optimized content delivery.

## Core Features

*   **Multi-Tenancy**: Uses the `X-User-ID` header to isolate data per user in `.coin_cache/{user_id}/`.
*   **Stateful Orchestration**: Manages the transition between Diagnostic, Study (Flashcards), and Examination phases.
*   **Flashcard Caching**: Transparently caches generated cards per milestone in `MemoryManager` to reduce LLM costs and ensure consistent study material.
*   **Adaptive Remediation**: Provides a dedicated endpoint for remediation materials if milestone assessments are failed.

## Setup

```bash
cd backend
pip install -r requirements.txt
```

## Running

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

*   `GET /projects`: List all projects for a user.
*   `GET /projects/{id}`: Detailed project view with full milestones.
*   `GET /projects/{id}/flashcards`: Milestone-specific flashcards (cached).
*   `GET /projects/{id}/flashcards/remediation`: Remediation cards (cached).
*   `POST /projects/{id}/exam`: Submit exam and update user profile.

See `/docs` for full interactive API documentation.

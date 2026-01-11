# AI Learning Coach - Python CLI

This is the core Python engine that powers the AI Learning Coach. It provides a command-line interface for interacting with the learning system.

## 🤖 The Agents

The system is powered by four specialized AI agents, each handling a specific phase of the learning lifecycle:

1.  **GoalAgent** (`agents/goal_agent.py`):
    *   **Role**: The Planner.
    *   **Function**: Takes your broad topic (e.g., "Quantum Physics") and converts it into a concrete, 30-day SMART learning plan.
    *   **Output**: A structured schedule with milestones and estimated timeframes.

2.  **DiagnosticAgent** (`agents/diagnostic_agent.py`):
    *   **Role**: The Assessor.
    *   **Function**: Before you start, it generates a diagnostic quiz to check your current knowledge level.
    *   **Utility**: Helps establish a baseline so you know where you stand.

3.  **OptimizerAgent** (`agents/optimizer_agent.py`):
    *   **Role**: The Content Creator.
    *   **Function**: For each milestone, it generates high-quality study materials, specifically formatted for *Spaced Repetition*.
    *   **Output**: Creates ready-to-import Anki Flashcard packages (`.apkg`).

4.  **ExaminerAgent** (`agents/examiner_agent.py`):
    *   **Role**: The Teacher.
    *   **Function**: After your study period, it creates a challenging exam for the current milestone. It grades your answers, provides feedback, and decides if you have passed or need to review.
    *   **Feature**: Includes *Active Recall* questions from previous milestones to ensure long-term retention.

## 🏗️ Module Structure

```
src/
├── main.py              # CLI entry point
├── memory.py            # State persistence (MemoryManager)
├── migration.py         # Legacy data migration utilities
├── models.py            # Pydantic data models
├── utils.py             # Shared utilities
└── agents/
    ├── goal_agent.py      # Learning plan generation
    ├── diagnostic_agent.py # Knowledge assessment
    ├── optimizer_agent.py  # Flashcard generation
    └── examiner_agent.py   # Exam creation & grading
```

## 🚀 Running the CLI

From the **project root** directory:

```bash
python src/main.py
```

Follow the on-screen prompts to enter your learning topic and interact with the coach.

## 🧠 Memory & State Management

The system uses a robust file-based persistence system to maintain state between sessions, shared between the CLI and the FastAPI backend.

*   **Location**: All state is stored in the `.coin_cache` directory (in the project root).
*   **Structure**: Supports multi-tenancy. Project data is isolated by user: `.coin_cache/{user_id}/{project_id}/`.
*   **Mechanism**: The `MemoryManager` class (`memory.py`) serializes the internal Pydantic models to JSON files.
*   **Files**:
    *   `learning_goal.json`: Stores the current active SMART goal and its milestones.
    *   `user_profile.json`: Tracks progress, completed milestones, and assessment history.
    *   `flashcards_{milestone_title}.json`: **Caching Layer**. Stores generated flashcards to avoid redundant LLM calls.
    *   `flashcards_remediation.json`: Stores remediation flashcards for target review.

This structure allows for **multiple independent learning projects** and **efficient state restoration**.

## 📦 Anki Packages

When the **OptimizerAgent** generates study materials, it saves them as Anki Package files (`.apkg`) directly in the **project root** directory.

**Naming Convention:** `deck_Milestone_Title.apkg`

**How to use:**
1.  Locate the `.apkg` file in the project folder.
2.  Double-click the file to import it into your [Anki](https://apps.ankiweb.net/) desktop application.
3.  Study the cards for the recommended duration before taking the exam.

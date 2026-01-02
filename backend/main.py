"""
AI Learning Coach - Backend API

FastAPI server that wraps the existing Python agents and provides
REST endpoints for the iOS app.
"""

import sys
import os

# Add parent directory to path so we can import from src
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import json

from src.memory import MemoryManager
from src.agents.goal_agent import GoalAgent
from src.agents.diagnostic_agent import DiagnosticAgent
from src.agents.optimizer_agent import OptimizerAgent
from src.agents.examiner_agent import ExaminerAgent
from src.models import LearningGoal, UserProfile, Flashcard, Question, AssessmentResult
from src.utils import to_snake_case

app = FastAPI(
    title="AI Learning Coach API",
    description="Backend API for the iOS Learning Coach app",
    version="1.0.0"
)

# CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize agents (singleton pattern)
goal_agent = GoalAgent()
diagnostic_agent = DiagnosticAgent()
optimizer_agent = OptimizerAgent()
examiner_agent = ExaminerAgent()

BASE_CACHE_PATH = ".coin_cache"


# ============== Dependency Injection ==============

async def get_user_id(x_user_id: Optional[str] = Header(None)) -> str:
    """
    Extracts the User ID from the X-User-ID header.
    If not present (e.g. local dev/curl), defaults to 'default_user'.
    """
    if not x_user_id:
        return "default_user"
    
    # Sanitize user_id to be safe for filesystem
    safe_id = "".join([c for c in x_user_id if c.isalnum() or c in "-_"])
    return safe_id or "default_user"


# ============== Request/Response Models ==============

class CreateProjectRequest(BaseModel):
    topic: str
    existing_plan: Optional[str] = None


class ProjectResponse(BaseModel):
    id: str
    title: str
    smart_goal: str
    total_duration_days: int
    current_milestone_index: int
    completed_milestones: List[str]


class FlashcardResponse(BaseModel):
    id: int
    front: str
    back: str
    tags: List[str]
    ease_factor: float = 2.5
    interval: int = 1
    repetitions: int = 0
    next_review_date: Optional[str] = None


class FlashcardReviewRequest(BaseModel):
    card_id: int
    quality: int  # 0-5 scale for SM-2


class QuestionResponse(BaseModel):
    id: int
    text: str
    difficulty: str
    key_concept: str


class SubmitAnswersRequest(BaseModel):
    answers: List[str]


class AssessmentResultResponse(BaseModel):
    score: float
    correct_concepts: List[str]
    missed_concepts: List[str]
    feedback: str
    excelled_at: Optional[str]
    improvement_areas: Optional[str]
    challenges: Optional[str]
    passed: bool


class SyncProgressRequest(BaseModel):
    """Sync offline flashcard progress to backend"""
    reviews: List[FlashcardReviewRequest]
    last_sync_timestamp: str


# ============== Helper Functions ==============

def get_user_cache_path(user_id: str) -> str:
    """Returns the cache directory for a specific user."""
    path = os.path.join(BASE_CACHE_PATH, user_id)
    os.makedirs(path, exist_ok=True)
    return path

def list_projects(user_id: str) -> List[tuple]:
    """Lists available project directories for a user."""
    user_path = get_user_cache_path(user_id)
    
    if not os.path.exists(user_path):
        return []
    
    projects = []
    for item in os.listdir(user_path):
        item_path = os.path.join(user_path, item)
        if os.path.isdir(item_path) and os.path.exists(os.path.join(item_path, "learning_goal.json")):
            try:
                with open(os.path.join(item_path, "learning_goal.json"), 'r') as f:
                    data = json.load(f)
                    title = data.get("smart_goal", item)
                    projects.append((item, title))
            except Exception:
                projects.append((item, item))
    return projects


def get_memory_manager(project_id: str, user_id: str) -> MemoryManager:
    """Get memory manager for a specific project and user."""
    user_path = get_user_cache_path(user_id)
    project_path = os.path.join(user_path, project_id)
    
    # We allow creating the manager even if dir doesn't exist yet (MemoryManager handles it)
    # but strictly checking existence for 'get' operations is good practice.
    # Here we let MemoryManager handle the specific project subdirectory creation.
    
    return MemoryManager(storage_dir=project_path)


# ============== Project Endpoints ==============

@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "message": "AI Learning Coach API is running"}


@app.get("/projects", response_model=List[ProjectResponse])
async def get_projects(user_id: str = Depends(get_user_id)):
    """List all learning projects for the authenticated user."""
    projects = list_projects(user_id)
    result = []
    
    for project_id, title in projects:
        memory = get_memory_manager(project_id, user_id)
        goal = memory.load_learning_goal()
        profile = memory.load_user_profile()
        
        result.append(ProjectResponse(
            id=project_id,
            title=title[:60] + "..." if len(title) > 60 else title,
            smart_goal=goal.smart_goal if goal else "",
            total_duration_days=goal.total_duration_days if goal else 0,
            current_milestone_index=profile.current_milestone_index,
            completed_milestones=profile.completed_milestones
        ))
    
    return result


@app.post("/projects", response_model=ProjectResponse)
async def create_project(request: CreateProjectRequest, user_id: str = Depends(get_user_id)):
    """Create a new learning project for the authenticated user."""
    project_id = to_snake_case(request.topic)
    if not project_id:
        import datetime
        project_id = f"project_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Ensure project path implies user path
    memory = get_memory_manager(project_id, user_id)
    
    # Create learning plan
    learning_goal = goal_agent.create_learning_plan(request.topic, existing_plan=request.existing_plan)
    memory.save_learning_goal(learning_goal)
    
    profile = memory.load_user_profile()
    
    return ProjectResponse(
        id=project_id,
        title=learning_goal.smart_goal[:60] + "..." if len(learning_goal.smart_goal) > 60 else learning_goal.smart_goal,
        smart_goal=learning_goal.smart_goal,
        total_duration_days=learning_goal.total_duration_days,
        current_milestone_index=profile.current_milestone_index,
        completed_milestones=profile.completed_milestones
    )


@app.get("/projects/{project_id}")
async def get_project(project_id: str, user_id: str = Depends(get_user_id)):
    """Get detailed project information."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="Project has no learning goal")
    
    return {
        "id": project_id,
        "learning_goal": goal.model_dump(),
        "user_profile": profile.model_dump()
    }


# ============== Flashcard Endpoints ==============

@app.get("/projects/{project_id}/flashcards", response_model=List[FlashcardResponse])
async def get_flashcards(project_id: str, user_id: str = Depends(get_user_id)):
    """Get flashcards for the current milestone."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Generate flashcards if needed
    # Note: optimizer_agent currently saves to current directory. 
    # TODO: In a real multi-user env, we should update optimizer_agent 
    # to save to the user's cache dir. For now, we assume the .apkg logic works as is
    # or simple text response is sufficient for the app.
    deck_path = optimizer_agent.generate_curriculum_and_cards(goal, profile)
    
    if deck_path == "All milestones completed!":
        return []
    
    # For now, return mock flashcards (actual cards are in .apkg file)
    # In production, we'd parse the deck or store cards in JSON
    current_milestone = goal.milestones[profile.current_milestone_index] if profile.current_milestone_index < len(goal.milestones) else None
    
    if not current_milestone:
        return []
    
    # Generate sample flashcards from concepts
    flashcards = []
    for i, concept in enumerate(current_milestone.concepts):
        flashcards.append(FlashcardResponse(
            id=i,
            front=f"What is {concept}?",
            back=f"Definition and explanation of {concept}",
            tags=[current_milestone.title, "auto-generated"],
            ease_factor=2.5,
            interval=1,
            repetitions=0
        ))
    
    return flashcards


@app.post("/projects/{project_id}/flashcards/review")
async def review_flashcard(project_id: str, review: FlashcardReviewRequest, user_id: str = Depends(get_user_id)):
    """Submit a flashcard review (SM-2 algorithm update)."""
    # This would update the spaced repetition data
    # For now, just acknowledge the review
    return {
        "status": "ok",
        "card_id": review.card_id,
        "quality": review.quality,
        "message": "Review recorded"
    }


@app.post("/projects/{project_id}/flashcards/sync")
async def sync_flashcard_progress(project_id: str, sync_request: SyncProgressRequest, user_id: str = Depends(get_user_id)):
    """Sync offline flashcard progress to backend."""
    # Process all offline reviews
    synced_count = len(sync_request.reviews)
    
    return {
        "status": "ok",
        "synced_reviews": synced_count,
        "message": f"Synced {synced_count} reviews from offline session"
    }


# ============== Diagnostic Endpoints ==============

@app.get("/projects/{project_id}/diagnostic", response_model=List[QuestionResponse])
async def get_diagnostic_quiz(project_id: str, user_id: str = Depends(get_user_id)):
    """Generate a diagnostic quiz for the project."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    questions = diagnostic_agent.generate_quiz(goal)
    
    return [
        QuestionResponse(
            id=i,
            text=q.text,
            difficulty=q.difficulty,
            key_concept=q.key_concept
        )
        for i, q in enumerate(questions)
    ]


@app.post("/projects/{project_id}/diagnostic", response_model=AssessmentResultResponse)
async def submit_diagnostic(project_id: str, submission: SubmitAnswersRequest, user_id: str = Depends(get_user_id)):
    """Submit diagnostic quiz answers and get results."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Regenerate questions to grade
    questions = diagnostic_agent.generate_quiz(goal)
    
    # Grade using examiner agent
    result = examiner_agent.evaluate_submission(questions, submission.answers)
    
    # Save to profile
    import datetime
    result.timestamp = datetime.datetime.now().isoformat()
    
    profile = memory.load_user_profile()
    profile.assessment_history.append(result)
    memory.save_user_profile(profile)
    
    return AssessmentResultResponse(
        score=result.score,
        correct_concepts=result.correct_concepts,
        missed_concepts=result.missed_concepts,
        feedback=result.feedback,
        excelled_at=result.excelled_at,
        improvement_areas=result.improvement_areas,
        challenges=result.challenges,
        passed=result.score >= 0.8
    )


# ============== Examiner Endpoints ==============

@app.get("/projects/{project_id}/exam", response_model=List[QuestionResponse])
async def get_exam(project_id: str, user_id: str = Depends(get_user_id)):
    """Generate an exam for the current milestone."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Get current milestone
    if profile.current_milestone_index >= len(goal.milestones):
        raise HTTPException(status_code=400, detail="All milestones completed")
    
    current_milestone = goal.milestones[profile.current_milestone_index]
    
    questions = examiner_agent.generate_assessment(goal, profile, current_milestone.title)
    
    return [
        QuestionResponse(
            id=i,
            text=q.text,
            difficulty=q.difficulty,
            key_concept=q.key_concept
        )
        for i, q in enumerate(questions)
    ]


@app.post("/projects/{project_id}/exam", response_model=AssessmentResultResponse)
async def submit_exam(project_id: str, submission: SubmitAnswersRequest, user_id: str = Depends(get_user_id)):
    """Submit exam answers and get results."""
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    if profile.current_milestone_index >= len(goal.milestones):
        raise HTTPException(status_code=400, detail="All milestones completed")
    
    current_milestone = goal.milestones[profile.current_milestone_index]
    
    # Regenerate questions to grade
    questions = examiner_agent.generate_assessment(goal, profile, current_milestone.title)
    
    # Grade
    result = examiner_agent.evaluate_submission(questions, submission.answers)
    
    import datetime
    result.timestamp = datetime.datetime.now().isoformat()
    
    # Update profile
    profile.assessment_history.append(result)
    passed = result.score >= 0.8
    
    if passed:
        profile.completed_milestones.append(current_milestone.title)
        profile.current_milestone_index += 1
        profile.current_deck_path = None
        profile.milestone_start_date = None
    
    memory.save_user_profile(profile)
    
    return AssessmentResultResponse(
        score=result.score,
        correct_concepts=result.correct_concepts,
        missed_concepts=result.missed_concepts,
        feedback=result.feedback,
        excelled_at=result.excelled_at,
        improvement_areas=result.improvement_areas,
        challenges=result.challenges,
        passed=passed
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

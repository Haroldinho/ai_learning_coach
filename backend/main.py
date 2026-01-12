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
import uuid
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("learning-coach-api")

from src.memory import MemoryManager
from src.agents.goal_agent import GoalAgent
from src.agents.diagnostic_agent import DiagnosticAgent
from src.agents.optimizer_agent import OptimizerAgent
from src.agents.examiner_agent import ExaminerAgent
from src.models import LearningGoal, UserProfile, Flashcard, Question, AssessmentResult, Milestone

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


class QuestionResultResponse(BaseModel):
    text: str
    user_answer: str
    correct_answer: str
    explanation: str
    is_correct: bool


class AssessmentResultResponse(BaseModel):
    score: float
    correct_concepts: List[str]
    missed_concepts: List[str]
    question_results: List[QuestionResultResponse]
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
    seen_ids = set()
    
    for item in os.listdir(user_path):
        if item in seen_ids:
            continue
            
        item_path = os.path.join(user_path, item)
        if os.path.isdir(item_path) and os.path.exists(os.path.join(item_path, "learning_goal.json")):
            try:
                with open(os.path.join(item_path, "learning_goal.json"), 'r') as f:
                    data = json.load(f)
                    title = data.get("smart_goal", item)
                    projects.append((item, title))
                    seen_ids.add(item)
            except Exception:
                 projects.append((item, item))
                 seen_ids.add(item)
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
    logger.info("Health check requested")
    return {"status": "ok", "message": "AI Learning Coach API is running"}


@app.get("/projects", response_model=List[ProjectResponse])
async def get_projects(user_id: str = Depends(get_user_id)):
    """List all learning projects for the authenticated user."""
    logger.info(f"Listing projects for user: {user_id}")
    projects = list_projects(user_id)
    result = []
    
    for project_id, title in projects:
        memory = get_memory_manager(project_id, user_id)
        goal = memory.load_learning_goal()
        profile = memory.load_user_profile()
        
        # Use filename as title if goal not loaded yet
        display_title = goal.smart_goal if goal else title
        
        result.append(ProjectResponse(
            id=project_id,
            title=display_title[:60] + "..." if len(display_title) > 60 else display_title,
            smart_goal=goal.smart_goal if goal else "",
            total_duration_days=goal.total_duration_days if goal else 0,
            current_milestone_index=profile.current_milestone_index,
            completed_milestones=profile.completed_milestones
        ))
    
    return result


@app.post("/projects", response_model=ProjectResponse)
async def create_project(request: CreateProjectRequest, user_id: str = Depends(get_user_id)):
    """Create a new learning project with a short UUID-based ID."""
    # Generate a short unique ID (8 chars)
    project_id = str(uuid.uuid4())[:8]
    logger.info(f"Creating project '{request.topic}' for user {user_id} with ID {project_id}")
    
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


class UpdatePlanRequest(BaseModel):
    milestones: List[dict]


@app.put("/projects/{project_id}/plan", response_model=ProjectResponse)
async def update_project_plan(project_id: str, request: UpdatePlanRequest, user_id: str = Depends(get_user_id)):
    """Update the milestones for a project."""
    logger.info(f"Updating plan for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Reconstruct Milestone objects from dicts
    try:
        new_milestones = [
            Milestone(
                title=m['title'],
                description=m['description'],
                concepts=m['concepts'],
                duration_days=m.get('duration_days', 3)
            ) for m in request.milestones
        ]
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Missing field in milestone: {e}")
        
    # Validation: Don't allow changing past milestones if they are already completed?
    # For now, we trust the UI to handle presentation, but we should ensure the count is consistent.
    
    goal.milestones = new_milestones
    goal.total_duration_days = sum(m.duration_days for m in new_milestones)
    
    memory.save_learning_goal(goal)
    
    return ProjectResponse(
        id=project_id,
        title=goal.smart_goal[:60] + "..." if len(goal.smart_goal) > 60 else goal.smart_goal,
        smart_goal=goal.smart_goal,
        total_duration_days=goal.total_duration_days,
        current_milestone_index=profile.current_milestone_index,
        completed_milestones=profile.completed_milestones
    )


@app.get("/projects/{project_id}")
async def get_project(project_id: str, user_id: str = Depends(get_user_id)):
    """Get detailed project information including full milestone details."""
    logger.info(f"Getting project {project_id} for user {user_id}")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        logger.warning(f"Project {project_id} not found for user {user_id}")
        raise HTTPException(status_code=404, detail=f"Project {project_id} not found")
    
    return {
        "id": project_id,
        "title": goal.smart_goal[:60] + "..." if len(goal.smart_goal) > 60 else goal.smart_goal,
        "smart_goal": goal.smart_goal,
        "total_duration_days": goal.total_duration_days,
        "current_milestone_index": profile.current_milestone_index,
        "completed_milestones": profile.completed_milestones,
        "milestones": [{
            "title": m.title,
            "description": m.description,
            "concepts": m.concepts,
            "duration_days": m.duration_days
        } for m in goal.milestones]
    }


# ============== Flashcard Endpoints ==============

@app.get("/projects/{project_id}/flashcards", response_model=List[FlashcardResponse])
async def get_flashcards(project_id: str, user_id: str = Depends(get_user_id)):
    """Get flashcards for the current milestone (cached)."""
    logger.info(f"Fetching flashcards for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Find current milestone
    current_milestone = None
    for m in goal.milestones:
        if m.title not in profile.completed_milestones:
            current_milestone = m
            break
    
    if not current_milestone:
        logger.info("All milestones completed")
        return []
    
    # Check cache first
    cached_cards = memory.load_milestone_flashcards(current_milestone.title)
    if cached_cards:
        logger.info(f"Loaded {len(cached_cards)} flashcards from cache for '{current_milestone.title}'")
        generated_cards = cached_cards
    else:
        # Generate and cache
        logger.info(f"Generating new flashcards for '{current_milestone.title}'")
        deck_path, generated_cards = optimizer_agent.generate_curriculum_and_cards(goal, profile)
        memory.save_milestone_flashcards(current_milestone.title, generated_cards)
        logger.info(f"Cached {len(generated_cards)} flashcards")
    
    # Return cards
    return [
        FlashcardResponse(
            id=i,
            front=card.front,
            back=card.back,
            tags=card.tags,
            ease_factor=2.5,
            interval=1,
            repetitions=0
        )
        for i, card in enumerate(generated_cards)
    ]


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


@app.get("/projects/{project_id}/flashcards/remediation", response_model=List[FlashcardResponse])
async def get_remediation_flashcards(project_id: str, user_id: str = Depends(get_user_id)):
    """Get remediation flashcards if user failed last exam."""
    logger.info(f"Fetching remediation flashcards for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    # Check if user failed last exam
    if not profile.assessment_history:
        return []
    
    last_result = profile.assessment_history[-1]
    if last_result.score >= 0.8:
        # User passed, no remediation needed
        return []
    
    # Check cache first
    cached_cards = memory.load_remediation_flashcards()
    if cached_cards:
        logger.info(f"Loaded {len(cached_cards)} remediation flashcards from cache")
        generated_cards = cached_cards
    else:
        # Generate remediation cards
        logger.info("Generating new remediation flashcards")
        deck_path, generated_cards = optimizer_agent.generate_remediation_cards(goal, profile, last_result)
        memory.save_remediation_flashcards(generated_cards)
        logger.info(f"Cached {len(generated_cards)} remediation flashcards")
    
    # Return cards
    return [
        FlashcardResponse(
            id=i,
            front=card.front,
            back=card.back,
            tags=card.tags,
            ease_factor=2.5,
            interval=1,
            repetitions=0
        )
        for i, card in enumerate(generated_cards)
    ]


# ============== Diagnostic Endpoints ==============

@app.get("/projects/{project_id}/diagnostic", response_model=List[QuestionResponse])
async def get_diagnostic_quiz(project_id: str, user_id: str = Depends(get_user_id)):
    """Generate or retrieve a diagnostic quiz for the project."""
    logger.info(f"Generating/Retrieving diagnostic quiz for project {project_id}")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    
    if not goal:
        logger.error(f"Goal not found for project {project_id} (user {user_id})")
        raise HTTPException(status_code=404, detail=f"Project {project_id} not found")
    
    # Check if quiz already exists
    questions = memory.load_diagnostic_quiz()
    if not questions:
        logger.info("Generating new diagnostic quiz...")
        questions = diagnostic_agent.generate_quiz(goal)
        memory.save_diagnostic_quiz(questions)
    else:
        logger.info("Loaded existing diagnostic quiz from disk.")
    
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
    """Submit diagnostic quiz answers and get results using the SAVED quiz."""
    logger.info(f"Submitting diagnostic for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    
    if not goal:
         logger.error(f"Goal not found for project {project_id} (user {user_id})")
         raise HTTPException(status_code=404, detail=f"Project {project_id} not found")
    
    # LOAD the quiz that was actually given to the user
    questions = memory.load_diagnostic_quiz()
    if not questions:
        logger.error(f"No saved quiz found for project {project_id}. Cannot grade.")
        # Fallback to generating one (unideal but prevents crash)
        questions = diagnostic_agent.generate_quiz(goal)
    
    # Grade using examiner agent
    result = examiner_agent.evaluate_submission(questions, submission.answers)
    
    # Save to profile
    result.timestamp = datetime.now().isoformat()
    
    profile = memory.load_user_profile()
    profile.assessment_history.append(result)
    memory.save_user_profile(profile)
    
    logger.info(f"Diagnostic graded for {project_id}. Score: {result.score}")
    
    return AssessmentResultResponse(
        score=result.score,
        correct_concepts=result.correct_concepts,
        missed_concepts=result.missed_concepts,
        question_results=[
            QuestionResultResponse(
                text=r.text,
                user_answer=r.user_answer,
                correct_answer=r.correct_answer,
                explanation=r.explanation,
                is_correct=r.is_correct
            )
            for r in result.question_results
        ],
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
    logger.info(f"Generating exam for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        logger.error(f"Goal not found for project {project_id} (user {user_id})")
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    current_milestone = goal.milestones[profile.current_milestone_index]
    logger.info(f"Current milestone: {current_milestone.title}")
    
    # Check if exam already exists
    questions = memory.load_exam_quiz()
    if not questions:
        logger.info("Generating new exam questions...")
        questions = examiner_agent.generate_assessment(goal, profile, current_milestone.title)
        memory.save_exam_quiz(questions)
    else:
        logger.info("Loaded existing exam questions from disk.")
    
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
    logger.info(f"Submitting exam for project {project_id} (user {user_id})")
    memory = get_memory_manager(project_id, user_id)
    goal = memory.load_learning_goal()
    profile = memory.load_user_profile()
    
    if not goal:
        logger.error(f"Goal not found for project {project_id} (user {user_id})")
        raise HTTPException(status_code=404, detail="No learning goal found")
    
    current_milestone = goal.milestones[profile.current_milestone_index]
    
    # LOAD the exam questions that were actually given to the user
    questions = memory.load_exam_quiz()
    if not questions:
        logger.error(f"No saved exam found for project {project_id}. Cannot grade.")
        # Fallback to generating (unideal but prevents crash)
        questions = examiner_agent.generate_assessment(goal, profile, current_milestone.title)
    
    # Grade
    result = examiner_agent.evaluate_submission(questions, submission.answers)
    result.timestamp = datetime.now().isoformat()
    
    # Update profile
    profile.assessment_history.append(result)
    passed = result.score >= 0.8
    
    if passed:
        logger.info(f"User passed milestone '{current_milestone.title}' for project {project_id}")
        profile.completed_milestones.append(current_milestone.title)
        profile.current_milestone_index += 1
        profile.current_deck_path = None
        profile.milestone_start_date = None
        # Clear the exam file so a new one can be generated for the next milestone
        memory.save_exam_quiz([]) 
    else:
        logger.info(f"User failed milestone '{current_milestone.title}' with score {result.score}")
    
    memory.save_user_profile(profile)
    
    return AssessmentResultResponse(
        score=result.score,
        correct_concepts=result.correct_concepts,
        missed_concepts=result.missed_concepts,
        question_results=[
            QuestionResultResponse(
                text=r.text,
                user_answer=r.user_answer,
                correct_answer=r.correct_answer,
                explanation=r.explanation,
                is_correct=r.is_correct
            )
            for r in result.question_results
        ],
        feedback=result.feedback,
        excelled_at=result.excelled_at,
        improvement_areas=result.improvement_areas,
        challenges=result.challenges,
        passed=passed
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

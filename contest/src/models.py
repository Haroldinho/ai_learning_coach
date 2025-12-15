from pydantic import BaseModel, Field
from typing import List, Dict, Optional

class Flashcard(BaseModel):
    front: str = Field(..., description="Question or Concept")
    back: str = Field(..., description="Answer or Definition")
    tags: List[str] = Field(default_factory=list, description="Tags for organization")

class FlashcardList(BaseModel):
    flashcards: List[Flashcard]

class FlashcardDeck(BaseModel):
    name: str
    cards: List[Flashcard]

class Question(BaseModel):
    text: str = Field(..., description="The content of the question")
    difficulty: str = Field(..., description="Difficulty level: beginner, intermediate, advanced")
    key_concept: str = Field(..., description="The specific concept being tested")
    correct_answer: str = Field(..., description="The correct answer to the question")
    explanation: str = Field(..., description="Explanation of why the answer is correct")

class Quiz(BaseModel):
    questions: List[Question]

class AssessmentResult(BaseModel):
    score: float = Field(..., description="Percentage score (0-1.0)")
    correct_concepts: List[str] = Field(default_factory=list)
    missed_concepts: List[str] = Field(default_factory=list)

    feedback: str = Field(..., description="Qualitative feedback for the learner")
    timestamp: str = Field(..., description="ISO timestamp of the assessment")

class Milestone(BaseModel):
    title: str
    description: str
    concepts: List[str]
    duration_days: int = 3

class LearningGoal(BaseModel):
    original_request: str
    smart_goal: str
    milestones: List[Milestone]
    total_duration_days: int

class UserProfile(BaseModel):
    name: str = "Learner"
    topic_mastery: Dict[str, float] = Field(default_factory=dict, description="Map of concept to mastery level (0.0-1.0)")
    completed_milestones: List[str] = Field(default_factory=list)
    current_milestone_index: int = 0
    assessment_history: List[AssessmentResult] = Field(default_factory=list)
    
    # Active State Tracking
    current_deck_path: Optional[str] = None
    milestone_start_date: Optional[str] = None

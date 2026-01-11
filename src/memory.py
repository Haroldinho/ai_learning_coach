import json
import os
from typing import List, Optional
from .models import UserProfile, LearningGoal, Question

class MemoryManager:
    def __init__(self, storage_dir=".coin_cache"):
        self.storage_dir = storage_dir
        os.makedirs(self.storage_dir, exist_ok=True)
        self.user_file = f"{self.storage_dir}/user_profile.json"
        self.goal_file = f"{self.storage_dir}/learning_goal.json"
        self.diagnostic_file = f"{self.storage_dir}/diagnostic_quiz.json"
        self.exam_file = f"{self.storage_dir}/exam_quiz.json"

    def get_project_title(self) -> str:
        """Returns the project title from the learning goal if available."""
        goal = self.load_learning_goal()
        return goal.smart_goal if goal else "Unknown Project"

    def save_user_profile(self, profile: UserProfile):
        with open(self.user_file, 'w') as f:
            f.write(profile.model_dump_json(indent=2))

    def load_user_profile(self) -> UserProfile:
        if not os.path.exists(self.user_file):
            return UserProfile()
        with open(self.user_file, 'r') as f:
            data = json.load(f)
            return UserProfile(**data)

    def save_learning_goal(self, goal: LearningGoal):
        with open(self.goal_file, 'w') as f:
            f.write(goal.model_dump_json(indent=2))

    def load_learning_goal(self) -> LearningGoal:
        if not os.path.exists(self.goal_file):
            return None
        with open(self.goal_file, 'r') as f:
            data = json.load(f)
            return LearningGoal(**data)

    def save_diagnostic_quiz(self, questions: List[Question]):
        """Saves the generated diagnostic quiz for consistency during grading."""
        with open(self.diagnostic_file, 'w') as f:
            json.dump([q.model_dump() for q in questions], f, indent=2)

    def load_diagnostic_quiz(self) -> Optional[List[Question]]:
        """Loads the saved diagnostic quiz."""
        if not os.path.exists(self.diagnostic_file):
            return None
        with open(self.diagnostic_file, 'r') as f:
            data = json.load(f)
            return [Question(**q) for q in data]

    def clear_memory(self):
        if os.path.exists(self.user_file):
            os.remove(self.user_file)
        if os.path.exists(self.goal_file):
            os.remove(self.goal_file)
        if os.path.exists(self.diagnostic_file):
            os.remove(self.diagnostic_file)
        if os.path.exists(self.exam_file):
            os.remove(self.exam_file)

    def save_exam_quiz(self, questions: List[Question]):
        """Saves the generated exam quiz for consistency during grading."""
        with open(self.exam_file, 'w') as f:
            json.dump([q.model_dump() for q in questions], f, indent=2)

    def load_exam_quiz(self) -> Optional[List[Question]]:
        """Loads the saved exam quiz."""
        if not os.path.exists(self.exam_file):
            return None
        with open(self.exam_file, 'r') as f:
            data = json.load(f)
            return [Question(**q) for q in data]
    
    def save_milestone_flashcards(self, milestone_title: str, flashcards: List):
        """Saves generated flashcards for a specific milestone."""
        from .models import Flashcard
        safe_title = milestone_title.replace(' ', '_').replace('/', '_')
        flashcard_file = f"{self.storage_dir}/flashcards_{safe_title}.json"
        with open(flashcard_file, 'w') as f:
            json.dump([card.model_dump() if isinstance(card, Flashcard) else card for card in flashcards], f, indent=2)
    
    def load_milestone_flashcards(self, milestone_title: str) -> Optional[List]:
        """Loads cached flashcards for a specific milestone."""
        from .models import Flashcard
        safe_title = milestone_title.replace(' ', '_').replace('/', '_')
        flashcard_file = f"{self.storage_dir}/flashcards_{safe_title}.json"
        if not os.path.exists(flashcard_file):
            return None
        with open(flashcard_file, 'r') as f:
            data = json.load(f)
            return [Flashcard(**card) for card in data]
    
    def save_remediation_flashcards(self, flashcards: List):
        """Saves remediation flashcards."""
        from .models import Flashcard
        remediation_file = f"{self.storage_dir}/flashcards_remediation.json"
        with open(remediation_file, 'w') as f:
            json.dump([card.model_dump() if isinstance(card, Flashcard) else card for card in flashcards], f, indent=2)
    
    def load_remediation_flashcards(self) -> Optional[List]:
        """Loads cached remediation flashcards."""
        from .models import Flashcard
        remediation_file = f"{self.storage_dir}/flashcards_remediation.json"
        if not os.path.exists(remediation_file):
            return None
        with open(remediation_file, 'r') as f:
            data = json.load(f)
            return [Flashcard(**card) for card in data]

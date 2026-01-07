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

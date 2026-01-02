from google import genai
from google.genai import types
from google.genai.errors import ClientError
from dotenv import load_dotenv
import os
import sys
import random
from typing import List
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from ..models import LearningGoal, UserProfile, Flashcard, FlashcardDeck, FlashcardList, AssessmentResult

# Add the parent directory to sys.path to allow importing from tools
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
sys.path.append(parent_dir)

from tools.anki_connection import create_anki_deck

load_dotenv()

class OptimizerAgent:
    def __init__(self):
        self.client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        self.model_id = 'gemini-2.0-flash-lite'

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def generate_curriculum_and_cards(self, goal: LearningGoal, user_profile: UserProfile) -> str:
        """
        Determines the next phase of study and generates Anki flashcards.
        Returns the path to the generated .apkg file.
        """
        
        # 1. Determine what to study next based on uncompleted milestones
        next_milestone = None
        for m in goal.milestones:
            if m.title not in user_profile.completed_milestones:
                next_milestone = m
                break
        
        if not next_milestone:
            return "All milestones completed!"

        # 2. Generate Flashcards for this milestone
        prompt = f"""
        You are an expert Curriculum Designer.
        The user is working on the milestone: "{next_milestone.title}".
        Description: {next_milestone.description}
        Key Concepts: {', '.join(next_milestone.concepts)}

        Generate 15 high-quality flashcards for this milestone.
        - Front: Concept, Question, or Term
        - Back: Definition, Answer, or Explanation
        - Tags: Add 1-2 relevant tags (e.g., '{next_milestone.title}', 'Basic')

        Output a FlashcardList object containing Flashcard objects.
        """

        try:
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=FlashcardList
                )
            )
            flashcards = response.parsed.flashcards
            
            # 3. Convert to Dict format for Anki Tool
            anki_cards = [{'front': c.front, 'back': c.back} for c in flashcards]
            
            # 4. Generate Deck
            deck_name = f"{goal.smart_goal} - {next_milestone.title}"
            # Sanitize filename
            filename = f"deck_{next_milestone.title.replace(' ', '_')}.apkg"
            
            result_path = create_anki_deck(deck_name, anki_cards, filename=filename)
            return result_path

        except Exception as e:
            print(f"Error generating curriculum/cards: {e}")
            raise e

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def generate_remediation_cards(self, goal: LearningGoal, user_profile: UserProfile, result: AssessmentResult) -> str:
        """
        Generates targeted remediation flashcards based on assessment failures.
        """
        current_milestone = goal.milestones[user_profile.current_milestone_index]
        
        prompt = f"""
        You are a Remediation specialist.
        The user failed their assessment for: "{current_milestone.title}".
        
        Areas that need improvement:
        {result.improvement_areas}
        
        Challenges to address:
        {result.challenges}
        
        Generate 5 high-quality REMEDIATION flashcards that directly address these specific weaknesses.
        - Front: Concept, Question, or Term
        - Back: Definition, Answer, or Explanation
        - Tags: Add tags like 'REMEDIATION', '{current_milestone.title}'
        
        Output a FlashcardList object containing Flashcard objects.
        """

        try:
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=FlashcardList
                )
            )
            flashcards = response.parsed.flashcards
            anki_cards = [{'front': c.front, 'back': c.back} for c in flashcards]
            
            deck_name = f"REMEDIATION: {current_milestone.title}"
            filename = f"deck_REMEDIATION_{current_milestone.title.replace(' ', '_')}.apkg"
            
            result_path = create_anki_deck(deck_name, anki_cards, filename=filename)
            return result_path

        except Exception as e:
            print(f"Error generating remediation cards: {e}")
            raise e

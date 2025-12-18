from google import genai
from google.genai import types
from google.genai.errors import ClientError
from dotenv import load_dotenv
import os
from typing import List
from pydantic import BaseModel
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from ..models import LearningGoal, Question, Quiz

load_dotenv()

class DiagnosticAgent:
    def __init__(self):
        self.client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        self.model_id = 'gemini-2.0-flash-lite'

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def generate_quiz(self, goal: LearningGoal) -> List[Question]:
        """
        Generates a 10-question diagnostic quiz based on the learning goal.
        """
        prompt = f"""
        You are an expert Teacher.
        The user has the following learning goal:
        {goal.smart_goal}

        The key milestones are:
        {[m.title for m in goal.milestones]}

        Generate a 10-question diagnostic quiz to assess the user's current knowledge level across these milestones.
        The questions should range from basic to intermediate difficulty.
        
        Output a Quiz object containing 10 Question objects.
        """

        try:
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=Quiz
                )
            )
            return response.parsed.questions
        except Exception as e:
            print(f"Error generating diagnostic quiz: {e}")
            raise e

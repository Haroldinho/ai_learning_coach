from google import genai
from google.genai import types
from google.genai.errors import ClientError
from dotenv import load_dotenv
import os
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from ..models import LearningGoal

load_dotenv()

class GoalAgent:
    def __init__(self):
        self.client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        self.model_id = 'gemini-2.0-flash-lite'

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def create_learning_plan(self, user_request: str) -> LearningGoal:
        prompt = f"""
        You are an expert Learning Coach.
        The user wants to learn: "{user_request}".

        Your task:
        1.  Convert this into a specific, measurable, achievable, relevant, and time-bound (SMART) goal.
        2.  Break it down into a sequence of milestones.
        3.  Estimate the total time required.
        4.  Create a detailed structured plan.

        Output must be a valid JSON object matching the LearningGoal schema.
        """

        try:
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=LearningGoal
                )
            )
            return response.parsed
        except Exception as e:
            print(f"Error generating learning plan: {e}")
            raise e

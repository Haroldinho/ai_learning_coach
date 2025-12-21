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
        print(f"DEBUG: Generating initial plan for '{user_request}'")
        
        initial_prompt = f"""
        You are an expert Learning Coach.
        The user wants to learn: "{user_request}".

        Your task:
        1.  Convert this into a specific, measurable, achievable, relevant, and time-bound (SMART) goal.
        2.  Break it down into a sequence of milestones.
        3.  Estimate the total time required.
        4.  Create a detailed structured plan.

        Output must be a valid JSON object matching the LearningGoal schema.
        """
        
        current_plan = self._generate(initial_prompt)
        
        while True:
            # Display Plan Summary
            print(f"\n📋 Proposed Plan: {current_plan.smart_goal}")
            print(f"⏱️  Duration: {current_plan.total_duration_days} days")
            print("Milestones:")
            for i, m in enumerate(current_plan.milestones):
                print(f"  {i+1}. {m.title} ({m.duration_days} days): {m.description}")
            
            # User Feedback
            print("\nDoes this plan look good to you?")
            print("  [Y] Yes, let's start!")
            print("  [Any text] No, please change... (type your feedback)")
            user_feedback = input("> ").strip()
            
            if user_feedback.lower() in ['y', 'yes', '']:
                return current_plan
            
            print("\n🔄 Updating plan based on your feedback...")
            current_plan = self._update_learning_plan(current_plan, user_feedback)

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def _generate(self, prompt: str) -> LearningGoal:
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

    def _update_learning_plan(self, current_plan: LearningGoal, feedback: str) -> LearningGoal:
        prompt = f"""
        You are an expert Learning Coach.
        You previously generated a learning plan, but the user has some feedback.
        
        Current Plan (JSON):
        {current_plan.model_dump_json()}
        
        User Feedback:
        "{feedback}"
        
        Your task:
        1.  Modify the plan to address the user's feedback.
        2.  Ensure the plan remains SMART and structured.
        
        Output must be a valid JSON object matching the LearningGoal schema.
        """
        return self._generate(prompt)

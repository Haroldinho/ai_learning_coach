from google import genai
from google.genai import types
from google.genai.errors import ClientError
from dotenv import load_dotenv
import os
import random
from typing import List
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from ..models import LearningGoal, UserProfile, Question, AssessmentResult, Quiz

load_dotenv()

class ExaminerAgent:
    def __init__(self):
        self.client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
        self.model_id = 'gemini-2.0-flash-lite'

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def generate_assessment(self, goal: LearningGoal, user_profile: UserProfile, current_milestone_title: str) -> List[Question]:
        """
        Generates an assessment:
        - 7 questions on the current milestone.
        - 3 questions from previous milestones (Active Recall), if available.
        """
        
        # 1. Active Recall Selection
        active_recall_context = ""
        previous_concepts = []
        
        # Collect concepts from previously completed milestones or past assessment misses
        if user_profile.assessment_history:
            # Look at past misses
            all_missed = []
            for result in user_profile.assessment_history:
                all_missed.extend(result.missed_concepts)
            
            if all_missed:
                # Pick 2-3 random missed concepts
                recall_targets = random.sample(all_missed, min(len(all_missed), 3))
                active_recall_context = f"""
                IMPORTANT: You must include 3 questions specifically testing these previously missed concepts:
                {', '.join(recall_targets)}
                """

        # 2. Main Prompt
        prompt = f"""
        You are a strict Examiner.
        The user has just finished studying: "{current_milestone_title}".
        
        Generate a 10-question assessment.
        
        Structure:
        - 7 questions strictly about "{current_milestone_title}".
        - 3 questions for Active Recall.
        {active_recall_context}
        
        The questions should be challenging but fair.
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
            print(f"Error generating assessment: {e}")
            raise e

    @retry(
        retry=retry_if_exception_type(ClientError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=2, min=4, max=60)
    )
    def evaluate_submission(self, questions: List[Question], user_answers: List[str]) -> AssessmentResult:
        """
        Evaluates the user's answers against the generated questions.
        For simplicity in this agent, we will ask the LLM to grade the open-ended answers.
        """
        
        # Construct the grading prompt
        grading_content = "Please grade the following quiz:\n"
        for i, (q, ans) in enumerate(zip(questions, user_answers)):
            grading_content += f"Q{i+1}: {q.text}\nCorrect Answer: {q.correct_answer}\nUser Answer: {ans}\nConcept: {q.key_concept}\n\n"
            
        prompt = f"""
        {grading_content}
        
        Task:
        1. Grade each answer as Correct or Incorrect.
        2. Calculate the final percentage score (0.0 to 1.0).
        3. Identify which concepts were known (Correct) and which were missed (Incorrect).
        4. Provide qualitative feedback:
           - In 'feedback', provide a general encouraging summary.
           - In 'excelled_at', list specific things the user did well.
           - In 'improvement_areas', list what the user didn't do well or missed.
           - In 'challenges', suggest what the user could do to challenge themselves further. If they achieve a high score 9 or 10, suggest questions going beyond the current learning plan, questions that apply the concepts to different contexts, or questions that require the user to apply the concepts in a different way.
       
        Output a valid AssessmentResult JSON object.
        """
        
        try:
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=AssessmentResult
                )
            )
            return response.parsed
        except Exception as e:
            print(f"Error grading submission: {e}")
            raise e

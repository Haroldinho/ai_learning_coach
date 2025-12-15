from pydantic import BaseModel
from google import genai
from google.genai import types
from dotenv import load_dotenv
import os

load_dotenv()

# --- CONFIGURATION ---
client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

# --- DATA MODELS ---
class Question(BaseModel):
    text: str
    difficulty: str
    key_concept: str

class QuestionBank(BaseModel):
    topic: str
    target_audience: str
    questions: list[Question]

from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
from google.genai.errors import ClientError

# ... existing imports ...

# --- THE AGENT ---
@retry(
    retry=retry_if_exception_type(ClientError),
    wait=wait_exponential(multiplier=1, min=4, max=60),
    stop=stop_after_attempt(5)
)
def generate_study_questions(topic: str, audience_level: str = "intermediate", count: int = 5) -> QuestionBank:
    """
    Agent responsible for brainstorming study questions for a specific topic.
    Unlike the Examiner, this agent focuses on generating open-ended discussion/study questions
    rather than a strict multiple-choice quiz.
    """
    
    prompt = f"""
    You are an expert tutor designing a study guide.
    Generate {count} thought-provoking study questions about '{topic}' for a {audience_level} learner.
    
    The questions should:
    1. Encourage deep thinking, not just facts.
    2. Cover different aspects of the topic.
    3. Include identifying the key concept being tested.
    """
    
    try:
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type='application/json',
                response_schema=QuestionBank
            )
        )
        return response.parsed
    except ClientError as e:
        if e.code == 429:
            print(f"⚠️ Quota exceeded. Retrying in a moment... (Error: {e.message})")
            raise e # Let tenacity handle the retry
        else:
            raise e

# --- DEMONSTRATION ---
if __name__ == "__main__":
    test_topic = "Neural Networks"
    print(f"🧠 Asking the Question Generator Agent to brainstorm about: {test_topic}...\n")
    
    result = generate_study_questions(test_topic, audience_level="beginner", count=3)
    
    print(f"📋 Topic: {result.topic} ({result.target_audience})")
    for i, q in enumerate(result.questions, 1):
        print(f"\n{i}. {q.text}")
        print(f"   [Concept: {q.key_concept}] | [Level: {q.difficulty}]")

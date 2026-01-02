import sqlite3
import datetime
from pydantic import BaseModel
from google import genai
from google.genai import types
from dotenv import load_dotenv
import os
load_dotenv()

# --- 1. SETUP & CONFIGURATION ---
# Initialize the new Google Gen AI Client
client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))


# Define the Structured Output Schema using Pydantic
class QuizQuestion(BaseModel):
    question: str
    options: list[str]
    correct_answer: str
    explanation: str


class Quiz(BaseModel):
    topic: str
    questions: list[QuizQuestion]


# --- 2. DATABASE HELPERS ---
def get_topic_for_review(user_id):
    """Finds a topic where next_review_due is in the past."""
    conn = sqlite3.connect('learning_coach.db')
    cursor = conn.cursor()
    
    # Simple logic: Find first topic due for review
    query = """
    SELECT t.name, s.mastery_score
    FROM user_topic_state s
    JOIN topics t ON s.topic_id = t.topic_id
    WHERE s.user_id = ? AND s.next_review_due <= ?
    ORDER BY s.next_review_due ASC
    LIMIT 1
    """
    cursor.execute(query, (user_id, datetime.datetime.now()))
    result = cursor.fetchone()
    conn.close()
    if result:
        return result[0] 
    return "Introduction to Linear Programming" 


# --- 3. THE EXAMINER AGENT ---
def generate_quiz(topic_name, difficulty="intermediate"):
    """
    Uses Gemini to generate a strict JSON quiz based on the topic.
    """
    prompt = f"""
    Create a {difficulty} level quiz about '{topic_name}'.
    The quiz must have 3 questions.
    Focus on conceptual understanding, not just definitions.
    """

    # CALL GEMINI WITH STRUCTURED OUTPUT
    response = client.models.generate_content(
        model='gemini-2.0-flash', # Use Flash for speed
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type='application/json',
            response_schema=Quiz
        )
    )
    
    # The SDK automatically parses the JSON into our Pydantic object
    return response.parsed

# --- 4. RUNNING THE AGENT LOOP ---
def run_learning_session(user_id):
    print("--- 🤖 ADAPTIVE LEARNING AGENT ACTIVATED ---")
    
    # Step 1: Memory Lookup
    topic = get_topic_for_review(user_id)
    print(f"🎯 Today's Focus: {topic}")
    
    # Step 2: Agent Generates Quiz
    quiz_data = generate_quiz(topic)
    
    score = 0
    total = len(quiz_data.questions)
    
    # Step 3: Interactive Loop
    for q in quiz_data.questions:
        print(f"\nQ: {q.question}")
        for i, opt in enumerate(q.options):
            print(f"   {i+1}. {opt}")
            
        user_choice = input("Your answer (type the option text): ")
        
        # Step 4: Simple Grading (In a real app, use an Agent to grade fuzzy answers)
        if user_choice.strip().lower() == q.correct_answer.strip().lower():
            print("✅ Correct!")
            score += 1
        else:
            print(f"❌ Incorrect. The answer was: {q.correct_answer}")
            print(f"💡 Why: {q.explanation}")

    print(f"\n🏁 Session Complete. Score: {score}/{total}")
    
    # Step 5: Update Memory (Spaced Repetition Logic)
    # If score is high -> Push review date +7 days. If low -> +1 day.
    next_review = datetime.datetime.now() + datetime.timedelta(days=(7 if score == total else 1))
    print(f"📅 Next review scheduled for: {next_review.strftime('%Y-%m-%d')}")
    
    # (SQL Update code would go here to save 'next_review' to the DB)
# --- 1. DEFINE THE VALIDATION SCHEMA ---
# The whitepaper suggests structured rubrics for judges 
class ValidationResult(BaseModel):
    is_valid: bool
    flaws_found: list[str]
    corrected_question: str | None 
    corrected_answer: str | None
    reasoning: str

# --- 2. THE VERIFIER AGENT (LLM-as-a-Judge) ---
def validate_quiz_question(topic, question_data):
    """
    Acts as a 'Red Teamer' to try and break the generated question.
    """
    
    # We feed the "Judge" the context and the candidate output
    validation_prompt = f"""
    You are an expert Professor in {topic}. Review this quiz question for accuracy.
    
    CANDIDATE QUESTION: {question_data.question}
    PROPOSED OPTIONS: {question_data.options}
    CLAIMED CORRECT ANSWER: {question_data.correct_answer}
    
    TASK:
    1. Solve the problem yourself step-by-step.
    2. Check if the 'correct answer' is factually indisputable.
    3. Check if any 'distractor' options are accidentally correct.
    4. Ensure the difficulty matches 'Intermediate' level.
    
    Output JSON with your verdict.
    """

    response = client.models.generate_content(
        model='gemini-2.0-flash', 
        contents=validation_prompt,
        config=types.GenerateContentConfig(
            response_mime_type='application/json',
            response_schema=ValidationResult
        )
    )
    
    return response.parsed

# --- 3. THE SAFE GENERATION LOOP ---
def generate_validated_quiz(topic_name):
    print(f"🕵️ Generating and Validating Quiz for: {topic_name}...")
    
    max_retries = 3
    for attempt in range(max_retries):
        # A. Generate (The Original 'Line Cook' Agent)
        raw_quiz = generate_quiz(topic_name) # From previous code
        
        # B. Validate (The 'Food Critic' Agent)
        # We validate just the first question for this demo
        verdict = validate_quiz_question(topic_name, raw_quiz.questions[0])
        
        if verdict.is_valid:
            print("✅ Verification Passed: Question is solid.")
            return raw_quiz
        else:
            print(f"⚠️ Verification Failed: {verdict.reasoning}")
            print(f"   Refining attempt {attempt+1}...")
            # Ideally, you pass the 'verdict.flaws_found' back to the generator to fix it
            
    raise Exception("Could not generate a valid quiz after 3 attempts.")

# --- THE CRITIC AGENT (Agent-as-a-Judge) ---
def critic_review_study_plan(user_skill_level, proposed_topic_tree):
    """
    Validates the 'Dependency Graph' of the study plan.
    Ensures we don't teach advanced topics before basics.
    """
    
    critic_prompt = f"""
    Review this proposed study plan for a student at level: {user_skill_level}.
    
    PROPOSED PLAN (Tree Structure):
    {proposed_topic_tree}
    
    CRITIC RUBRIC:
    1. Are the prerequisites strictly respected? (e.g. Arithmetic -> Algebra -> Calculus)
    2. Is the pacing realistic for a 1-week sprint?
    3. Are there missing foundational concepts?
    
    If REJECTED, output a corrected JSON tree.
    If APPROVED, output "APPROVED".
    """
    
    # ... Call Gemini with this prompt ...
    # This acts as the "Reviewer UI" described in the paper, but automated.
# --- EXECUTION ---
# run_learning_session(user_id=1)
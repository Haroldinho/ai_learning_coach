import sys
import os
import datetime
import json
# Ensure we can import from src
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.memory import MemoryManager
from src.agents.goal_agent import GoalAgent
from src.agents.diagnostic_agent import DiagnosticAgent
from src.agents.optimizer_agent import OptimizerAgent
from src.agents.examiner_agent import ExaminerAgent
from src.models import AssessmentResult
from src.utils import to_snake_case
from src.migration import migrate_legacy_data

def list_projects(base_path: str = ".coin_cache") -> list[str]:
    """Lists available project directories in the base cache path."""
    if not os.path.exists(base_path):
        return []
    
    projects = []
    for item in os.listdir(base_path):
        item_path = os.path.join(base_path, item)
        # Check if directory and contains learning_goal.json
        if os.path.isdir(item_path) and os.path.exists(os.path.join(item_path, "learning_goal.json")):
            # Get display title
            try:
                with open(os.path.join(item_path, "learning_goal.json"), 'r') as f:
                    data = json.load(f)
                    title = data.get("smart_goal", item)
                    # Truncate likely long smart_goal for display
                    if len(title) > 60:
                        title = title[:57] + "..."
                    projects.append((item, title))
            except Exception:
                projects.append((item, item))
    return projects

def get_project_choice() -> tuple[str, str]:
    """
    Prompts user to select a project or start a new one.
    Returns: (project_directory_name, user_input_topic_if_new)
             user_input_topic_if_new is None if continuing existing project.
    """
    projects = list_projects()
    
    print("\nSelect an option:")
    print("  0. Start a new lesson")
    for i, (dirname, title) in enumerate(projects):
        print(f"  {i+1}. Continue '{title}'")
    
    while True:
        choice = input("\nEnter your choice (number): ").strip()
        if choice == "0":
            topic = input("\nWhat would you like to learn today? ")
            project_name = to_snake_case(topic)
            if not project_name:
                project_name = f"project_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
            return project_name, topic
        
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(projects):
                return projects[idx][0], None # Return dirname, no new topic
        except ValueError:
            pass
        
        print("Invalid choice. Please try again.")

def main():
    print("🎓 Welcome to your AI Learning Coach!")
    
    # 0. Migration Support
    migrate_legacy_data()

    # 1. Project Selection
    project_dir_name, new_topic = get_project_choice()
    project_path = os.path.join(".coin_cache", project_dir_name)
    
    print(f"\n📂 Loading project space: {project_dir_name}...")

    # 2. Initialize Components
    memory = MemoryManager(storage_dir=project_path)
    goal_agent = GoalAgent()
    diagnostic_agent = DiagnosticAgent()
    optimizer_agent = OptimizerAgent()
    examiner_agent = ExaminerAgent()

    # 3. Check State
    user_profil = memory.load_user_profile()
    learning_goal = memory.load_learning_goal()

    # --- Phase 1: Initialization ---
    if not learning_goal:
        # If it's a new project, we expect new_topic to be populated from the menu
        if not new_topic:
             # Fallback if somehow we got here without a topic (e.g. empty dir selected)
             new_topic = input("\nWhat would you like to learn today? ")
             
        user_input = new_topic
        print("🧠 Analyzing your goal and creating a study plan...")

        
        learning_goal = goal_agent.create_learning_plan(user_input)
        memory.save_learning_goal(learning_goal)
        print(f"\n✅ Plan Created: {learning_goal.smart_goal}")
        print(f"📅 Duration: {learning_goal.total_duration_days} days")
        print("Milestones:")
        for i, m in enumerate(learning_goal.milestones):
            print(f"  {i+1}. {m.title}")

        print("\n🩺 Let's assess your starting baseline...")
        questions = diagnostic_agent.generate_quiz(learning_goal)
        
        # Administer Quiz
        user_answers = []
        for i, q in enumerate(questions):
            ans = input(f"\nQ{i+1}: {q.text}\nYour Answer: ")
            user_answers.append(ans)
        
        # Initial Grading (Using Examiner for simplicity of grading)
        # Note: In a real app, Diagnostic might have its own logic, but Examiner is fine here.
        result = examiner_agent.evaluate_submission(questions, user_answers)
        result.timestamp = datetime.datetime.now().isoformat()
        
        user_profil.assessment_history.append(result)
        memory.save_user_profile(user_profil)
        print(f"\n📊 Baseline Assessment: {result.score * 100:.1f}%")
        print(f"💡 Feedback: {result.feedback}")
        if result.excelled_at:
            print(f"🌟 Excelled At: {result.excelled_at}")
        if result.improvement_areas:
            print(f"📉 Areas to Improve: {result.improvement_areas}")
        if result.challenges:
            print(f"🚀 Challenges: {result.challenges}")

    # --- Phase 2: Loop ---
    while True:
        # Check completion
        completed_titles = user_profil.completed_milestones
        all_milestones = [m.title for m in learning_goal.milestones]
        
        if len(completed_titles) == len(all_milestones):
            print("\n🎉 CONGRATULATIONS! You have completed all milestones for this goal!")
            break

        # Identify Current Milestone
        current_milestone = None
        for m in learning_goal.milestones:
            if m.title not in completed_titles:
                current_milestone = m
                break
        
        print(f"\n🚀 Current Phase: {current_milestone.title}")
        print(f"ℹ️  {current_milestone.description}")
        
        # Step 3: Optimizer (Curriculum + Flashcards)
        
        # Check if we are already in the middle of this milestone
        if user_profil.current_deck_path and user_profil.current_milestone_index == len(user_profil.completed_milestones):
            deck_path = user_profil.current_deck_path
            start_date = user_profil.milestone_start_date or "Unknown date"
            print(f"\n🔄 Resuming study plan (Started: {start_date})...")
            print(f"✅ Anki Deck available at: {deck_path}")
        else:
            print("\n⚡ Generating Study Materials (Anki Deck)...")
            deck_path = optimizer_agent.generate_curriculum_and_cards(learning_goal, user_profil)
            
            # Save active state
            user_profil.current_deck_path = deck_path
            user_profil.milestone_start_date = datetime.datetime.now().isoformat()
            memory.save_user_profile(user_profil)
            
            print(f"✅ Anki Deck saved to: {deck_path}")

        print("👉 Import this file into Anki and study for 3 days.")
        
        action = input("\n[Press Enter when you have completed your 3 days of study and are ready for the exam, or type 'q' to quit]: ")
        if action.lower() == 'q':
            print("\n💾 Progress saved. Take your time studying! See you next time.")
            break
        
        # Step 4: Examiner
        print("\n📝 Time for your Assessment!")
        # Generate with Active Recall
        exam_questions = examiner_agent.generate_assessment(learning_goal, user_profil, current_milestone.title)
        
        exam_answers = []
        for i, q in enumerate(exam_questions):
            # Show if it's a recall question? No, keep it mixed.
            ans = input(f"\nQ{i+1}: {q.text}\n(Difficulty: {q.difficulty}) Answer: ")
            exam_answers.append(ans)
        
        print("\n🤔 Grading...")
        exam_result = examiner_agent.evaluate_submission(exam_questions, exam_answers)
        exam_result.timestamp = datetime.datetime.now().isoformat()
        
        user_profil.assessment_history.append(exam_result)
        
        print(f"\n📊 Score: {exam_result.score * 100:.1f}%")
        print(f"💡 Feedback: {exam_result.feedback}")
        if exam_result.excelled_at:
            print(f"🌟 Excelled At: {exam_result.excelled_at}")
        if exam_result.improvement_areas:
            print(f"📉 Areas to Improve: {exam_result.improvement_areas}")
        if exam_result.challenges:
            print(f"🚀 Challenges: {exam_result.challenges}")
        
        # Step 5: Update State
        if exam_result.score >= 0.7:  # Pass threshold
            print(f"✅ You passed '{current_milestone.title}'!")
            user_profil.completed_milestones.append(current_milestone.title)
            user_profil.current_milestone_index += 1
            # Clear active state
            user_profil.current_deck_path = None
            user_profil.milestone_start_date = None
        else:
            print(f"⚠️ Score too low to advance. Let's optimize the plan and try again in 3 days.")
            print("\n⚡ Generating targeted remediation materials...")
            
            remediation_deck_path = optimizer_agent.generate_remediation_cards(learning_goal, user_profil, exam_result)
            
            # Update profile with remediation deck
            user_profil.current_deck_path = remediation_deck_path
            user_profil.milestone_start_date = datetime.datetime.now().isoformat()
            
            print(f"✅ Remediation Deck saved to: {remediation_deck_path}")
            print(f"👉 Please study these specific cards to master '{current_milestone.title}'.")
            
        memory.save_user_profile(user_profil)
        
        cont = input("\nContinue to next phase? (y/n): ")
        if cont.lower() != 'y':
            print("💾 Progress saved. See you next time!")
            break

if __name__ == "__main__":
    main()

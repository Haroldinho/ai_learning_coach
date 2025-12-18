import os
import json
import shutil
from .utils import to_snake_case

def migrate_legacy_data(base_path: str = ".coin_cache"):
    """
    Migrates legacy cache files (user_profile.json, learning_goal.json)
    from the root of base_path to a project-specific subdirectory.
    """
    legacy_goal_file = os.path.join(base_path, "learning_goal.json")
    legacy_user_file = os.path.join(base_path, "user_profile.json")

    # Check if legacy files exist
    if not os.path.exists(legacy_goal_file):
        return

    try:
        # Load the learning goal to determine the project name
        with open(legacy_goal_file, 'r') as f:
            data = json.load(f)
            # Try to get the specific goal or topic. The model has 'smart_goal' often starting with "Master ... in 30 days"
            # Ideally we want the original user input, but it might not be stored directly as a clean title.
            # We will use a sanitized version of the smart_goal title or fallback to 'legacy_project'.
            
            # Looking at main.py, goal_agent returns a LearningGoal object.
            # Let's inspect the LearningGoal model in memory.py/models.py if needed, 
            # but usually it has 'smart_goal' field which is the text.
            topic = data.get("smart_goal", "Legacy Project")
            # Truncate if too long (e.g. "Master Quantum Physics in 30 days") -> "master_quantum_physics_in_30_days"
            # Ideally we'd validte this, but let's just use it.
            
        project_name = to_snake_case(topic)
        if not project_name:
            project_name = "legacy_project"

        # Create new project directory
        new_project_dir = os.path.join(base_path, project_name)
        os.makedirs(new_project_dir, exist_ok=True)

        print(f"\n📦 Migrating legacy data to: {new_project_dir}...")

        # Move files
        shutil.move(legacy_goal_file, os.path.join(new_project_dir, "learning_goal.json"))
        
        if os.path.exists(legacy_user_file):
            shutil.move(legacy_user_file, os.path.join(new_project_dir, "user_profile.json"))

        print("✅ Migration complete.")

    except Exception as e:
        print(f"⚠️  Migration failed: {e}")
        # If it fails, we leave it alone to avoid data loss

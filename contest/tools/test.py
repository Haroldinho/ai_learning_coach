"""
    Example of how the tool architect would interact with genanki

"""
from anki_connection import create_anki_deck

# This is the data the Agent sends to the Python function above
cards_data = [
    {
        "front": "In Linear Programming, what is the condition for optimality in a maximization problem?",
        "back": "When all reduced costs in the objective function row are non-negative (>= 0)."
    },
    {
        "front": "Define a 'Basic Feasible Solution' (BFS).",
        "back": "A solution where the variables satisfy $Ax=b$, $x \\ge 0$, and the non-zero variables correspond to linearly independent columns of matrix A."
    },
    {
        "front": "What is the purpose of the 'Ratio Test' in the Simplex Method?",
        "back": "To determine which basic variable leaves the basis, ensuring that the new solution remains feasible (non-negative)."
    }
]

# The Agent executes the tool
import os

# Create path relative to this script
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lp_study_deck.apkg")

# The Agent executes the tool
result = create_anki_deck("Linear Programming: Simplex Basics", cards_data, filename=output_path)
print(result)
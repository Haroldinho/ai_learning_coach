import os
from graphviz import Digraph

def create_system_diagram():
    # initialize Digraph
    dot = Digraph(comment='AI Learning Coach System Architecture', format='png')
    dot.attr(rankdir='TB', size='10')
    dot.attr('node', shape='box', style='filled', fontname='Helvetica', margin='0.2')
    
    # Colors
    c_user = '#e3f2fd'       # Light Blue
    c_agent = '#e8f5e9'      # Light Green
    c_memory = '#fff9c4'     # Light Yellow
    c_artifact = '#f3e5f5'   # Light Purple
    
    # Nodes
    dot.node('User', 'User 👤', fillcolor=c_user, shape='ellipse')
    
    # Agents
    dot.node('Goal', 'GoalAgent 🎯\n(Planner)', fillcolor=c_agent)
    dot.node('Diagnostic', 'DiagnosticAgent 🩺\n(Assessor)', fillcolor=c_agent)
    dot.node('Optimizer', 'OptimizerAgent ⚡\n(Content Creator)', fillcolor=c_agent)
    dot.node('Examiner', 'ExaminerAgent 📝\n(Teacher)', fillcolor=c_agent)
    
    # State
    dot.node('Memory', 'Memory / State 🧠\n(.coin_cache)', fillcolor=c_memory, shape='cylinder')
    
    # Artifacts
    dot.node('Plan', 'Learning Plan', fillcolor=c_artifact, shape='note')
    dot.node('Anki', 'Anki Deck\n(.apkg)', fillcolor=c_artifact, shape='component')
    
    # Edges
    # Phase 1
    dot.edge('User', 'Goal', label='1. "I want to learn..."')
    dot.edge('Goal', 'Plan', label='Creates')
    dot.edge('Plan', 'Memory', label='Saves Goal')
    
    dot.edge('Plan', 'Diagnostic', label='Basis for Quiz')
    dot.edge('Diagnostic', 'User', label='2. Quiz Questions')
    dot.edge('User', 'Diagnostic', label='Answers')
    dot.edge('Diagnostic', 'Memory', label='Updates Profile')
    
    # Phase 2
    dot.edge('Memory', 'Optimizer', label='Current Milestone')
    dot.edge('Optimizer', 'Anki', label='3. Generates')
    dot.edge('Anki', 'User', label='Studies (3 days)')
    
    # Phase 3
    dot.edge('User', 'Examiner', label='4. Request Exam')
    dot.edge('Memory', 'Examiner', label='Context')
    dot.edge('Examiner', 'User', label='Questions')
    dot.edge('User', 'Examiner', label='Answers')
    dot.edge('Examiner', 'Memory', label='5. Grades & Updates')

    # Output
    output_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'figures', 'architecture_diagram')
    # Ensure dir exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    try:
        dot.render(output_path, view=False)
        print(f"Diagram generated successfully at: {output_path}.png")
    except Exception as e:
        print(f"Error generating diagram: {e}")
        print("Note: Graphviz system binaries must be installed on your machine (e.g., 'brew install graphviz').")

if __name__ == "__main__":
    create_system_diagram()

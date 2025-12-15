import re

def to_snake_case(text: str) -> str:
    """
    Converts a string to snake case.
    Example: "Learn Discrete Mathematics" -> "learn_discrete_mathematics"
    """
    # Convert to lowercase
    text = text.lower()
    # Replace non-alphanumeric characters (excluding underscores) with spaces
    text = re.sub(r'[^a-z0-9_]', ' ', text)
    # Replace whitespace with underscores
    text = re.sub(r'\s+', '_', text)
    # Strip leading/trailing underscores
    text = text.strip('_')
    return text

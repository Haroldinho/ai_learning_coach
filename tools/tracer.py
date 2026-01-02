import logging
import json
import datetime
# Configure structured logging (The 'Diary' Pillar)
logging.basicConfig(level=logging.INFO, format='%(message)s')


def log_agent_trace(step_name, inputs, outputs, error=None):
    trace_entry = {
        "timestamp": datetime.datetime.now().isoformat(),
        "span_name": step_name, # e.g., "QuizGeneration", "CriticReview"
        "inputs": str(inputs),
        "outputs": str(outputs),
        "status": "ERROR" if error else "SUCCESS",
        "error_details": str(error) if error else None
    }
    # This creates the "Trace" the whitepaper demands for debugging
    logging.info(json.dumps(trace_entry))
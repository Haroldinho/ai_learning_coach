-- 1. Users: Supports multiple students
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Subjects: Broad areas like "Linear Programming" or "French 101"
CREATE TABLE subjects (
    subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT
);

-- 3. Topics: The Knowledge Tree (Nodes)
-- 'parent_topic_id' allows you to build a dependency tree.
CREATE TABLE topics (
    topic_id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER,
    name TEXT NOT NULL, -- e.g., "Total Unimodularity"
    parent_topic_id INTEGER, -- Points to "Matrix Basics"
    proficiency_level INTEGER DEFAULT 0, -- 0=New, 1=Learning, 2=Mastered
    FOREIGN KEY(subject_id) REFERENCES subjects(subject_id),
    FOREIGN KEY(parent_topic_id) REFERENCES topics(topic_id)
);

-- 4. User_Topic_State: The "Brain" of the Agent
-- Tracks spaced repetition data (next_review_date)
CREATE TABLE user_topic_state (
    state_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    topic_id INTEGER,
    mastery_score REAL DEFAULT 0.0, -- 0.0 to 1.0
    last_reviewed DATETIME,
    next_review_due DATETIME, -- The agent queries THIS to know what to teach today
    FOREIGN KEY(user_id) REFERENCES users(user_id),
    FOREIGN KEY(topic_id) REFERENCES topics(topic_id)
);

-- 5. Quiz_Logs: Audit trail for the "Grader" agent
CREATE TABLE quiz_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    topic_id INTEGER,
    question_text TEXT,
    user_answer TEXT,
    is_correct BOOLEAN,
    agent_feedback TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
-- Sample initialization script for PostgreSQL
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100),
    payload JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO events (event_type, payload) VALUES 
('user_registered', '{"user_id": 1, "name": "Test User"}');

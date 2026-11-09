-- Create a dedicated schema for the API endpoints
CREATE SCHEMA api;

-- Create a sample table inside the schema
CREATE TABLE api.todos (
    id SERIAL PRIMARY KEY,
    task TEXT NOT NULL,
    done BOOLEAN DEFAULT false
);

-- Insert dummy data
INSERT INTO api.todos (task, done) VALUES
    ('Set up Docker Compose', true),
    ('Configure PostgREST', true),
    ('Test Swagger UI', false);

-- Create an anonymous web role for unauthenticated requests
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON api.todos TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.todos_id_seq TO web_anon;

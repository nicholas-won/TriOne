-- TriOne Database Schema
-- Initial migration

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    email TEXT NOT NULL,
    auth_id TEXT UNIQUE NOT NULL,
    subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'churned', 'past_due')),
    revenue_cat_id TEXT,
    experience_level TEXT CHECK (experience_level IN ('finisher', 'competitor')),
    unit_preference TEXT DEFAULT 'imperial' CHECK (unit_preference IN ('imperial', 'metric')),
    is_private BOOLEAN DEFAULT false,
    display_name TEXT,
    avatar_url TEXT,
    trial_ends_at TIMESTAMP WITH TIME ZONE
);

-- Biometrics table
CREATE TABLE biometrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    css_pace_per_100 INTEGER, -- seconds per 100m/yd
    run_threshold_pace_per_mile INTEGER, -- seconds per mile
    bike_ftp INTEGER, -- watts
    max_heart_rate INTEGER,
    resting_heart_rate INTEGER,
    calibration_source TEXT DEFAULT 'manual_entry' CHECK (calibration_source IN ('manual_entry', 'calibration_week', 'auto_update'))
);

-- Workout templates table (Master Library)
CREATE TABLE workout_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('swim', 'bike', 'run', 'strength', 'brick')),
    difficulty_tier INTEGER DEFAULT 3 CHECK (difficulty_tier BETWEEN 1 AND 5),
    structure_json JSONB NOT NULL,
    description TEXT
);

-- Races table
CREATE TABLE races (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    date DATE NOT NULL,
    location TEXT NOT NULL,
    distance_type TEXT NOT NULL CHECK (distance_type IN ('sprint', 'olympic', '70.3', '140.6')),
    swim_distance_meters INTEGER NOT NULL,
    bike_distance_meters INTEGER NOT NULL,
    run_distance_meters INTEGER NOT NULL,
    website_url TEXT,
    is_custom BOOLEAN DEFAULT false,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE -- Only set for custom races
);

-- Training plans table
CREATE TABLE training_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    race_date DATE NOT NULL,
    start_date DATE NOT NULL,
    race_distance_type TEXT NOT NULL CHECK (race_distance_type IN ('sprint', 'olympic', '70.3', '140.6')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    race_id UUID REFERENCES races(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workouts table
CREATE TABLE workouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES training_plans(id) ON DELETE CASCADE,
    template_id UUID REFERENCES workout_templates(id) ON DELETE SET NULL,
    scheduled_date DATE NOT NULL,
    workout_type TEXT NOT NULL CHECK (workout_type IN ('swim', 'bike', 'run', 'strength', 'brick')),
    priority_level INTEGER DEFAULT 2 CHECK (priority_level BETWEEN 1 AND 3),
    status TEXT DEFAULT 'planned' CHECK (status IN ('planned', 'completed', 'missed', 'skipped')),
    is_calibration_test BOOLEAN DEFAULT false,
    calculated_structure JSONB NOT NULL
);

-- Activity logs table
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_duration_seconds INTEGER NOT NULL,
    total_distance_meters INTEGER,
    avg_heart_rate INTEGER,
    source TEXT DEFAULT 'manual_input' CHECK (source IN ('manual_input', 'apple_health', 'active_mode_recording')),
    external_activity_id TEXT,
    route_data JSONB
);

-- Feedback logs table
CREATE TABLE feedback_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_log_id UUID REFERENCES activity_logs(id) ON DELETE CASCADE,
    comparison_ref_id UUID REFERENCES activity_logs(id) ON DELETE SET NULL,
    feedback_rating TEXT NOT NULL CHECK (feedback_rating IN ('easier', 'same', 'harder')),
    rpe_score INTEGER CHECK (rpe_score BETWEEN 1 AND 10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User training state table
CREATE TABLE user_training_state (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_fatigue_strikes INTEGER DEFAULT 0,
    last_strike_date DATE,
    acute_training_load FLOAT DEFAULT 0,
    chronic_training_load FLOAT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Friendships table
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    friend_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    UNIQUE(user_id, friend_id)
);

-- Kudos table
CREATE TABLE kudos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_log_id UUID REFERENCES activity_logs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(activity_log_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_users_auth_id ON users(auth_id);
CREATE INDEX idx_biometrics_user_id ON biometrics(user_id);
CREATE INDEX idx_workouts_plan_id ON workouts(plan_id);
CREATE INDEX idx_workouts_scheduled_date ON workouts(scheduled_date);
CREATE INDEX idx_workouts_status ON workouts(status);
CREATE INDEX idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX idx_activity_logs_workout_id ON activity_logs(workout_id);
CREATE INDEX idx_training_plans_user_id ON training_plans(user_id);
CREATE INDEX idx_training_plans_status ON training_plans(status);
CREATE INDEX idx_races_date ON races(date);
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_kudos_activity_log_id ON kudos(activity_log_id);

-- Row Level Security Policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE biometrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE kudos ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (for backend API)
CREATE POLICY "Service role has full access to users" ON users
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to biometrics" ON biometrics
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to training_plans" ON training_plans
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to workouts" ON workouts
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to activity_logs" ON activity_logs
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to feedback_logs" ON feedback_logs
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to user_training_state" ON user_training_state
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to friendships" ON friendships
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access to kudos" ON kudos
    FOR ALL USING (auth.role() = 'service_role');

-- Public read access to races (non-custom)
CREATE POLICY "Anyone can view public races" ON races
    FOR SELECT USING (is_custom = false OR user_id = auth.uid());

CREATE POLICY "Service role has full access to races" ON races
    FOR ALL USING (auth.role() = 'service_role');


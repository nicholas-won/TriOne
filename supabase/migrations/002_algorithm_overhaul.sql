-- TriOne Algorithm Overhaul Migration
-- Implements the new Scalar Injection Model and Dynamic Linked List architecture

-- ============================================
-- PART 1: Update Users Table
-- ============================================

-- Add new required fields to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS onboarding_status TEXT DEFAULT 'STARTED' 
    CHECK (onboarding_status IN ('STARTED', 'BIOMETRICS_PENDING', 'COMPLETED')),
ADD COLUMN IF NOT EXISTS training_volume_tier INTEGER DEFAULT 1 
    CHECK (training_volume_tier BETWEEN 1 AND 3),
ADD COLUMN IF NOT EXISTS calibration_method TEXT DEFAULT 'MANUAL_INPUT'
    CHECK (calibration_method IN ('MANUAL_INPUT', 'CALIBRATION_WEEK')),
ADD COLUMN IF NOT EXISTS dob DATE,
ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
ADD COLUMN IF NOT EXISTS primary_race_id UUID REFERENCES races(id) ON DELETE SET NULL;

-- Create index for primary race lookups
CREATE INDEX IF NOT EXISTS idx_users_primary_race ON users(primary_race_id);

-- ============================================
-- PART 2: Update Biometrics Table
-- ============================================

-- Add new required fields to biometrics table
ALTER TABLE biometrics
ADD COLUMN IF NOT EXISTS height_cm INTEGER,
ADD COLUMN IF NOT EXISTS weight_kg FLOAT;

-- Rename existing columns for clarity (if they exist with old names)
-- CSS is now stored as seconds per 100m (float for precision)
ALTER TABLE biometrics 
RENAME COLUMN css_pace_per_100 TO critical_swim_speed;

-- Make critical_swim_speed a FLOAT for precision
ALTER TABLE biometrics 
ALTER COLUMN critical_swim_speed TYPE FLOAT USING critical_swim_speed::FLOAT;

-- Rename FTP column
ALTER TABLE biometrics 
RENAME COLUMN bike_ftp TO functional_threshold_power;

-- Rename threshold pace column  
ALTER TABLE biometrics
RENAME COLUMN run_threshold_pace_per_mile TO threshold_run_pace;

-- Drop the old calibration_source as we now use calibration_method on users
ALTER TABLE biometrics DROP COLUMN IF EXISTS calibration_source;

-- Add unique constraint to ensure one-to-one with users
ALTER TABLE biometrics DROP CONSTRAINT IF EXISTS biometrics_user_id_unique;
ALTER TABLE biometrics ADD CONSTRAINT biometrics_user_id_unique UNIQUE (user_id);

-- ============================================
-- PART 3: Update Workouts Table for Priority Scheduler
-- ============================================

-- Add target RPE for objective fatigue tracking
ALTER TABLE workouts
ADD COLUMN IF NOT EXISTS target_rpe INTEGER CHECK (target_rpe BETWEEN 1 AND 10),
ADD COLUMN IF NOT EXISTS intensity_scalar FLOAT DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS original_template_id UUID REFERENCES workout_templates(id),
ADD COLUMN IF NOT EXISTS was_adapted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS skip_reason TEXT CHECK (skip_reason IN ('TOO_TIRED', 'SICK', 'SCHEDULE_CONFLICT', 'OTHER'));

-- ============================================
-- PART 4: Update User Training State
-- ============================================

-- Add fields for adaptation tracking
ALTER TABLE user_training_state
ADD COLUMN IF NOT EXISTS last_adaptation_date DATE,
ADD COLUMN IF NOT EXISTS total_adaptations INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS consecutive_completes INTEGER DEFAULT 0;

-- ============================================
-- PART 5: Update Feedback Logs for 2-Strike Rule
-- ============================================

-- Add target vs actual RPE tracking
ALTER TABLE feedback_logs
ADD COLUMN IF NOT EXISTS target_rpe INTEGER,
ADD COLUMN IF NOT EXISTS triggered_strike BOOLEAN DEFAULT false;

-- ============================================
-- PART 6: Create Volume Tier Configuration Table
-- ============================================

CREATE TABLE IF NOT EXISTS volume_tier_config (
    tier INTEGER PRIMARY KEY CHECK (tier BETWEEN 1 AND 3),
    min_weekly_hours FLOAT NOT NULL,
    max_weekly_hours FLOAT NOT NULL,
    swim_sessions_per_week INTEGER NOT NULL,
    bike_sessions_per_week INTEGER NOT NULL,
    run_sessions_per_week INTEGER NOT NULL,
    strength_sessions_per_week INTEGER DEFAULT 0,
    brick_sessions_per_week INTEGER DEFAULT 0,
    description TEXT NOT NULL
);

-- Insert volume tier configurations
INSERT INTO volume_tier_config (tier, min_weekly_hours, max_weekly_hours, swim_sessions_per_week, bike_sessions_per_week, run_sessions_per_week, strength_sessions_per_week, brick_sessions_per_week, description)
VALUES 
    (1, 4.0, 6.0, 1, 1, 1, 0, 1, 'Light - Finish focused'),
    (2, 7.0, 10.0, 2, 2, 2, 1, 0, 'Moderate - Performance focused'),
    (3, 11.0, 15.0, 3, 3, 3, 2, 1, 'High - Competition focused')
ON CONFLICT (tier) DO UPDATE SET
    min_weekly_hours = EXCLUDED.min_weekly_hours,
    max_weekly_hours = EXCLUDED.max_weekly_hours,
    swim_sessions_per_week = EXCLUDED.swim_sessions_per_week,
    bike_sessions_per_week = EXCLUDED.bike_sessions_per_week,
    run_sessions_per_week = EXCLUDED.run_sessions_per_week,
    strength_sessions_per_week = EXCLUDED.strength_sessions_per_week,
    brick_sessions_per_week = EXCLUDED.brick_sessions_per_week,
    description = EXCLUDED.description;

-- ============================================
-- PART 7: Create Training Phase Configuration
-- ============================================

CREATE TABLE IF NOT EXISTS training_phase_config (
    phase TEXT PRIMARY KEY CHECK (phase IN ('BASE', 'BUILD', 'PEAK', 'TAPER')),
    zone_focus TEXT NOT NULL,
    intensity_modifier FLOAT NOT NULL,
    volume_modifier FLOAT NOT NULL,
    description TEXT NOT NULL
);

INSERT INTO training_phase_config (phase, zone_focus, intensity_modifier, volume_modifier, description)
VALUES
    ('BASE', 'Zone 2', 0.85, 1.0, 'High volume, low intensity. Building aerobic foundation.'),
    ('BUILD', 'Zone 3/4', 1.0, 0.9, 'Intervals introduced. Race-specific intensity.'),
    ('PEAK', 'Zone 5', 1.1, 0.8, 'Race simulation. Highest intensity, reduced volume.'),
    ('TAPER', 'Zone 2/3', 0.9, 0.5, 'Volume decay 50-75%. Maintain intensity, maximize recovery.')
ON CONFLICT (phase) DO UPDATE SET
    zone_focus = EXCLUDED.zone_focus,
    intensity_modifier = EXCLUDED.intensity_modifier,
    volume_modifier = EXCLUDED.volume_modifier,
    description = EXCLUDED.description;

-- ============================================
-- PART 8: Create Heart Rate Zone Table
-- ============================================

CREATE TABLE IF NOT EXISTS heart_rate_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    zone_number INTEGER NOT NULL CHECK (zone_number BETWEEN 1 AND 5),
    min_hr INTEGER NOT NULL,
    max_hr INTEGER NOT NULL,
    calculation_method TEXT NOT NULL CHECK (calculation_method IN ('STANDARD', 'KARVONEN')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, zone_number)
);

-- Enable RLS on new tables
ALTER TABLE volume_tier_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_phase_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE heart_rate_zones ENABLE ROW LEVEL SECURITY;

-- Allow read access to config tables
CREATE POLICY "Anyone can read volume tier config" ON volume_tier_config
    FOR SELECT USING (true);

CREATE POLICY "Anyone can read training phase config" ON training_phase_config
    FOR SELECT USING (true);

CREATE POLICY "Service role has full access to heart_rate_zones" ON heart_rate_zones
    FOR ALL USING (auth.role() = 'service_role');

-- ============================================
-- PART 9: Update Training Plans for Phase Tracking
-- ============================================

ALTER TABLE training_plans
ADD COLUMN IF NOT EXISTS current_phase TEXT DEFAULT 'BASE' 
    CHECK (current_phase IN ('BASE', 'BUILD', 'PEAK', 'TAPER')),
ADD COLUMN IF NOT EXISTS current_week INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS total_weeks INTEGER,
ADD COLUMN IF NOT EXISTS volume_tier INTEGER DEFAULT 1;

-- ============================================
-- PART 10: Create Adaptation Log Table
-- ============================================

CREATE TABLE IF NOT EXISTS adaptation_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    trigger_reason TEXT NOT NULL CHECK (trigger_reason IN ('FATIGUE_STRIKES', 'RPE_EXCEEDED', 'COMPLIANCE', 'MANUAL')),
    fatigue_strikes_at_trigger INTEGER NOT NULL,
    workouts_affected INTEGER NOT NULL,
    actions_taken JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_adaptation_logs_user ON adaptation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_adaptation_logs_date ON adaptation_logs(triggered_at);

ALTER TABLE adaptation_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role has full access to adaptation_logs" ON adaptation_logs
    FOR ALL USING (auth.role() = 'service_role');


-- Maintenance Mode Migration
-- Adds support for maintenance/rolling base training plans

-- ============================================
-- PART 1: Add plan_type to training_plans
-- ============================================

ALTER TABLE training_plans
ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'race_prep'
    CHECK (plan_type IN ('race_prep', 'maintenance'));

-- Update existing plans to be race_prep
UPDATE training_plans
SET plan_type = 'race_prep'
WHERE plan_type IS NULL;

-- Make race_date nullable for maintenance plans
ALTER TABLE training_plans
ALTER COLUMN race_date DROP NOT NULL;

-- ============================================
-- PART 2: Add index for maintenance plan queries
-- ============================================

CREATE INDEX IF NOT EXISTS idx_training_plans_plan_type ON training_plans(plan_type, status);

-- ============================================
-- PART 3: Update RLS policies (if needed)
-- ============================================

-- RLS policies should already allow users to read their own plans
-- No changes needed here


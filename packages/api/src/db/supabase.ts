import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

// ============================================
// Database Types - Updated for Algorithm Overhaul
// ============================================

export type OnboardingStatus = 'STARTED' | 'BIOMETRICS_PENDING' | 'COMPLETED';
export type CalibrationMethod = 'MANUAL_INPUT' | 'CALIBRATION_WEEK';
export type Gender = 'MALE' | 'FEMALE' | 'OTHER';
export type TrainingPhase = 'BASE' | 'BUILD' | 'PEAK' | 'TAPER';
export type SkipReason = 'TOO_TIRED' | 'SICK' | 'SCHEDULE_CONFLICT' | 'OTHER';

export interface DbUser {
  id: string;
  created_at: string;
  email: string;
  auth_id: string;
  subscription_status: 'trial' | 'active' | 'churned' | 'past_due';
  revenue_cat_id?: string;
  experience_level?: 'finisher' | 'competitor';
  unit_preference: 'imperial' | 'metric';
  is_private: boolean;
  display_name?: string;
  avatar_url?: string;
  trial_ends_at?: string;
  // New fields for algorithm overhaul
  onboarding_status: OnboardingStatus;
  training_volume_tier: 1 | 2 | 3;
  calibration_method: CalibrationMethod;
  dob?: string; // Date of birth ISO string
  gender?: Gender;
  primary_race_id?: string;
}

export interface DbBiometrics {
  id: string;
  user_id: string;
  recorded_at: string;
  // Physical attributes
  height_cm?: number;
  weight_kg?: number;
  // The Scalars (Engine Inputs)
  critical_swim_speed?: number; // seconds per 100m
  functional_threshold_power?: number; // watts (FTP)
  threshold_run_pace?: number; // seconds per mile
  // Heart rate data
  max_heart_rate?: number;
  resting_heart_rate?: number;
}

export interface DbWorkoutTemplate {
  id: string;
  name: string;
  type: 'swim' | 'bike' | 'run' | 'strength' | 'brick';
  difficulty_tier: number;
  structure_json: {
    steps: Array<{
      type: string;
      duration: number;
      // Template coefficients (multiplied by user scalar)
      percent_ftp?: number; // e.g., 1.05 = 105% of FTP
      percent_css?: number;
      percent_tp?: number;
      target_zone?: number;
      target_rpe?: number;
      description?: string;
    }>;
    total_duration: number;
    title: string;
    description: string;
  };
  description?: string;
}

export interface DbTrainingPlan {
  id: string;
  user_id: string;
  name: string;
  race_date: string;
  start_date: string;
  race_distance_type: 'sprint' | 'olympic' | '70.3' | '140.6';
  status: 'active' | 'completed' | 'archived';
  race_id?: string;
  // New phase tracking fields
  current_phase: TrainingPhase;
  current_week: number;
  total_weeks?: number;
  volume_tier: 1 | 2 | 3;
}

export interface DbWorkout {
  id: string;
  plan_id: string;
  template_id?: string;
  scheduled_date: string;
  workout_type: 'swim' | 'bike' | 'run' | 'strength' | 'brick';
  priority_level: 1 | 2 | 3; // 1 = highest (Long), 2 = medium (Intervals), 3 = lowest (Recovery)
  status: 'planned' | 'completed' | 'missed' | 'skipped';
  is_calibration_test: boolean;
  // New fields for adaptation engine
  target_rpe?: number;
  intensity_scalar: number; // Default 1.0, reduced to 0.85 on adaptation
  original_template_id?: string;
  was_adapted: boolean;
  skip_reason?: SkipReason;
  calculated_structure: {
    steps: Array<{
      type: string;
      duration: number;
      target_wattage?: number;
      target_pace?: number; // seconds per 100m (swim) or per mile (run)
      target_heart_rate?: number;
      target_zone?: number;
      target_rpe?: number;
      description?: string;
    }>;
    total_duration: number;
    title: string;
    description: string;
  };
}

export interface DbActivityLog {
  id: string;
  workout_id: string;
  user_id: string;
  completed_at: string;
  total_duration_seconds: number;
  total_distance_meters?: number;
  avg_heart_rate?: number;
  source: 'manual_input' | 'apple_health' | 'active_mode_recording';
  external_activity_id?: string;
  route_data?: {
    coordinates: Array<{ lat: number; lng: number; timestamp: number }>;
  };
}

export interface DbFeedbackLog {
  id: string;
  activity_log_id: string;
  comparison_ref_id?: string;
  feedback_rating: 'easier' | 'same' | 'harder';
  rpe_score?: number;
  // New fields for 2-Strike tracking
  target_rpe?: number;
  triggered_strike: boolean;
}

export interface DbUserTrainingState {
  user_id: string;
  current_fatigue_strikes: number;
  last_strike_date?: string;
  acute_training_load: number;
  chronic_training_load: number;
  updated_at: string;
  // New fields
  last_adaptation_date?: string;
  total_adaptations: number;
  consecutive_completes: number;
}

export interface DbRace {
  id: string;
  name: string;
  date: string;
  location: string;
  distance_type: 'sprint' | 'olympic' | '70.3' | '140.6';
  swim_distance_meters: number;
  bike_distance_meters: number;
  run_distance_meters: number;
  website_url?: string;
  is_custom: boolean;
  user_id?: string;
}

export interface DbFriendship {
  id: string;
  user_id: string;
  friend_id: string;
  created_at: string;
  status: 'pending' | 'accepted';
}

export interface DbKudos {
  id: string;
  activity_log_id: string;
  user_id: string;
  created_at: string;
}

// New tables from algorithm overhaul

export interface DbVolumeTierConfig {
  tier: 1 | 2 | 3;
  min_weekly_hours: number;
  max_weekly_hours: number;
  swim_sessions_per_week: number;
  bike_sessions_per_week: number;
  run_sessions_per_week: number;
  strength_sessions_per_week: number;
  brick_sessions_per_week: number;
  description: string;
}

export interface DbTrainingPhaseConfig {
  phase: TrainingPhase;
  zone_focus: string;
  intensity_modifier: number;
  volume_modifier: number;
  description: string;
}

export interface DbHeartRateZone {
  id: string;
  user_id: string;
  zone_number: 1 | 2 | 3 | 4 | 5;
  min_hr: number;
  max_hr: number;
  calculation_method: 'STANDARD' | 'KARVONEN';
  created_at: string;
}

export interface DbAdaptationLog {
  id: string;
  user_id: string;
  triggered_at: string;
  trigger_reason: 'FATIGUE_STRIKES' | 'RPE_EXCEEDED' | 'COMPLIANCE' | 'MANUAL';
  fatigue_strikes_at_trigger: number;
  workouts_affected: number;
  actions_taken: {
    intensity_cuts: string[];
    volume_conversions: string[];
    notifications_sent: boolean;
  };
}

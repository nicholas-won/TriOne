/**
 * Calibration Week Generator
 * 
 * Generates the 3 calibration test workouts when a user chooses "Test Me"
 * instead of providing manual biometrics.
 * 
 * Tests Generated:
 * 1. 400m Swim Test -> Calculates CSS
 * 2. 20min Bike Test -> Calculates FTP
 * 3. 1 Mile Run Test -> Calculates Threshold Pace
 */

import { v4 as uuid } from 'uuid';
import { supabase, DbWorkout, DbTrainingPlan } from '../db/supabase';
import { calculateCSS, calculateFTP, calculateThresholdPace } from './biometricsCalculator';

// ============================================
// Calibration Week Generator
// ============================================

/**
 * Generate a calibration week for a user
 * Creates 3 test workouts: Swim, Bike, Run
 */
export async function generateCalibrationWeek(
  userId: string,
  raceId: string | null,
  raceDistance: 'sprint' | 'olympic' | '70.3' | '140.6',
  volumeTier: 1 | 2 | 3
): Promise<DbTrainingPlan> {
  
  // Calculate dates
  const startDate = getNextMonday();
  const raceDate = raceId 
    ? await getRaceDate(raceId) 
    : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000); // Default 90 days out

  // Create the calibration plan
  const planId = uuid();
  const { data: plan, error: planError } = await supabase
    .from('training_plans')
    .insert({
      id: planId,
      user_id: userId,
      name: 'Calibration Week',
      race_date: raceDate.toISOString().split('T')[0],
      start_date: startDate.toISOString().split('T')[0],
      race_distance_type: raceDistance,
      status: 'active',
      race_id: raceId,
      current_phase: 'BASE',
      current_week: 0, // Week 0 = Calibration
      total_weeks: null, // Will be set after calibration
      volume_tier: volumeTier,
    })
    .select()
    .single();

  if (planError || !plan) {
    throw new Error('Failed to create calibration plan');
  }

  // Generate the 3 calibration workouts
  const workouts = createCalibrationWorkouts(planId, startDate);

  // Insert workouts
  const { error: workoutsError } = await supabase
    .from('workouts')
    .insert(workouts);

  if (workoutsError) {
    throw new Error('Failed to create calibration workouts');
  }

  console.log(`✅ Calibration week created for user ${userId}`);
  console.log(`   - 3 test workouts scheduled`);
  console.log(`   - Starting: ${startDate.toISOString().split('T')[0]}`);

  return plan;
}

/**
 * Create the 3 calibration test workouts
 */
function createCalibrationWorkouts(planId: string, startDate: Date): Partial<DbWorkout>[] {
  const workouts: Partial<DbWorkout>[] = [];
  const monday = new Date(startDate);

  // ========================================
  // DAY 1 (Monday) - 400m Swim Time Trial
  // ========================================
  workouts.push({
    id: uuid(),
    plan_id: planId,
    scheduled_date: monday.toISOString().split('T')[0],
    workout_type: 'swim',
    priority_level: 2,
    status: 'planned',
    is_calibration_test: true,
    target_rpe: 9,
    intensity_scalar: 1.0,
    was_adapted: false,
    calculated_structure: {
      steps: [
        {
          type: 'warmup',
          duration: 600, // 10 mins
          description: 'Easy swimming - mix of freestyle and drill work',
          target_zone: 1,
          target_rpe: 3,
        },
        {
          type: 'main',
          duration: 420, // 7 mins max
          description: '400m TIME TRIAL - Swim as fast as you can maintain for 400m! Record your exact time.',
          target_zone: 5,
          target_rpe: 9,
        },
        {
          type: 'rest',
          duration: 180, // 3 mins
          description: 'Rest and recover',
          target_zone: 1,
        },
        {
          type: 'cooldown',
          duration: 300, // 5 mins
          description: 'Easy swimming to flush out lactate',
          target_zone: 1,
          target_rpe: 2,
        },
      ],
      total_duration: 1500, // 25 mins
      title: '🏊 Swim Test: 400m Time Trial',
      description: 'Today we establish your Critical Swim Speed (CSS). After a proper warm-up, swim 400 meters as fast as you can SUSTAIN (not sprint). Your CSS = (400m time ÷ 4) + 3 seconds.',
    },
  });

  // ========================================
  // DAY 2 (Tuesday) - Rest
  // ========================================

  // ========================================
  // DAY 3 (Wednesday) - 20min Bike FTP Test
  // ========================================
  const wednesday = new Date(monday);
  wednesday.setDate(wednesday.getDate() + 2);

  workouts.push({
    id: uuid(),
    plan_id: planId,
    scheduled_date: wednesday.toISOString().split('T')[0],
    workout_type: 'bike',
    priority_level: 2,
    status: 'planned',
    is_calibration_test: true,
    target_rpe: 9,
    intensity_scalar: 1.0,
    was_adapted: false,
    calculated_structure: {
      steps: [
        {
          type: 'warmup',
          duration: 600, // 10 mins
          description: 'Easy spinning, gradually increasing effort',
          target_zone: 1,
          target_rpe: 2,
        },
        {
          type: 'interval',
          duration: 60, // 1 min
          description: 'Hard effort to open up the legs',
          target_zone: 4,
          target_rpe: 7,
        },
        {
          type: 'rest',
          duration: 300, // 5 mins
          description: 'Easy spinning recovery',
          target_zone: 1,
          target_rpe: 2,
        },
        {
          type: 'main',
          duration: 1200, // 20 mins
          description: '20 MINUTE MAX EFFORT - Ride at the HIGHEST power you can SUSTAIN for 20 minutes! Record your average power.',
          target_zone: 4,
          target_rpe: 9,
        },
        {
          type: 'cooldown',
          duration: 600, // 10 mins
          description: 'Easy spinning to recover',
          target_zone: 1,
          target_rpe: 2,
        },
      ],
      total_duration: 2760, // 46 mins
      title: '🚴 Bike Test: 20-Minute FTP Test',
      description: 'Today we establish your Functional Threshold Power (FTP). After warming up, ride at the HARDEST effort you can sustain for exactly 20 minutes. Your FTP = Average Power × 0.95.',
    },
  });

  // ========================================
  // DAY 4 (Thursday) - Rest
  // ========================================

  // ========================================
  // DAY 5 (Friday) - 1 Mile Run Time Trial
  // ========================================
  const friday = new Date(monday);
  friday.setDate(friday.getDate() + 4);

  workouts.push({
    id: uuid(),
    plan_id: planId,
    scheduled_date: friday.toISOString().split('T')[0],
    workout_type: 'run',
    priority_level: 2,
    status: 'planned',
    is_calibration_test: true,
    target_rpe: 9,
    intensity_scalar: 1.0,
    was_adapted: false,
    calculated_structure: {
      steps: [
        {
          type: 'warmup',
          duration: 600, // 10 mins
          description: 'Easy jogging with dynamic stretches',
          target_zone: 1,
          target_rpe: 3,
        },
        {
          type: 'interval',
          duration: 60, // 4 x 15 sec strides
          description: '4 x 15-second strides at 80% effort with easy jog recovery',
          target_zone: 3,
          target_rpe: 5,
        },
        {
          type: 'rest',
          duration: 180, // 3 mins
          description: 'Easy walking/jogging',
          target_zone: 1,
        },
        {
          type: 'main',
          duration: 600, // 10 mins max
          description: '1 MILE TIME TRIAL - Run 1 mile as FAST as you can! Record your exact time.',
          target_zone: 5,
          target_rpe: 9,
        },
        {
          type: 'cooldown',
          duration: 600, // 10 mins
          description: 'Easy jogging to cool down',
          target_zone: 1,
          target_rpe: 2,
        },
      ],
      total_duration: 2040, // 34 mins
      title: '🏃 Run Test: 1 Mile Time Trial',
      description: 'Today we establish your Threshold Pace. After warming up, run exactly 1 mile as FAST as you can. Your Threshold Pace = Mile Time × 1.15 (converts anaerobic pace to aerobic threshold).',
    },
  });

  // ========================================
  // DAY 6 (Saturday) - Recovery Spin
  // ========================================
  const saturday = new Date(monday);
  saturday.setDate(saturday.getDate() + 5);

  workouts.push({
    id: uuid(),
    plan_id: planId,
    scheduled_date: saturday.toISOString().split('T')[0],
    workout_type: 'bike',
    priority_level: 3,
    status: 'planned',
    is_calibration_test: false,
    target_rpe: 3,
    intensity_scalar: 1.0,
    was_adapted: false,
    calculated_structure: {
      steps: [
        {
          type: 'main',
          duration: 2400, // 40 mins
          description: 'Easy spinning - keep it relaxed! Recovery from testing.',
          target_zone: 1,
          target_rpe: 3,
        },
      ],
      total_duration: 2400,
      title: '🚴 Recovery Spin',
      description: 'Active recovery after your testing. Keep the effort very light - this is about blood flow, not fitness.',
    },
  });

  // ========================================
  // DAY 7 (Sunday) - Recovery Jog
  // ========================================
  const sunday = new Date(monday);
  sunday.setDate(sunday.getDate() + 6);

  workouts.push({
    id: uuid(),
    plan_id: planId,
    scheduled_date: sunday.toISOString().split('T')[0],
    workout_type: 'run',
    priority_level: 3,
    status: 'planned',
    is_calibration_test: false,
    target_rpe: 3,
    intensity_scalar: 1.0,
    was_adapted: false,
    calculated_structure: {
      steps: [
        {
          type: 'main',
          duration: 1800, // 30 mins
          description: 'Easy jogging - conversational pace only!',
          target_zone: 1,
          target_rpe: 3,
        },
      ],
      total_duration: 1800,
      title: '🏃 Recovery Jog',
      description: 'Easy jog to finish your calibration week. Your personalized training plan starts next week!',
    },
  });

  return workouts;
}

// ============================================
// Process Calibration Results
// ============================================

export interface CalibrationResult {
  testType: 'swim_400m' | 'bike_20min' | 'run_1mile';
  result: number; // time in seconds or average power in watts
  heartRate?: number;
}

/**
 * Process a single calibration test result
 * Updates biometrics and checks if all tests are complete
 */
export async function processCalibrationResult(
  userId: string,
  result: CalibrationResult
): Promise<{
  calculatedValue: number;
  metric: string;
  allTestsComplete: boolean;
}> {
  let calculatedValue: number;
  let metric: string;
  let updateField: string;

  switch (result.testType) {
    case 'swim_400m':
      // CSS (sec/100m) = (Time_400m / 4) + 3.0
      calculatedValue = calculateCSS(result.result);
      metric = 'Critical Swim Speed';
      updateField = 'critical_swim_speed';
      break;

    case 'bike_20min':
      // FTP = Average Power × 0.95
      calculatedValue = calculateFTP(result.result);
      metric = 'Functional Threshold Power';
      updateField = 'functional_threshold_power';
      break;

    case 'run_1mile':
      // Threshold Pace = Mile Time × 1.15
      calculatedValue = calculateThresholdPace(result.result);
      metric = 'Threshold Run Pace';
      updateField = 'threshold_run_pace';
      break;

    default:
      throw new Error('Unknown test type');
  }

  // Update biometrics
  await supabase
    .from('biometrics')
    .update({
      [updateField]: calculatedValue,
      recorded_at: new Date().toISOString(),
    })
    .eq('user_id', userId);

  // Check if all tests are complete
  const { data: biometrics } = await supabase
    .from('biometrics')
    .select('critical_swim_speed, functional_threshold_power, threshold_run_pace')
    .eq('user_id', userId)
    .single();

  const allTestsComplete = !!(
    biometrics?.critical_swim_speed &&
    biometrics?.functional_threshold_power &&
    biometrics?.threshold_run_pace
  );

  if (allTestsComplete) {
    // Update user's onboarding status
    await supabase
      .from('users')
      .update({
        onboarding_status: 'COMPLETED',
        calibration_method: 'CALIBRATION_WEEK',
      })
      .eq('id', userId);

    console.log(`✅ All calibration tests complete for user ${userId}`);
    console.log(`   CSS: ${biometrics?.critical_swim_speed} sec/100m`);
    console.log(`   FTP: ${biometrics?.functional_threshold_power} watts`);
    console.log(`   TP: ${biometrics?.threshold_run_pace} sec/mile`);
  }

  return {
    calculatedValue,
    metric,
    allTestsComplete,
  };
}

/**
 * After calibration is complete, generate the full training plan
 */
export async function finishCalibrationAndGeneratePlan(userId: string): Promise<void> {
  // Import dynamically to avoid circular dependency
  const { generateTrainingPlan } = await import('./planGenerator');

  // Get user data
  const { data: user } = await supabase
    .from('users')
    .select('*, biometrics(*)')
    .eq('id', userId)
    .single();

  if (!user) {
    throw new Error('User not found');
  }

  // Get current calibration plan
  const { data: calibrationPlan } = await supabase
    .from('training_plans')
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'active')
    .single();

  if (!calibrationPlan) {
    throw new Error('No active calibration plan found');
  }

  // Archive the calibration plan
  await supabase
    .from('training_plans')
    .update({ status: 'archived' })
    .eq('id', calibrationPlan.id);

  // Generate full training plan
  await generateTrainingPlan({
    userId: user.id,
    raceId: calibrationPlan.race_id,
    raceDistance: calibrationPlan.race_distance_type,
    volumeTier: calibrationPlan.volume_tier,
    biometrics: user.biometrics,
    needsCalibration: false,
  });

  console.log(`🎉 Full training plan generated for user ${userId} after calibration`);
}

// ============================================
// Helpers
// ============================================

function getNextMonday(): Date {
  const today = new Date();
  const dayOfWeek = today.getDay();
  const daysUntilMonday = dayOfWeek === 0 ? 1 : 8 - dayOfWeek;
  const nextMonday = new Date(today);
  nextMonday.setDate(today.getDate() + daysUntilMonday);
  return nextMonday;
}

async function getRaceDate(raceId: string): Promise<Date> {
  const { data: race } = await supabase
    .from('races')
    .select('date')
    .eq('id', raceId)
    .single();

  return race ? new Date(race.date) : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
}

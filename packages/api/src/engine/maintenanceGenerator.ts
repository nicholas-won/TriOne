/**
 * Maintenance Plan Generator
 * 
 * Generates a "Rolling Base" schedule for users without a specific race.
 * Uses a 4-week repeating cycle: 3 weeks load, 1 week recovery.
 */

import { supabase, DbWorkout, DbTrainingPlan, DbWorkoutTemplate, DbBiometrics } from '../db/supabase';
import { v4 as uuid } from 'uuid';
import { generateWorkoutFromTemplate } from './workoutGenerator';

// ============================================
// Types
// ============================================

interface MaintenancePlanParams {
  userId: string;
  volumeTier: 1 | 2 | 3;
  biometrics: Partial<DbBiometrics>;
}

interface WeekPattern {
  weekNumber: number; // 1-4 (repeating)
  volumeModifier: number; // 1.0 for load weeks, 0.7 for recovery
  intensityModifier: number; // 0.85 for maintenance
  zoneFocus: 'Zone 2' | 'Zone 3';
}

// ============================================
// Maintenance Week Patterns
// ============================================

const MAINTENANCE_PATTERNS: WeekPattern[] = [
  { weekNumber: 1, volumeModifier: 1.0, intensityModifier: 0.85, zoneFocus: 'Zone 2' },
  { weekNumber: 2, volumeModifier: 1.0, intensityModifier: 0.85, zoneFocus: 'Zone 2' },
  { weekNumber: 3, volumeModifier: 1.0, intensityModifier: 0.85, zoneFocus: 'Zone 3' },
  { weekNumber: 4, volumeModifier: 0.7, intensityModifier: 0.85, zoneFocus: 'Zone 2' }, // Recovery week
];

// Volume tiers for maintenance (slightly reduced from race prep)
const MAINTENANCE_VOLUME_TIERS = {
  1: { swim: 1, bike: 1, run: 1, strength: 0 },
  2: { swim: 2, bike: 2, run: 2, strength: 1 },
  3: { swim: 2, bike: 3, run: 2, strength: 1 },
};

// ============================================
// Main Functions
// ============================================

/**
 * Generate or update maintenance plan
 */
export async function generateMaintenancePlan(params: MaintenancePlanParams): Promise<DbTrainingPlan> {
  const { userId, volumeTier, biometrics } = params;

  console.log(`🔄 Generating maintenance plan for user ${userId}`);

  // Check if user already has an active maintenance plan
  const { data: existingPlan } = await supabase
    .from('training_plans')
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'active')
    .eq('plan_type', 'maintenance')
    .single();

  const startDate = getNextMonday();
  const planId = existingPlan?.id || uuid();

  // Create or update the plan
  const planData: Partial<DbTrainingPlan> = {
    id: planId,
    user_id: userId,
    name: 'Maintenance Training',
    race_date: null, // No race date for maintenance
    start_date: startDate.toISOString().split('T')[0],
    race_distance_type: 'olympic', // Default, not used in maintenance
    status: 'active',
    race_id: null,
    plan_type: 'maintenance',
    current_phase: 'BASE',
    current_week: 1,
    total_weeks: null, // Infinite/rolling
    volume_tier: volumeTier,
  };

  if (existingPlan) {
    await supabase
      .from('training_plans')
      .update(planData)
      .eq('id', planId);
  } else {
    await supabase
      .from('training_plans')
      .insert(planData);
  }

  // Generate initial 2 weeks of workouts
  await generateMaintenanceWorkouts(planId, startDate, volumeTier, biometrics, 2);

  console.log(`✅ Maintenance plan created/updated for user ${userId}`);

  return planData as DbTrainingPlan;
}

/**
 * Generate maintenance workouts for specified number of weeks
 */
export async function generateMaintenanceWorkouts(
  planId: string,
  startDate: Date,
  volumeTier: 1 | 2 | 3,
  biometrics: Partial<DbBiometrics>,
  weeksToGenerate: number = 2
): Promise<void> {
  const workouts: Partial<DbWorkout>[] = [];
  const volumeConfig = MAINTENANCE_VOLUME_TIERS[volumeTier];

  // Get workout templates
  const { data: templates } = await supabase
    .from('workout_templates')
    .select('*');

  const templatesByType: Record<string, DbWorkoutTemplate[]> = {};
  templates?.forEach(t => {
    if (!templatesByType[t.type]) templatesByType[t.type] = [];
    templatesByType[t.type].push(t);
  });

  let currentDate = new Date(startDate);

  for (let weekOffset = 0; weekOffset < weeksToGenerate; weekOffset++) {
    const weekNumber = (weekOffset % 4) + 1; // 1-4 repeating cycle
    const pattern = MAINTENANCE_PATTERNS[weekNumber - 1];

    // Generate workouts for this week
    const weekWorkouts = generateMaintenanceWeek(
      planId,
      currentDate,
      volumeConfig,
      pattern,
      templatesByType,
      biometrics
    );

    workouts.push(...weekWorkouts);

    // Move to next Monday
    currentDate = new Date(currentDate);
    currentDate.setDate(currentDate.getDate() + 7);
  }

  // Insert workouts
  if (workouts.length > 0) {
    const { error: workoutsError } = await supabase
      .from('workouts')
      .insert(workouts);

    if (workoutsError) {
      console.error('Failed to insert maintenance workouts:', workoutsError);
      throw new Error('Failed to generate maintenance workouts');
    }
  }

  console.log(`✅ Generated ${workouts.length} maintenance workouts`);
}

/**
 * Generate workouts for a single maintenance week
 */
function generateMaintenanceWeek(
  planId: string,
  weekStart: Date,
  volumeConfig: { swim: number; bike: number; run: number; strength: number },
  pattern: WeekPattern,
  templatesByType: Record<string, DbWorkoutTemplate[]>,
  biometrics: Partial<DbBiometrics>
): Partial<DbWorkout>[] {
  const workouts: Partial<DbWorkout>[] = [];
  let currentDate = new Date(weekStart);

  // Determine workout schedule for the week
  const schedule: Array<{ day: number; type: string }> = [];
  
  // Monday: Swim
  if (volumeConfig.swim > 0) {
    schedule.push({ day: 0, type: 'swim' });
  }
  
  // Tuesday: Bike
  if (volumeConfig.bike > 0) {
    schedule.push({ day: 1, type: 'bike' });
  }
  
  // Wednesday: Run
  if (volumeConfig.run > 0) {
    schedule.push({ day: 2, type: 'run' });
  }
  
  // Thursday: Swim (if tier 2+)
  if (volumeConfig.swim > 1) {
    schedule.push({ day: 3, type: 'swim' });
  }
  
  // Friday: Bike (if tier 2+)
  if (volumeConfig.bike > 1) {
    schedule.push({ day: 4, type: 'bike' });
  }
  
  // Saturday: Run (if tier 2+)
  if (volumeConfig.run > 1) {
    schedule.push({ day: 5, type: 'run' });
  }
  
  // Sunday: Rest (always)

  // Generate workouts based on schedule
  for (const item of schedule) {
    const workoutDate = new Date(currentDate);
    workoutDate.setDate(workoutDate.getDate() + item.day);

    const availableTemplates = templatesByType[item.type] || [];
    
    // Select template based on zone focus and week pattern
    const template = selectMaintenanceTemplate(
      availableTemplates,
      pattern.zoneFocus,
      pattern.weekNumber === 4 // Recovery week
    );

    if (template) {
      // Convert DbBiometrics to format expected by generateWorkoutFromTemplate
      const workoutBiometrics = {
        bike_ftp: biometrics.functional_threshold_power,
        css_pace_per_100: biometrics.critical_swim_speed,
        run_threshold_pace_per_mile: biometrics.threshold_run_pace,
        max_heart_rate: biometrics.max_heart_rate,
      };

      const workout = generateWorkoutFromTemplate(
        planId,
        template,
        workoutDate.toISOString().split('T')[0],
        2, // Priority 2 (moderate) for maintenance
        workoutBiometrics,
        'BASE' // Always BASE phase for maintenance
      );

      // Apply volume modifier for recovery week
      if (pattern.volumeModifier < 1.0 && workout.calculated_structure) {
        workout.calculated_structure.steps = workout.calculated_structure.steps.map(step => ({
          ...step,
          duration: Math.round(step.duration * pattern.volumeModifier),
        }));
        workout.calculated_structure.total_duration = workout.calculated_structure.steps.reduce(
          (sum, s) => sum + s.duration,
          0
        );
      }

      workouts.push(workout);
    }
  }

  return workouts;
}

/**
 * Select appropriate template for maintenance week
 */
function selectMaintenanceTemplate(
  templates: DbWorkoutTemplate[],
  zoneFocus: 'Zone 2' | 'Zone 3',
  isRecoveryWeek: boolean
): DbWorkoutTemplate | null {
  if (templates.length === 0) return null;

  // For recovery week, prefer Zone 2 templates
  if (isRecoveryWeek) {
    const zone2Templates = templates.filter(t => 
      t.structure_json.steps.some(s => (s.target_zone || 2) <= 2)
    );
    return zone2Templates[0] || templates[0];
  }

  // For load weeks, match zone focus
  if (zoneFocus === 'Zone 2') {
    const zone2Templates = templates.filter(t => 
      t.structure_json.steps.some(s => (s.target_zone || 2) <= 2)
    );
    return zone2Templates[0] || templates[0];
  } else {
    // Zone 3 - allow some tempo work
    const zone3Templates = templates.filter(t => 
      t.structure_json.steps.some(s => (s.target_zone || 2) === 3)
    );
    return zone3Templates[0] || templates[0];
  }
}

/**
 * Get next Monday from today
 */
function getNextMonday(): Date {
  const today = new Date();
  const dayOfWeek = today.getDay();
  const daysUntilMonday = dayOfWeek === 0 ? 1 : (8 - dayOfWeek) % 7 || 7;
  const nextMonday = new Date(today);
  nextMonday.setDate(today.getDate() + daysUntilMonday);
  nextMonday.setHours(0, 0, 0, 0);
  return nextMonday;
}

/**
 * Check if maintenance plan needs more workouts generated
 * Called by cron job
 */
export async function checkAndGenerateMaintenanceWorkouts(): Promise<{
  plansChecked: number;
  weeksGenerated: number;
}> {
  let plansChecked = 0;
  let weeksGenerated = 0;

  // Get all active maintenance plans
  const { data: plans } = await supabase
    .from('training_plans')
    .select('*')
    .eq('status', 'active')
    .eq('plan_type', 'maintenance');

  if (!plans || plans.length === 0) {
    return { plansChecked: 0, weeksGenerated: 0 };
  }

  for (const plan of plans) {
    plansChecked++;

    // Get latest workout date
    const { data: latestWorkout } = await supabase
      .from('workouts')
      .select('scheduled_date')
      .eq('plan_id', plan.id)
      .order('scheduled_date', { ascending: false })
      .limit(1)
      .single();

    if (!latestWorkout) {
      // No workouts yet, generate initial weeks
      const startDate = new Date(plan.start_date);
      const { data: biometrics } = await supabase
        .from('biometrics')
        .select('*')
        .eq('user_id', plan.user_id)
        .order('recorded_at', { ascending: false })
        .limit(1)
        .single();

      await generateMaintenanceWorkouts(
        plan.id,
        startDate,
        plan.volume_tier,
        biometrics || {},
        2
      );
      weeksGenerated += 2;
      continue;
    }

    // Calculate days until we need more workouts (14 days ahead)
    const latestDate = new Date(latestWorkout.scheduled_date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const daysUntilLatest = Math.floor((latestDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

    if (daysUntilLatest < 14) {
      // Need to generate more workouts
      const weeksNeeded = Math.ceil((14 - daysUntilLatest) / 7);
      
      // Get next Monday after latest workout
      const nextMonday = new Date(latestDate);
      nextMonday.setDate(latestDate.getDate() + 7);
      while (nextMonday.getDay() !== 1) {
        nextMonday.setDate(nextMonday.getDate() + 1);
      }

      const { data: biometrics } = await supabase
        .from('biometrics')
        .select('*')
        .eq('user_id', plan.user_id)
        .order('recorded_at', { ascending: false })
        .limit(1)
        .single();

      await generateMaintenanceWorkouts(
        plan.id,
        nextMonday,
        plan.volume_tier,
        biometrics || {},
        weeksNeeded
      );
      weeksGenerated += weeksNeeded;
    }
  }

  return { plansChecked, weeksGenerated };
}


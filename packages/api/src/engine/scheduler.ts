/**
 * Priority Scheduler
 * 
 * Handles missed workout logic and rescheduling.
 * Designed to be run as a daily cron job at 00:01 local time.
 */

import { supabase, DbWorkout } from '../db/supabase';

// ============================================
// Priority System
// ============================================

// Priority 1 = Highest (Long workouts - most important for endurance building)
// Priority 2 = Medium (Intervals/Tempo - important for fitness)
// Priority 3 = Lowest (Recovery/Easy - can be safely skipped)

const PRIORITY_NAMES: Record<number, string> = {
  1: 'Long/Key',
  2: 'Intervals/Tempo',
  3: 'Recovery/Easy',
};

// ============================================
// Main Scheduler Function
// ============================================

/**
 * Process missed workouts from yesterday
 * 
 * Logic Flow:
 * 1. Gate 1: If missed workout is Priority 3 (Recovery) -> DELETE
 * 2. Gate 2: If missed Priority < today's Priority -> Swap
 * 3. Gate 3: Safety check for back-to-back high intensity
 * 
 * @returns Summary of actions taken
 */
export async function processMissedWorkouts(): Promise<{
  processed: number;
  deleted: number;
  rescheduled: number;
  bumped: number;
}> {
  const result = {
    processed: 0,
    deleted: 0,
    rescheduled: 0,
    bumped: 0,
  };

  // Get yesterday's date
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split('T')[0];

  const today = new Date().toISOString().split('T')[0];

  console.log(`📅 Scheduler running for missed workouts from ${yesterdayStr}`);

  // Find all users with missed workouts from yesterday
  const { data: missedWorkouts, error } = await supabase
    .from('workouts')
    .select(`
      *,
      training_plans!inner(user_id, status)
    `)
    .eq('scheduled_date', yesterdayStr)
    .eq('status', 'planned') // Still planned = missed
    .eq('training_plans.status', 'active');

  if (error) {
    console.error('Error fetching missed workouts:', error);
    return result;
  }

  if (!missedWorkouts || missedWorkouts.length === 0) {
    console.log('✅ No missed workouts to process');
    return result;
  }

  console.log(`Found ${missedWorkouts.length} missed workout(s)`);

  for (const missedWorkout of missedWorkouts) {
    result.processed++;
    const userId = missedWorkout.training_plans.user_id;

    // Gate 1: Priority 3 (Recovery/Easy) -> Just delete it
    if (missedWorkout.priority_level === 3) {
      await markWorkoutMissed(missedWorkout.id, 'Low priority - auto-deleted');
      result.deleted++;
      console.log(`  🗑️ Deleted low-priority workout: ${missedWorkout.id}`);
      continue;
    }

    // Get today's workout for this user's plan
    const { data: todayWorkout } = await supabase
      .from('workouts')
      .select('*')
      .eq('plan_id', missedWorkout.plan_id)
      .eq('scheduled_date', today)
      .eq('status', 'planned')
      .single();

    // Gate 3: Safety check - prevent back-to-back high intensity
    if (missedWorkout.priority_level <= 2) {
      // Check if this is an interval workout
      const isIntervalMissed = isIntervalWorkout(missedWorkout);
      const isIntervalToday = todayWorkout && isIntervalWorkout(todayWorkout);

      if (isIntervalMissed && isIntervalToday) {
        // Can't do intervals back-to-back - delete the missed one
        await markWorkoutMissed(missedWorkout.id, 'Safety: Cannot stack interval sessions');
        result.deleted++;
        console.log(`  ⚠️ Safety delete (back-to-back intervals): ${missedWorkout.id}`);
        continue;
      }
    }

    // Gate 2: Priority comparison and swap
    if (todayWorkout) {
      // Lower number = higher priority
      if (missedWorkout.priority_level < todayWorkout.priority_level) {
        // Missed workout is MORE important than today's
        // Move missed to today, bump today's workout
        await rescheduleWorkout(missedWorkout.id, today);
        await handleBumpedWorkout(todayWorkout);
        result.rescheduled++;
        result.bumped++;
        console.log(`  ↔️ Swapped: ${missedWorkout.id} (P${missedWorkout.priority_level}) moved to today, ${todayWorkout.id} (P${todayWorkout.priority_level}) bumped`);
      } else {
        // Today's workout is more important or equal - delete the missed one
        await markWorkoutMissed(missedWorkout.id, 'Lower priority than scheduled workout');
        result.deleted++;
        console.log(`  🗑️ Deleted (lower priority): ${missedWorkout.id}`);
      }
    } else {
      // No workout scheduled for today - just reschedule the missed one
      await rescheduleWorkout(missedWorkout.id, today);
      result.rescheduled++;
      console.log(`  📅 Rescheduled to today: ${missedWorkout.id}`);
    }
  }

  console.log(`\n📊 Scheduler Summary:`);
  console.log(`   Processed: ${result.processed}`);
  console.log(`   Rescheduled: ${result.rescheduled}`);
  console.log(`   Deleted: ${result.deleted}`);
  console.log(`   Bumped: ${result.bumped}`);

  return result;
}

// ============================================
// Helper Functions
// ============================================

/**
 * Check if a workout is an interval/high-intensity session
 */
function isIntervalWorkout(workout: DbWorkout): boolean {
  // Check by priority
  if (workout.priority_level <= 2) {
    // Check structure for interval steps
    const hasIntervals = workout.calculated_structure.steps.some(
      (step) => step.type === 'interval' || (step.target_zone && step.target_zone >= 4)
    );
    return hasIntervals;
  }
  return false;
}

/**
 * Mark a workout as missed
 */
async function markWorkoutMissed(workoutId: string, reason: string): Promise<void> {
  await supabase
    .from('workouts')
    .update({
      status: 'missed',
      skip_reason: 'SCHEDULE_CONFLICT' as const,
    })
    .eq('id', workoutId);
}

/**
 * Reschedule a workout to a new date
 */
async function rescheduleWorkout(workoutId: string, newDate: string): Promise<void> {
  await supabase
    .from('workouts')
    .update({
      scheduled_date: newDate,
    })
    .eq('id', workoutId);
}

/**
 * Handle a bumped workout - try to find a rest day or delete
 */
async function handleBumpedWorkout(workout: DbWorkout): Promise<void> {
  // Try to find next available rest day within 3 days
  const { data: nextDays } = await supabase
    .from('workouts')
    .select('scheduled_date')
    .eq('plan_id', workout.plan_id)
    .eq('status', 'planned')
    .gte('scheduled_date', new Date().toISOString().split('T')[0])
    .order('scheduled_date', { ascending: true })
    .limit(7);

  const scheduledDates = new Set(nextDays?.map((w) => w.scheduled_date) || []);

  // Find first gap (rest day) in the next 3 days
  for (let i = 1; i <= 3; i++) {
    const checkDate = new Date();
    checkDate.setDate(checkDate.getDate() + i);
    const checkDateStr = checkDate.toISOString().split('T')[0];

    if (!scheduledDates.has(checkDateStr)) {
      // Found a rest day - reschedule here
      await rescheduleWorkout(workout.id, checkDateStr);
      console.log(`    → Bumped workout ${workout.id} moved to rest day ${checkDateStr}`);
      return;
    }
  }

  // No rest day found - must delete the bumped workout
  // Priority 3 workouts get deleted, others get marked missed
  if (workout.priority_level === 3) {
    await markWorkoutMissed(workout.id, 'Bumped - no available slot');
    console.log(`    → Bumped workout ${workout.id} deleted (low priority)`);
  } else {
    // Keep higher priority workouts as is - they'll be handled next day
    console.log(`    → Bumped workout ${workout.id} remains (high priority)`);
  }
}

// ============================================
// Cron Job Entry Point
// ============================================

/**
 * Main function to be called by cron job
 * Run daily at 00:01 local time
 */
export async function runDailyScheduler(): Promise<void> {
  console.log('='.repeat(50));
  console.log(`🕐 Daily Scheduler Started: ${new Date().toISOString()}`);
  console.log('='.repeat(50));

  try {
    const result = await processMissedWorkouts();
    console.log('\n✅ Scheduler completed successfully');
  } catch (error) {
    console.error('❌ Scheduler error:', error);
  }

  console.log('='.repeat(50));
}

// ============================================
// Manual Trigger Endpoint Handler
// ============================================

/**
 * For testing - manually trigger scheduler for a specific date
 */
export async function triggerSchedulerForDate(dateStr: string): Promise<{
  processed: number;
  deleted: number;
  rescheduled: number;
  bumped: number;
}> {
  console.log(`📅 Manual scheduler trigger for date: ${dateStr}`);
  
  // Temporarily override the date logic
  // This would need to be implemented with date injection
  // For now, just run the normal scheduler
  return processMissedWorkouts();
}


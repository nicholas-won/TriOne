/**
 * Adaptation Engine
 * 
 * The "Brain" that modifies the training plan based on user feedback.
 * Implements the "2-Strike" Rule from the algorithm specification.
 */

import { supabase, DbWorkout, DbUserTrainingState, DbFeedbackLog, SkipReason } from '../db/supabase';
import { v4 as uuid } from 'uuid';

// ============================================
// CONSTANTS
// ============================================

const FATIGUE_THRESHOLD = 2; // Trigger adaptation after 2 strikes
const INTENSITY_CUT_SCALAR = 0.85; // 15% reduction on adaptation
const VOLUME_CUT_MULTIPLIER = 0.5; // 50% duration cut for volume conversion
const WORKOUTS_TO_MODIFY = 3; // Number of workouts affected by adaptation

// Recovery template IDs (these should match your workout_templates table)
const RECOVERY_TEMPLATES = {
  run: 'recovery-run-template-id',
  bike: 'recovery-spin-template-id',
  swim: 'recovery-swim-template-id',
};

// ============================================
// PART 1: Strike Detection
// ============================================

interface StrikeCheckResult {
  shouldAddStrike: boolean;
  reason?: 'SUBJECTIVE' | 'OBJECTIVE' | 'COMPLIANCE';
}

/**
 * Check if feedback triggers a fatigue strike
 * 
 * Strike Triggers:
 * 1. Subjective: User rates workout "Harder than expected"
 * 2. Objective: RPE > Target_RPE + 2
 * 3. Compliance: Skipped workout due to fatigue/sickness
 */
export function checkForStrike(
  feedbackRating: 'easier' | 'same' | 'harder',
  actualRPE?: number,
  targetRPE?: number,
  skipReason?: SkipReason
): StrikeCheckResult {
  // Subjective check: User said it was harder
  if (feedbackRating === 'harder') {
    return { shouldAddStrike: true, reason: 'SUBJECTIVE' };
  }

  // Objective check: RPE exceeded target by 2+
  if (actualRPE && targetRPE && actualRPE > targetRPE + 2) {
    return { shouldAddStrike: true, reason: 'OBJECTIVE' };
  }

  // Compliance check: Skipped due to fatigue/sickness
  if (skipReason === 'TOO_TIRED' || skipReason === 'SICK') {
    return { shouldAddStrike: true, reason: 'COMPLIANCE' };
  }

  return { shouldAddStrike: false };
}

// ============================================
// PART 2: Strike Processing
// ============================================

/**
 * Process workout feedback and update fatigue strikes
 * Called from POST /feedback endpoint
 */
export async function processFeedback(
  userId: string,
  workoutId: string,
  rating: 'easier' | 'same' | 'harder',
  rpe?: number
): Promise<{ strikeTriggered: boolean; adaptationTriggered: boolean }> {
  // Get the workout to check target RPE
  const { data: workout } = await supabase
    .from('workouts')
    .select('target_rpe')
    .eq('id', workoutId)
    .single();

  const targetRPE = workout?.target_rpe;

  // Check if this triggers a strike
  const strikeCheck = checkForStrike(rating, rpe, targetRPE);

  if (!strikeCheck.shouldAddStrike) {
    // No strike, but reset consecutive completes counter if they completed
    await incrementConsecutiveCompletes(userId);
    return { strikeTriggered: false, adaptationTriggered: false };
  }

  // Add the strike
  const { data: state } = await supabase
    .from('user_training_state')
    .select('current_fatigue_strikes')
    .eq('user_id', userId)
    .single();

  const currentStrikes = (state?.current_fatigue_strikes || 0) + 1;

  await supabase
    .from('user_training_state')
    .upsert({
      user_id: userId,
      current_fatigue_strikes: currentStrikes,
      last_strike_date: new Date().toISOString().split('T')[0],
      consecutive_completes: 0, // Reset on strike
      updated_at: new Date().toISOString(),
    });

  console.log(`⚠️ Strike added for user ${userId}. Total: ${currentStrikes}`);

  // Check if we hit the threshold
  if (currentStrikes >= FATIGUE_THRESHOLD) {
    await triggerAdaptation(userId, currentStrikes, strikeCheck.reason!);
    return { strikeTriggered: true, adaptationTriggered: true };
  }

  return { strikeTriggered: true, adaptationTriggered: false };
}

// ============================================
// PART 3: Adaptation Event Execution
// ============================================

/**
 * Trigger the adaptation event
 * Modifies the next 3 scheduled workouts
 */
async function triggerAdaptation(
  userId: string,
  strikeCount: number,
  triggerReason: 'SUBJECTIVE' | 'OBJECTIVE' | 'COMPLIANCE'
): Promise<void> {
  console.log(`🔄 Triggering adaptation for user ${userId} (${strikeCount} strikes)`);

  // Get the user's active plan
  const { data: plan } = await supabase
    .from('training_plans')
    .select('id')
    .eq('user_id', userId)
    .eq('status', 'active')
    .single();

  if (!plan) {
    console.log('No active plan found for adaptation');
    return;
  }

  // Get next scheduled workouts
  const today = new Date().toISOString().split('T')[0];
  const { data: upcomingWorkouts } = await supabase
    .from('workouts')
    .select('*')
    .eq('plan_id', plan.id)
    .eq('status', 'planned')
    .gte('scheduled_date', today)
    .order('scheduled_date', { ascending: true })
    .limit(WORKOUTS_TO_MODIFY + 3); // Get extras for filtering

  if (!upcomingWorkouts || upcomingWorkouts.length === 0) {
    console.log('No upcoming workouts to adapt');
    return;
  }

  const actionsLog = {
    intensity_cuts: [] as string[],
    volume_conversions: [] as string[],
    notifications_sent: false,
  };

  let workoutsModified = 0;

  // Action 1: Intensity Cut - Find interval/tempo sessions
  const intervalWorkouts = upcomingWorkouts.filter(
    (w) => w.priority_level <= 2 && !w.was_adapted
  ).slice(0, 2);

  for (const workout of intervalWorkouts) {
    await applyIntensityCut(workout);
    actionsLog.intensity_cuts.push(workout.id);
    workoutsModified++;
  }

  // Action 2: Volume Conversion - Find long sessions
  const longWorkouts = upcomingWorkouts.filter(
    (w) => w.priority_level === 1 && !w.was_adapted
  ).slice(0, 1);

  for (const workout of longWorkouts) {
    await convertToRecovery(workout);
    actionsLog.volume_conversions.push(workout.id);
    workoutsModified++;
  }

  // Action 3: Reset strikes and log adaptation
  await supabase
    .from('user_training_state')
    .update({
      current_fatigue_strikes: 0,
      last_adaptation_date: new Date().toISOString().split('T')[0],
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', userId);

  // Also increment total adaptations
  await supabase.rpc('increment_total_adaptations', { user_id_param: userId });

  // Log the adaptation
  await supabase.from('adaptation_logs').insert({
    id: uuid(),
    user_id: userId,
    triggered_at: new Date().toISOString(),
    trigger_reason: triggerReason === 'SUBJECTIVE' ? 'FATIGUE_STRIKES' : 
                    triggerReason === 'OBJECTIVE' ? 'RPE_EXCEEDED' : 'COMPLIANCE',
    fatigue_strikes_at_trigger: strikeCount,
    workouts_affected: workoutsModified,
    actions_taken: actionsLog,
  });

  // TODO: Send push notification
  // "Plan Adapted: Intensity reduced due to high fatigue."
  actionsLog.notifications_sent = true;

  console.log(`✅ Adaptation complete. ${workoutsModified} workouts modified.`);
}

/**
 * Apply intensity cut to a workout (15% reduction)
 */
async function applyIntensityCut(workout: DbWorkout): Promise<void> {
  // Recalculate structure with reduced intensity
  const updatedStructure = { ...workout.calculated_structure };
  
  updatedStructure.steps = updatedStructure.steps.map((step) => ({
    ...step,
    target_wattage: step.target_wattage 
      ? Math.round(step.target_wattage * INTENSITY_CUT_SCALAR) 
      : undefined,
    target_pace: step.target_pace 
      ? Math.round(step.target_pace / INTENSITY_CUT_SCALAR) // Slower pace = higher number
      : undefined,
  }));

  await supabase
    .from('workouts')
    .update({
      intensity_scalar: INTENSITY_CUT_SCALAR,
      calculated_structure: updatedStructure,
      was_adapted: true,
      original_template_id: workout.original_template_id || workout.template_id,
    })
    .eq('id', workout.id);

  console.log(`  → Intensity cut applied to workout ${workout.id}`);
}

/**
 * Convert a long workout to recovery
 */
async function convertToRecovery(workout: DbWorkout): Promise<void> {
  const recoveryTemplateId = RECOVERY_TEMPLATES[workout.workout_type as keyof typeof RECOVERY_TEMPLATES];
  
  // Create a recovery structure
  const originalDuration = workout.calculated_structure.total_duration;
  const newDuration = Math.round(originalDuration * VOLUME_CUT_MULTIPLIER);

  const recoveryStructure = {
    title: `Recovery ${workout.workout_type.charAt(0).toUpperCase() + workout.workout_type.slice(1)}`,
    description: 'Easy effort. Focus on movement quality and recovery.',
    total_duration: newDuration,
    steps: [
      {
        type: 'warmup',
        duration: Math.round(newDuration * 0.1),
        target_zone: 1,
        description: 'Easy warm-up',
      },
      {
        type: 'main',
        duration: Math.round(newDuration * 0.8),
        target_zone: 2,
        target_rpe: 3,
        description: 'Easy steady effort. Zone 2 only.',
      },
      {
        type: 'cooldown',
        duration: Math.round(newDuration * 0.1),
        target_zone: 1,
        description: 'Easy cooldown',
      },
    ],
  };

  await supabase
    .from('workouts')
    .update({
      template_id: recoveryTemplateId || workout.template_id,
      calculated_structure: recoveryStructure,
      was_adapted: true,
      original_template_id: workout.original_template_id || workout.template_id,
      priority_level: 3, // Downgrade priority
      target_rpe: 3,
    })
    .eq('id', workout.id);

  console.log(`  → Volume conversion applied to workout ${workout.id} (${originalDuration}s → ${newDuration}s)`);
}

// ============================================
// PART 4: Compliance Tracking
// ============================================

/**
 * Handle workout completion - track consecutive completes
 */
export async function handleWorkoutCompletion(userId: string, workoutId: string): Promise<void> {
  await incrementConsecutiveCompletes(userId);
  
  // Update workout status
  await supabase
    .from('workouts')
    .update({ status: 'completed' })
    .eq('id', workoutId);
}

/**
 * Handle missed workout with skip reason
 */
export async function handleMissedWorkout(
  userId: string,
  workoutId: string,
  skipReason: SkipReason
): Promise<{ strikeTriggered: boolean; adaptationTriggered: boolean }> {
  // Update workout with skip reason
  await supabase
    .from('workouts')
    .update({ 
      status: 'skipped',
      skip_reason: skipReason,
    })
    .eq('id', workoutId);

  // Check if this triggers a strike
  const strikeCheck = checkForStrike('same', undefined, undefined, skipReason);

  if (strikeCheck.shouldAddStrike) {
    return processFeedback(userId, workoutId, 'same', undefined);
  }

  return { strikeTriggered: false, adaptationTriggered: false };
}

async function incrementConsecutiveCompletes(userId: string): Promise<void> {
  const { data: state } = await supabase
    .from('user_training_state')
    .select('consecutive_completes')
    .eq('user_id', userId)
    .single();

  const current = state?.consecutive_completes || 0;

  await supabase
    .from('user_training_state')
    .upsert({
      user_id: userId,
      consecutive_completes: current + 1,
      updated_at: new Date().toISOString(),
    });
}

// ============================================
// PART 5: Strike Reset on Positive Feedback
// ============================================

/**
 * Optionally reduce strikes on consistent positive feedback
 * Call this if user has 5+ consecutive completes with "same" or "easier" ratings
 */
export async function checkPositiveTrend(userId: string): Promise<void> {
  const { data: state } = await supabase
    .from('user_training_state')
    .select('consecutive_completes, current_fatigue_strikes')
    .eq('user_id', userId)
    .single();

  if (state && state.consecutive_completes >= 5 && state.current_fatigue_strikes > 0) {
    // Reduce strikes by 1 for consistent positive training
    await supabase
      .from('user_training_state')
      .update({
        current_fatigue_strikes: Math.max(0, state.current_fatigue_strikes - 1),
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    console.log(`✨ Strike reduced for user ${userId} due to positive trend`);
  }
}

// ============================================
// PART 6: Middleware Hook
// ============================================

/**
 * Check fatigue state - to be called from POST /feedback middleware
 */
export async function checkFatigue(userId: string): Promise<{
  currentStrikes: number;
  isNearThreshold: boolean;
  lastAdaptation?: string;
}> {
  const { data: state } = await supabase
    .from('user_training_state')
    .select('current_fatigue_strikes, last_adaptation_date')
    .eq('user_id', userId)
    .single();

  const strikes = state?.current_fatigue_strikes || 0;

  return {
    currentStrikes: strikes,
    isNearThreshold: strikes >= FATIGUE_THRESHOLD - 1,
    lastAdaptation: state?.last_adaptation_date,
  };
}

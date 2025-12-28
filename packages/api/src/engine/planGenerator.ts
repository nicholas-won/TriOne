/**
 * Plan Generator
 * 
 * Creates a Dynamic Linked List of Workout Objects based on the user's
 * Biometric_State. Each workout target is calculated using:
 * 
 * Target_Intensity = Template_Coefficient × User_Biometric_Scalar
 */

import { supabase, DbWorkout, DbTrainingPlan, DbWorkoutTemplate, TrainingPhase, DbBiometrics } from '../db/supabase';
import { v4 as uuid } from 'uuid';
import { generateWorkoutFromTemplate } from './workoutGenerator';
import { 
  calculateBikeTargetPower, 
  calculateSwimTargetPace, 
  calculateRunTargetPace,
  applyIntensityScalar
} from './biometricsCalculator';

// ============================================
// Types
// ============================================

interface PlanGenerationParams {
  userId: string;
  raceId?: string | null;
  raceDistance: 'sprint' | 'olympic' | '70.3' | '140.6';
  volumeTier: 1 | 2 | 3;
  biometrics: Partial<DbBiometrics>;
  needsCalibration: boolean;
}

interface VolumeTierConfig {
  tier: 1 | 2 | 3;
  minWeeklyHours: number;
  maxWeeklyHours: number;
  swimSessions: number;
  bikeSessions: number;
  runSessions: number;
  strengthSessions: number;
  brickSessions: number;
}

interface PhaseConfig {
  phase: TrainingPhase;
  zoneFocus: string;
  intensityModifier: number;
  volumeModifier: number;
}

// ============================================
// Volume Tier Configurations
// ============================================

const VOLUME_TIERS: Record<1 | 2 | 3, VolumeTierConfig> = {
  1: {
    tier: 1,
    minWeeklyHours: 4,
    maxWeeklyHours: 6,
    swimSessions: 1,
    bikeSessions: 1,
    runSessions: 1,
    strengthSessions: 0,
    brickSessions: 1,
  },
  2: {
    tier: 2,
    minWeeklyHours: 7,
    maxWeeklyHours: 10,
    swimSessions: 2,
    bikeSessions: 2,
    runSessions: 2,
    strengthSessions: 1,
    brickSessions: 0,
  },
  3: {
    tier: 3,
    minWeeklyHours: 11,
    maxWeeklyHours: 15,
    swimSessions: 3,
    bikeSessions: 3,
    runSessions: 3,
    strengthSessions: 2,
    brickSessions: 1,
  },
};

// ============================================
// Phase Configurations
// ============================================

const PHASE_CONFIGS: Record<TrainingPhase, PhaseConfig> = {
  BASE: {
    phase: 'BASE',
    zoneFocus: 'Zone 2',
    intensityModifier: 0.85, // Lower intensity
    volumeModifier: 1.0, // Full volume
  },
  BUILD: {
    phase: 'BUILD',
    zoneFocus: 'Zone 3/4',
    intensityModifier: 1.0, // Normal intensity
    volumeModifier: 0.9, // Slightly reduced volume
  },
  PEAK: {
    phase: 'PEAK',
    zoneFocus: 'Zone 5',
    intensityModifier: 1.1, // Higher intensity
    volumeModifier: 0.8, // Reduced volume
  },
  TAPER: {
    phase: 'TAPER',
    zoneFocus: 'Zone 2/3',
    intensityModifier: 0.9, // Maintain some intensity
    volumeModifier: 0.5, // 50% volume reduction
  },
};

// ============================================
// Phase Distribution Logic
// ============================================

function getPhaseDistribution(weeksToRace: number): { phase: TrainingPhase; weeks: number }[] {
  if (weeksToRace <= 4) {
    return [
      { phase: 'BUILD', weeks: 2 },
      { phase: 'TAPER', weeks: 2 },
    ];
  }
  
  if (weeksToRace <= 8) {
    return [
      { phase: 'BASE', weeks: 2 },
      { phase: 'BUILD', weeks: 4 },
      { phase: 'TAPER', weeks: 2 },
    ];
  }
  
  if (weeksToRace <= 12) {
    return [
      { phase: 'BASE', weeks: 4 },
      { phase: 'BUILD', weeks: 5 },
      { phase: 'PEAK', weeks: 1 },
      { phase: 'TAPER', weeks: 2 },
    ];
  }
  
  // 12+ weeks - Standard periodization
  const baseWeeks = Math.floor(weeksToRace * 0.3);
  const buildWeeks = Math.floor(weeksToRace * 0.4);
  const peakWeeks = Math.floor(weeksToRace * 0.15);
  const taperWeeks = weeksToRace - baseWeeks - buildWeeks - peakWeeks;
  
  return [
    { phase: 'BASE', weeks: Math.max(3, baseWeeks) },
    { phase: 'BUILD', weeks: Math.max(4, buildWeeks) },
    { phase: 'PEAK', weeks: Math.max(1, peakWeeks) },
    { phase: 'TAPER', weeks: Math.max(2, taperWeeks) },
  ];
}

// ============================================
// Weekly Structure Generation
// ============================================

interface DayPlan {
  type: 'swim' | 'bike' | 'run' | 'strength' | 'brick' | 'rest';
  priority: 1 | 2 | 3;
  duration?: number; // target duration in minutes
  focusType?: 'endurance' | 'tempo' | 'intervals' | 'recovery';
}

function generateWeeklyStructure(
  volumeTier: VolumeTierConfig,
  phase: TrainingPhase
): DayPlan[] {
  const config = PHASE_CONFIGS[phase];
  const week: DayPlan[] = [];
  
  // Calculate session requirements
  const swimCount = Math.round(volumeTier.swimSessions * config.volumeModifier);
  const bikeCount = Math.round(volumeTier.bikeSessions * config.volumeModifier);
  const runCount = Math.round(volumeTier.runSessions * config.volumeModifier);
  const strengthCount = Math.round(volumeTier.strengthSessions * config.volumeModifier);
  const brickCount = volumeTier.brickSessions; // Bricks don't scale with volume modifier
  
  // Tier 1: Mon-Swim, Tue-Rest, Wed-Bike, Thu-Run, Fri-Rest, Sat-Brick, Sun-Rest
  // Tier 2: Mon-Swim, Tue-Bike, Wed-Run, Thu-Swim, Fri-Bike, Sat-Run, Sun-Rest
  // Tier 3: Mon-Swim, Tue-Bike+Run, Wed-Run, Thu-Swim, Fri-Bike, Sat-Brick, Sun-Run
  
  switch (volumeTier.tier) {
    case 1:
      week.push(
        { type: 'swim', priority: 2, focusType: phase === 'BASE' ? 'endurance' : 'tempo' },
        { type: 'rest', priority: 3 },
        { type: 'bike', priority: 2, focusType: phase === 'BASE' ? 'endurance' : 'tempo' },
        { type: 'run', priority: 2, focusType: phase === 'BASE' ? 'endurance' : 'tempo' },
        { type: 'rest', priority: 3 },
        { type: brickCount > 0 ? 'brick' : 'bike', priority: 1 },
        { type: 'rest', priority: 3 }
      );
      break;
      
    case 2:
      week.push(
        { type: 'swim', priority: 2, focusType: 'endurance' },
        { type: 'bike', priority: 2, focusType: phase === 'BUILD' ? 'intervals' : 'tempo' },
        { type: 'run', priority: 2, focusType: phase === 'BUILD' ? 'intervals' : 'tempo' },
        { type: 'swim', priority: 2, focusType: 'tempo' },
        { type: 'bike', priority: 1, focusType: 'endurance' }, // Long ride
        { type: 'run', priority: 1, focusType: 'endurance' }, // Long run
        { type: strengthCount > 0 ? 'strength' : 'rest', priority: 3 }
      );
      break;
      
    case 3:
      week.push(
        { type: 'swim', priority: 2, focusType: 'tempo' },
        { type: 'bike', priority: 2, focusType: 'intervals' },
        { type: 'run', priority: 2, focusType: 'intervals' },
        { type: 'swim', priority: 2, focusType: 'intervals' },
        { type: 'bike', priority: 1, focusType: 'endurance' },
        { type: brickCount > 0 ? 'brick' : 'run', priority: 1 },
        { type: 'run', priority: 1, focusType: 'endurance' }
      );
      break;
  }
  
  // Apply taper volume reduction for TAPER phase
  if (phase === 'TAPER') {
    return week.map(day => ({
      ...day,
      priority: Math.min(3, day.priority + 1) as 1 | 2 | 3, // Reduce all priorities
      focusType: 'recovery' as const
    }));
  }
  
  return week;
}

// ============================================
// Main Plan Generation
// ============================================

export async function generateTrainingPlan(params: PlanGenerationParams): Promise<DbTrainingPlan> {
  const { userId, raceId, raceDistance, volumeTier, biometrics, needsCalibration } = params;

  console.log(`🏋️ Generating training plan for user ${userId}`);
  console.log(`   Race distance: ${raceDistance}`);
  console.log(`   Volume tier: ${volumeTier}`);
  console.log(`   Needs calibration: ${needsCalibration}`);

  // Get race details
  let raceDate: Date;
  let raceName: string;

  if (raceId) {
    const { data: race } = await supabase
      .from('races')
      .select('*')
      .eq('id', raceId)
      .single();
    
    if (race) {
      raceDate = new Date(race.date);
      raceName = race.name;
    } else {
      raceDate = new Date();
      raceDate.setDate(raceDate.getDate() + 84);
      raceName = `${raceDistance.toUpperCase()} Training`;
    }
  } else {
    raceDate = new Date();
    raceDate.setDate(raceDate.getDate() + 84);
    raceName = `${raceDistance.toUpperCase()} Training`;
  }

  // Start next Monday
  const startDate = getNextMonday();
  
  // Calculate weeks to race
  const weeksToRace = Math.ceil((raceDate.getTime() - startDate.getTime()) / (7 * 24 * 60 * 60 * 1000));
  const phases = getPhaseDistribution(weeksToRace);
  const totalWeeks = phases.reduce((sum, p) => sum + p.weeks, 0);
  
  console.log(`   Weeks to race: ${weeksToRace}`);
  console.log(`   Phases: ${phases.map(p => `${p.phase}(${p.weeks}w)`).join(' → ')}`);

  // Create the plan
  const planId = uuid();
  const { data: plan, error: planError } = await supabase
    .from('training_plans')
    .insert({
      id: planId,
      user_id: userId,
      name: `Road to ${raceName}`,
      race_date: raceDate.toISOString().split('T')[0],
      start_date: startDate.toISOString().split('T')[0],
      race_distance_type: raceDistance,
      status: 'active',
      race_id: raceId,
      current_phase: phases[0].phase,
      current_week: 1,
      total_weeks: totalWeeks,
      volume_tier: volumeTier,
    })
    .select()
    .single();

  if (planError || !plan) {
    console.error('Failed to create training plan:', planError);
    throw new Error('Failed to create training plan');
  }

  // Get workout templates
  const { data: templates } = await supabase
    .from('workout_templates')
    .select('*');

  const templatesByType: Record<string, DbWorkoutTemplate[]> = {};
  templates?.forEach(t => {
    if (!templatesByType[t.type]) templatesByType[t.type] = [];
    templatesByType[t.type].push(t);
  });

  const workouts: Partial<DbWorkout>[] = [];
  let currentDate = new Date(startDate);
  let weekNumber = 1;

  // Generate workouts for each phase
  for (const phaseInfo of phases) {
    const volumeConfig = VOLUME_TIERS[volumeTier];
    const phaseConfig = PHASE_CONFIGS[phaseInfo.phase];
    
    for (let week = 0; week < phaseInfo.weeks; week++) {
      const weeklyStructure = generateWeeklyStructure(volumeConfig, phaseInfo.phase);
      
      for (let day = 0; day < 7; day++) {
        const dayPlan = weeklyStructure[day];
        
        if (dayPlan.type === 'rest') {
          currentDate.setDate(currentDate.getDate() + 1);
          continue;
        }

        // Select appropriate template based on focus type
        const availableTemplates = templatesByType[dayPlan.type] || [];
        const template = selectTemplate(availableTemplates, dayPlan.focusType, phaseInfo.phase);

        if (template) {
          const workout = generateWorkoutFromTemplate(
            planId,
            template,
            currentDate.toISOString().split('T')[0],
            dayPlan.priority,
            biometrics,
            phaseInfo.phase,
            phaseConfig.intensityModifier
          );
          workouts.push(workout);
        } else {
          // Create a placeholder workout if no template found
          workouts.push(createPlaceholderWorkout(
            planId,
            currentDate.toISOString().split('T')[0],
            dayPlan,
            biometrics,
            phaseConfig.intensityModifier
          ));
        }

        currentDate.setDate(currentDate.getDate() + 1);
      }
      
      weekNumber++;
    }
  }

  // Insert all workouts
  if (workouts.length > 0) {
    const { error: workoutsError } = await supabase
      .from('workouts')
      .insert(workouts);

    if (workoutsError) {
      console.error('Failed to insert workouts:', workoutsError);
    }
  }

  console.log(`✅ Plan created with ${workouts.length} workouts`);
  
  return plan;
}

// ============================================
// Helper Functions
// ============================================

function getNextMonday(): Date {
  const today = new Date();
  const dayOfWeek = today.getDay();
  const daysUntilMonday = dayOfWeek === 0 ? 1 : 8 - dayOfWeek;
  const nextMonday = new Date(today);
  nextMonday.setDate(today.getDate() + daysUntilMonday);
  nextMonday.setHours(0, 0, 0, 0);
  return nextMonday;
}

function selectTemplate(
  templates: DbWorkoutTemplate[],
  focusType: string | undefined,
  phase: TrainingPhase
): DbWorkoutTemplate | undefined {
  if (templates.length === 0) return undefined;
  
  // Try to match focus type to difficulty tier
  const tierMap: Record<string, number> = {
    recovery: 1,
    endurance: 2,
    tempo: 3,
    intervals: 4,
  };
  
  const targetTier = tierMap[focusType || 'endurance'] || 2;
  
  // Find closest match
  const sorted = [...templates].sort((a, b) => 
    Math.abs(a.difficulty_tier - targetTier) - Math.abs(b.difficulty_tier - targetTier)
  );
  
  return sorted[0];
}

function createPlaceholderWorkout(
  planId: string,
  date: string,
  dayPlan: DayPlan,
  biometrics: Partial<DbBiometrics>,
  intensityModifier: number
): Partial<DbWorkout> {
  const baseDurations: Record<string, number> = {
    swim: 2400, // 40 mins
    bike: 3600, // 60 mins
    run: 2700, // 45 mins
    strength: 2400, // 40 mins
    brick: 4200, // 70 mins
  };
  
  const duration = Math.round((baseDurations[dayPlan.type] || 3000) * (dayPlan.priority === 1 ? 1.5 : dayPlan.priority === 3 ? 0.7 : 1.0));
  
  // Calculate targets based on biometrics
  let targetValue: number | undefined;
  let targetField: string = '';
  
  if (dayPlan.type === 'swim' && biometrics.critical_swim_speed) {
    targetValue = applyIntensityScalar(1.0, biometrics.critical_swim_speed, intensityModifier);
    targetField = 'target_pace';
  } else if (dayPlan.type === 'bike' && biometrics.functional_threshold_power) {
    targetValue = applyIntensityScalar(0.75, biometrics.functional_threshold_power, intensityModifier);
    targetField = 'target_wattage';
  } else if (dayPlan.type === 'run' && biometrics.threshold_run_pace) {
    targetValue = applyIntensityScalar(1.15, biometrics.threshold_run_pace, intensityModifier); // Slower for endurance
    targetField = 'target_pace';
  }
  
  const focusTypeNames: Record<string, string> = {
    recovery: 'Recovery',
    endurance: 'Endurance',
    tempo: 'Tempo',
    intervals: 'Intervals',
  };
  
  return {
    id: uuid(),
    plan_id: planId,
    scheduled_date: date,
    workout_type: dayPlan.type,
    priority_level: dayPlan.priority,
    status: 'planned',
    is_calibration_test: false,
    target_rpe: dayPlan.priority === 1 ? 7 : dayPlan.priority === 2 ? 6 : 4,
    intensity_scalar: intensityModifier,
    was_adapted: false,
    calculated_structure: {
      title: `${focusTypeNames[dayPlan.focusType || 'endurance']} ${dayPlan.type.charAt(0).toUpperCase() + dayPlan.type.slice(1)}`,
      description: `${dayPlan.priority === 1 ? 'Key' : dayPlan.priority === 2 ? 'Quality' : 'Easy'} ${dayPlan.type} session.`,
      total_duration: duration,
      steps: [
        {
          type: 'warmup',
          duration: Math.round(duration * 0.15),
          target_zone: 1,
          target_rpe: 3,
          description: 'Easy warm-up',
        },
        {
          type: 'main',
          duration: Math.round(duration * 0.7),
          target_zone: dayPlan.priority === 1 ? 3 : dayPlan.priority === 2 ? 3 : 2,
          target_rpe: dayPlan.priority === 1 ? 7 : dayPlan.priority === 2 ? 6 : 4,
          [targetField]: targetValue,
          description: `Main ${dayPlan.focusType || 'endurance'} set`,
        },
        {
          type: 'cooldown',
          duration: Math.round(duration * 0.15),
          target_zone: 1,
          target_rpe: 2,
          description: 'Easy cooldown',
        },
      ],
    },
  };
}

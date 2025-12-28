import { v4 as uuid } from 'uuid';
import { DbWorkout, DbWorkoutTemplate } from '../db/supabase';

// Zone definitions based on % of FTP/Threshold
const ZONES = {
  1: { name: 'Recovery', percentFTP: [0, 0.55], percentPace: [0.75, 0.85] },
  2: { name: 'Endurance', percentFTP: [0.56, 0.75], percentPace: [0.85, 0.90] },
  3: { name: 'Tempo', percentFTP: [0.76, 0.90], percentPace: [0.90, 0.95] },
  4: { name: 'Threshold', percentFTP: [0.91, 1.05], percentPace: [0.95, 1.0] },
  5: { name: 'VO2 Max', percentFTP: [1.06, 1.20], percentPace: [1.0, 1.05] },
  6: { name: 'Anaerobic', percentFTP: [1.21, 1.50], percentPace: [1.05, 1.15] },
};

interface Biometrics {
  css_pace_per_100?: number;
  run_threshold_pace_per_mile?: number;
  bike_ftp?: number;
  max_heart_rate?: number;
}

export function generateWorkoutFromTemplate(
  planId: string,
  template: DbWorkoutTemplate,
  scheduledDate: string,
  priority: 1 | 2 | 3,
  biometrics: Biometrics,
  phase: string
): Partial<DbWorkout> {
  const steps = template.structure_json.steps.map((step, index) => {
    const targetZone = step.target_zone || getZoneForStepType(step.type);
    
    return {
      type: step.type,
      duration: adjustDurationForPhase(step.duration, phase, priority),
      description: step.description || getStepDescription(step.type, targetZone),
      target_zone: targetZone,
      target_wattage: calculateTargetWattage(targetZone, biometrics.bike_ftp, template.type),
      target_pace: calculateTargetPace(targetZone, biometrics, template.type),
      target_heart_rate: calculateTargetHR(targetZone, biometrics.max_heart_rate),
      percent_ftp: step.percent_ftp,
    };
  });

  const totalDuration = steps.reduce((sum, s) => sum + s.duration, 0);

  return {
    id: uuid(),
    plan_id: planId,
    template_id: template.id,
    scheduled_date: scheduledDate,
    workout_type: template.type,
    priority_level: priority,
    status: 'planned',
    is_calibration_test: false,
    calculated_structure: {
      steps,
      total_duration: totalDuration,
      title: template.name,
      description: template.description || generateDescription(template.type, phase, priority),
    },
  };
}

function getZoneForStepType(type: string): number {
  switch (type) {
    case 'warmup':
    case 'cooldown':
    case 'rest':
      return 1;
    case 'main':
    case 'interval':
      return 4;
    default:
      return 2;
  }
}

function adjustDurationForPhase(baseDuration: number, phase: string, priority: number): number {
  let multiplier = 1;
  
  switch (phase) {
    case 'base':
      multiplier = 0.85;
      break;
    case 'build':
      multiplier = 1.0;
      break;
    case 'peak':
      multiplier = 1.1;
      break;
    case 'taper':
      multiplier = 0.6;
      break;
  }

  // Long workouts (priority 1) get extra duration
  if (priority === 1) {
    multiplier *= 1.3;
  }

  return Math.round(baseDuration * multiplier);
}

function calculateTargetWattage(zone: number, ftp?: number, workoutType?: string): number | undefined {
  if (!ftp || workoutType !== 'bike') return undefined;
  
  const zoneData = ZONES[zone as keyof typeof ZONES];
  if (!zoneData) return undefined;
  
  const midpoint = (zoneData.percentFTP[0] + zoneData.percentFTP[1]) / 2;
  return Math.round(ftp * midpoint);
}

function calculateTargetPace(zone: number, biometrics: Biometrics, workoutType?: string): number | undefined {
  if (workoutType === 'bike') return undefined;
  
  let basePace: number | undefined;
  
  if (workoutType === 'swim') {
    basePace = biometrics.css_pace_per_100;
  } else if (workoutType === 'run') {
    basePace = biometrics.run_threshold_pace_per_mile;
  }
  
  if (!basePace) return undefined;
  
  const zoneData = ZONES[zone as keyof typeof ZONES];
  if (!zoneData) return undefined;
  
  // Higher percentage = slower pace for running/swimming
  const midpoint = (zoneData.percentPace[0] + zoneData.percentPace[1]) / 2;
  return Math.round(basePace / midpoint);
}

function calculateTargetHR(zone: number, maxHR?: number): number | undefined {
  if (!maxHR) return undefined;
  
  // HR zones based on % of max HR
  const hrZones: Record<number, [number, number]> = {
    1: [0.50, 0.60],
    2: [0.60, 0.70],
    3: [0.70, 0.80],
    4: [0.80, 0.90],
    5: [0.90, 0.95],
    6: [0.95, 1.00],
  };
  
  const range = hrZones[zone];
  if (!range) return undefined;
  
  const midpoint = (range[0] + range[1]) / 2;
  return Math.round(maxHR * midpoint);
}

function getStepDescription(type: string, zone: number): string {
  const zoneData = ZONES[zone as keyof typeof ZONES];
  const zoneName = zoneData?.name || 'Easy';
  
  switch (type) {
    case 'warmup':
      return 'Gradual warm-up to prepare your body';
    case 'cooldown':
      return 'Easy effort to aid recovery';
    case 'rest':
      return 'Active recovery between efforts';
    case 'interval':
      return `${zoneName} effort - push yourself!`;
    case 'main':
      return `Main set at ${zoneName} intensity`;
    default:
      return `${zoneName} effort`;
  }
}

function generateDescription(type: string, phase: string, priority: number): string {
  const phaseDescriptions: Record<string, string> = {
    base: 'Building your aerobic foundation',
    build: 'Increasing intensity to build race fitness',
    peak: 'Fine-tuning for optimal race performance',
    taper: 'Recovering and sharpening for race day',
  };

  const typeDescriptions: Record<string, string> = {
    swim: 'Improving technique and aquatic endurance',
    bike: 'Building cycling power and efficiency',
    run: 'Developing running economy and speed',
    brick: 'Practicing the bike-to-run transition',
    strength: 'Building muscular endurance and injury prevention',
  };

  const priorityPrefix = priority === 1 
    ? 'Key session: ' 
    : priority === 2 
      ? 'Quality work: '
      : 'Recovery focus: ';

  return `${priorityPrefix}${typeDescriptions[type] || 'Building fitness'}. ${phaseDescriptions[phase] || ''}`;
}


/**
 * Biometrics Calculator
 * 
 * Implements the mathematical models from the algorithm specification.
 * All formulas are derived from sports science research.
 */

// ============================================
// PART 1: Age & Max Heart Rate Calculations
// ============================================

/**
 * Calculate age from date of birth
 */
export function calculateAge(dob: string | Date): number {
  const birthDate = new Date(dob);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  
  return age;
}

/**
 * Calculate Max Heart Rate using the standard formula
 * Formula: Max_HR = 220 - Age
 * 
 * @param age User's age in years
 * @returns Estimated maximum heart rate in BPM
 */
export function calculateMaxHR(age: number): number {
  return 220 - age;
}

/**
 * Get or calculate Max HR
 * If user provides their own Max HR, use it. Otherwise calculate from age.
 */
export function getMaxHR(userMaxHR: number | undefined, dob: string | Date): number {
  if (userMaxHR && userMaxHR > 0) {
    return userMaxHR;
  }
  const age = calculateAge(dob);
  return calculateMaxHR(age);
}

// ============================================
// PART 2: Swimming - Critical Swim Speed (CSS)
// ============================================

/**
 * Calculate Critical Swim Speed from 400m Time Trial
 * 
 * Formula: CSS (sec/100m) = (Time_400m / 4) + 3.0
 * 
 * Note: +3.0s offset accounts for "fade" over longer distances vs a short test
 * 
 * @param time400m Time in seconds for 400m swim
 * @returns CSS in seconds per 100m
 */
export function calculateCSS(time400m: number): number {
  return (time400m / 4) + 3.0;
}

/**
 * Calculate target pace for a swim workout interval
 * 
 * Formula: Target_Pace = CSS * Template_Coefficient
 * 
 * @param css Critical Swim Speed in seconds per 100m
 * @param coefficient Template coefficient (e.g., 1.05 for 105%)
 * @returns Target pace in seconds per 100m
 */
export function calculateSwimTargetPace(css: number, coefficient: number): number {
  return Math.round(css * coefficient);
}

// ============================================
// PART 3: Running - Threshold Pace
// ============================================

/**
 * Calculate Threshold Pace from 1 Mile Time Trial
 * 
 * Formula: TP (sec/mile) = Time_1mile * 1.15
 * 
 * Note: 1.15 multiplier converts Anaerobic mile pace to Aerobic Threshold pace
 * 
 * @param time1Mile Time in seconds for 1 mile run
 * @returns Threshold pace in seconds per mile
 */
export function calculateThresholdPace(time1Mile: number): number {
  return Math.round(time1Mile * 1.15);
}

/**
 * Calculate target pace for a run workout interval
 * 
 * Formula: Target_Pace = Threshold_Pace * Template_Coefficient
 * 
 * @param thresholdPace Threshold pace in seconds per mile
 * @param coefficient Template coefficient (e.g., 0.95 for 95% = faster)
 * @returns Target pace in seconds per mile
 */
export function calculateRunTargetPace(thresholdPace: number, coefficient: number): number {
  return Math.round(thresholdPace * coefficient);
}

/**
 * Convert pace to min:sec format string
 */
export function formatPace(secondsPerMile: number): string {
  const minutes = Math.floor(secondsPerMile / 60);
  const seconds = secondsPerMile % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}/mi`;
}

// ============================================
// PART 4: Cycling - Functional Threshold Power (FTP)
// ============================================

/**
 * Calculate FTP from 20-minute Power Test
 * 
 * Formula: FTP = Average_20min_Power * 0.95
 * 
 * @param avgPower20min Average power in watts for 20-minute test
 * @returns FTP in watts
 */
export function calculateFTP(avgPower20min: number): number {
  return Math.round(avgPower20min * 0.95);
}

/**
 * Calculate target power for a bike workout interval
 * 
 * Formula: Target_Power = FTP * Template_Coefficient
 * 
 * @param ftp Functional Threshold Power in watts
 * @param coefficient Template coefficient (e.g., 1.05 for 105%)
 * @returns Target power in watts
 */
export function calculateBikeTargetPower(ftp: number, coefficient: number): number {
  return Math.round(ftp * coefficient);
}

/**
 * Calculate Power-to-Weight ratio (W/kg)
 * 
 * Formula: W/kg = FTP / Weight
 * 
 * @param ftp Functional Threshold Power in watts
 * @param weightKg Weight in kilograms
 * @returns Power-to-weight ratio
 */
export function calculateWattsPerKg(ftp: number, weightKg: number): number {
  if (weightKg <= 0) return 0;
  return parseFloat((ftp / weightKg).toFixed(2));
}

// ============================================
// PART 5: Heart Rate Zones
// ============================================

export interface HeartRateZones {
  zone1: { min: number; max: number; name: string };
  zone2: { min: number; max: number; name: string };
  zone3: { min: number; max: number; name: string };
  zone4: { min: number; max: number; name: string };
  zone5: { min: number; max: number; name: string };
}

/**
 * Calculate heart rate zones using Standard (Max HR) method
 * 
 * Zone percentages based on % of Max HR:
 * - Zone 1: 50-60% (Recovery)
 * - Zone 2: 60-75% (Endurance)
 * - Zone 3: 75-85% (Tempo)
 * - Zone 4: 85-95% (Threshold)
 * - Zone 5: 95-100% (VO2 Max)
 * 
 * @param maxHR Maximum heart rate in BPM
 * @returns Heart rate zones object
 */
export function calculateStandardHRZones(maxHR: number): HeartRateZones {
  return {
    zone1: { min: Math.round(maxHR * 0.50), max: Math.round(maxHR * 0.60), name: 'Recovery' },
    zone2: { min: Math.round(maxHR * 0.60), max: Math.round(maxHR * 0.75), name: 'Endurance' },
    zone3: { min: Math.round(maxHR * 0.75), max: Math.round(maxHR * 0.85), name: 'Tempo' },
    zone4: { min: Math.round(maxHR * 0.85), max: Math.round(maxHR * 0.95), name: 'Threshold' },
    zone5: { min: Math.round(maxHR * 0.95), max: maxHR, name: 'VO2 Max' },
  };
}

/**
 * Calculate heart rate zones using Karvonen method (more accurate)
 * 
 * Formula: Target_HR = ((Max_HR - Resting_HR) × %) + Resting_HR
 * 
 * This method uses Heart Rate Reserve (HRR) for more personalized zones.
 * 
 * @param maxHR Maximum heart rate in BPM
 * @param restingHR Resting heart rate in BPM
 * @returns Heart rate zones object
 */
export function calculateKarvonenHRZones(maxHR: number, restingHR: number): HeartRateZones {
  const hrr = maxHR - restingHR; // Heart Rate Reserve
  
  const karvonen = (pct: number) => Math.round((hrr * pct) + restingHR);
  
  return {
    zone1: { min: karvonen(0.50), max: karvonen(0.60), name: 'Recovery' },
    zone2: { min: karvonen(0.60), max: karvonen(0.75), name: 'Endurance' },
    zone3: { min: karvonen(0.75), max: karvonen(0.85), name: 'Tempo' },
    zone4: { min: karvonen(0.85), max: karvonen(0.95), name: 'Threshold' },
    zone5: { min: karvonen(0.95), max: maxHR, name: 'VO2 Max' },
  };
}

/**
 * Get heart rate zones using the appropriate method
 * Uses Karvonen if resting HR is available, otherwise Standard
 */
export function getHeartRateZones(maxHR: number, restingHR?: number): { 
  zones: HeartRateZones; 
  method: 'STANDARD' | 'KARVONEN' 
} {
  if (restingHR && restingHR > 0) {
    return {
      zones: calculateKarvonenHRZones(maxHR, restingHR),
      method: 'KARVONEN'
    };
  }
  return {
    zones: calculateStandardHRZones(maxHR),
    method: 'STANDARD'
  };
}

/**
 * Get target heart rate for a specific zone
 */
export function getTargetHRForZone(zones: HeartRateZones, zoneNumber: 1 | 2 | 3 | 4 | 5): number {
  const zone = zones[`zone${zoneNumber}` as keyof HeartRateZones];
  // Return midpoint of zone
  return Math.round((zone.min + zone.max) / 2);
}

// ============================================
// PART 6: Volume Tier Mapping
// ============================================

export type ExperienceLevel = 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED';

/**
 * Map experience level to training volume tier
 * 
 * BEGINNER -> Tier 1 (Light: 4-6 hrs/week)
 * INTERMEDIATE -> Tier 2 (Moderate: 7-10 hrs/week)
 * ADVANCED -> Tier 3 (High: 11+ hrs/week)
 */
export function mapExperienceToVolumeTier(experience: ExperienceLevel): 1 | 2 | 3 {
  switch (experience) {
    case 'BEGINNER': return 1;
    case 'INTERMEDIATE': return 2;
    case 'ADVANCED': return 3;
    default: return 1;
  }
}

// ============================================
// PART 7: Intensity Scalar Application
// ============================================

/**
 * Apply intensity scalar to a target value
 * 
 * Core Formula: Target_Intensity = Template_Coefficient × User_Biometric_Scalar × Intensity_Scalar
 * 
 * @param templateCoefficient The coefficient from the workout template
 * @param userScalar The user's baseline (CSS, FTP, or TP)
 * @param intensityScalar Adaptation scalar (default 1.0, reduced to 0.85 on fatigue)
 * @returns Calculated target intensity
 */
export function applyIntensityScalar(
  templateCoefficient: number,
  userScalar: number,
  intensityScalar: number = 1.0
): number {
  return Math.round(templateCoefficient * userScalar * intensityScalar);
}

// ============================================
// PART 8: Calorie Estimation
// ============================================

/**
 * Estimate calories burned during exercise
 * Uses MET values and body weight
 * 
 * @param workoutType Type of workout
 * @param durationMinutes Duration in minutes
 * @param weightKg Body weight in kg
 * @param intensity Intensity level (1-5)
 */
export function estimateCalories(
  workoutType: 'swim' | 'bike' | 'run' | 'strength' | 'brick',
  durationMinutes: number,
  weightKg: number,
  intensity: number = 3
): number {
  // MET values (Metabolic Equivalent of Task)
  const baseMET: Record<string, number> = {
    swim: 8.0,
    bike: 7.0,
    run: 9.0,
    strength: 5.0,
    brick: 8.5,
  };
  
  // Adjust MET based on intensity
  const intensityMultiplier = 0.8 + (intensity * 0.1); // 0.9 to 1.3
  const met = baseMET[workoutType] * intensityMultiplier;
  
  // Calorie formula: MET × Weight (kg) × Duration (hours)
  const durationHours = durationMinutes / 60;
  return Math.round(met * weightKg * durationHours);
}


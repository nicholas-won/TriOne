import { Router } from 'express';
import { supabase, OnboardingStatus, CalibrationMethod, Gender, DbBiometrics } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { generateTrainingPlan } from '../engine/planGenerator';
import { generateCalibrationWeek } from '../engine/calibrationWeek';
import { 
  calculateAge, 
  getMaxHR, 
  getHeartRateZones, 
  mapExperienceToVolumeTier,
  ExperienceLevel 
} from '../engine/biometricsCalculator';
import { v4 as uuid } from 'uuid';

export const userRoutes = Router();

// ============================================
// Type Definitions
// ============================================

interface OnboardingPayload {
  userId: string;
  // Physical Stats
  dateOfBirth: string; // ISO "1990-01-01"
  gender: Gender;
  height: number; // cm
  weight: number; // kg
  
  // Training Context
  primaryRaceId: string | null;
  experienceLevel: ExperienceLevel;
  hardware: {
    hasPowerMeterBike: boolean;
    hasSmartTrainer: boolean;
    hasHeartRateMonitor: boolean;
  };

  // Performance Data (Optional - Null if user chose "Test Me")
  manualBiometrics?: {
    ftp?: number; // watts
    css?: number; // seconds per 100m
    thresholdPace?: number; // seconds per mile
    maxHr?: number; // Optional user override
  };
  
  // Legacy support
  unitPreference?: 'imperial' | 'metric';
  customRace?: {
    name: string;
    date: string;
    swimDistance: number;
    bikeDistance: number;
    runDistance: number;
  };
  goalDistance?: 'sprint' | 'olympic' | '70.3' | '140.6';
}

// ============================================
// Routes
// ============================================

// Get current user profile
userRoutes.get('/me', async (req: AuthRequest, res) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('*, biometrics(*)')
      .eq('auth_id', req.userId)
      .single();

    if (error || !user) {
      // Create user if doesn't exist
      const { data: newUser, error: createError } = await supabase
        .from('users')
        .insert({
          id: uuid(),
          auth_id: req.userId,
          email: req.userEmail,
          subscription_status: 'trial',
          unit_preference: 'imperial',
          is_private: false,
          onboarding_status: 'STARTED',
          training_volume_tier: 1,
          calibration_method: 'MANUAL_INPUT',
        })
        .select()
        .single();

      if (createError) {
        return res.status(500).json({ message: 'Failed to create user' });
      }

      return res.json(newUser);
    }

    res.json(user);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ message: 'Failed to get user' });
  }
});

// Update user profile
userRoutes.patch('/me', async (req: AuthRequest, res) => {
  try {
    const allowedFields = [
      'display_name', 
      'unit_preference', 
      'is_private', 
      'avatar_url',
      'dob',
      'gender',
      'primary_race_id',
    ];
    const updates: Record<string, any> = {};
    
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    }

    const { data: user, error } = await supabase
      .from('users')
      .update(updates)
      .eq('auth_id', req.userId)
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to update user' });
    }

    res.json(user);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ message: 'Failed to update user' });
  }
});

/**
 * Complete Onboarding
 * 
 * Implements the Logic Fork from the algorithm spec:
 * - If manualBiometrics provided: Generate full training plan
 * - If manualBiometrics is NULL: Generate calibration week
 */
userRoutes.post('/onboarding/complete', async (req: AuthRequest, res) => {
  try {
    const payload: OnboardingPayload = req.body;

    // Get user
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('auth_id', req.userId)
      .single();

    if (userError || !user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // ==============================
    // Step 1: Calculate Age & Max HR
    // ==============================
    const age = calculateAge(payload.dateOfBirth);
    const maxHR = getMaxHR(payload.manualBiometrics?.maxHr, payload.dateOfBirth);
    
    console.log(`📊 User age: ${age}, Max HR: ${maxHR}`);

    // ==============================
    // Step 2: Determine Calibration Method
    // ==============================
    const hasManualBiometrics = !!(
      payload.manualBiometrics?.ftp ||
      payload.manualBiometrics?.css ||
      payload.manualBiometrics?.thresholdPace
    );
    
    const calibrationMethod: CalibrationMethod = hasManualBiometrics 
      ? 'MANUAL_INPUT' 
      : 'CALIBRATION_WEEK';
    
    const volumeTier = mapExperienceToVolumeTier(payload.experienceLevel);

    console.log(`🎯 Calibration method: ${calibrationMethod}, Volume tier: ${volumeTier}`);

    // ==============================
    // Step 3: Update User Record
    // ==============================
    const { data: updatedUser, error: updateError } = await supabase
      .from('users')
      .update({
        dob: payload.dateOfBirth,
        gender: payload.gender,
        onboarding_status: hasManualBiometrics ? 'COMPLETED' : 'BIOMETRICS_PENDING' as OnboardingStatus,
        training_volume_tier: volumeTier,
        calibration_method: calibrationMethod,
        primary_race_id: payload.primaryRaceId,
        experience_level: payload.experienceLevel.toLowerCase() === 'advanced' ? 'competitor' : 'finisher',
        unit_preference: payload.unitPreference || 'imperial',
      })
      .eq('id', user.id)
      .select()
      .single();

    if (updateError) {
      console.error('User update error:', updateError);
      return res.status(500).json({ message: 'Failed to update user' });
    }

    // ==============================
    // Step 4: Create/Update Biometrics
    // ==============================
    const biometricsData: Partial<DbBiometrics> = {
      user_id: user.id,
      recorded_at: new Date().toISOString(),
      height_cm: payload.height,
      weight_kg: payload.weight,
      max_heart_rate: maxHR,
    };

    // Add manual biometrics if provided
    if (payload.manualBiometrics) {
      if (payload.manualBiometrics.css) {
        biometricsData.critical_swim_speed = payload.manualBiometrics.css;
      }
      if (payload.manualBiometrics.ftp) {
        biometricsData.functional_threshold_power = payload.manualBiometrics.ftp;
      }
      if (payload.manualBiometrics.thresholdPace) {
        biometricsData.threshold_run_pace = payload.manualBiometrics.thresholdPace;
      }
    }

    // Upsert biometrics (insert or update)
    const { data: existingBio } = await supabase
      .from('biometrics')
      .select('id')
      .eq('user_id', user.id)
      .single();

    if (existingBio) {
      await supabase
        .from('biometrics')
        .update(biometricsData)
        .eq('user_id', user.id);
    } else {
      await supabase
        .from('biometrics')
        .insert({ id: uuid(), ...biometricsData });
    }

    // ==============================
    // Step 5: Create Heart Rate Zones
    // ==============================
    const { zones, method } = getHeartRateZones(maxHR, undefined);
    
    // Delete existing zones and insert new
    await supabase.from('heart_rate_zones').delete().eq('user_id', user.id);
    
    const zoneInserts = Object.entries(zones).map(([key, zone], index) => ({
      id: uuid(),
      user_id: user.id,
      zone_number: index + 1,
      min_hr: zone.min,
      max_hr: zone.max,
      calculation_method: method,
    }));
    
    await supabase.from('heart_rate_zones').insert(zoneInserts);

    // ==============================
    // Step 6: Initialize Training State
    // ==============================
    await supabase.from('user_training_state').upsert({
      user_id: user.id,
      current_fatigue_strikes: 0,
      acute_training_load: 0,
      chronic_training_load: 0,
      total_adaptations: 0,
      consecutive_completes: 0,
      updated_at: new Date().toISOString(),
    });

    // ==============================
    // Step 7: Handle Custom Race
    // ==============================
    let targetRaceId = payload.primaryRaceId;
    
    if (payload.customRace) {
      const { data: newRace, error: raceError } = await supabase
        .from('races')
        .insert({
          id: uuid(),
          name: payload.customRace.name,
          date: payload.customRace.date,
          location: 'Custom',
          distance_type: payload.goalDistance || 'olympic',
          swim_distance_meters: payload.customRace.swimDistance,
          bike_distance_meters: payload.customRace.bikeDistance,
          run_distance_meters: payload.customRace.runDistance,
          is_custom: true,
          user_id: user.id,
        })
        .select()
        .single();

      if (!raceError && newRace) {
        targetRaceId = newRace.id;
        
        // Update user's primary race
        await supabase
          .from('users')
          .update({ primary_race_id: newRace.id })
          .eq('id', user.id);
      }
    }

    // ==============================
    // Step 8: THE LOGIC FORK
    // ==============================
    let plan;
    
    // Check if user selected "No race" (maintenance mode)
    if (!targetRaceId) {
      // Maintenance mode - generate rolling base plan
      console.log('🔄 Generating maintenance plan (No race selected)...');
      
      const { generateMaintenancePlan } = await import('../engine/maintenanceGenerator');
      plan = await generateMaintenancePlan({
        userId: user.id,
        volumeTier,
        biometrics: biometricsData as any,
      });
    } else if (hasManualBiometrics) {
      // User provided biometrics -> Generate full Base Phase plan
      console.log('🏃 Generating full training plan (Manual Input)...');
      
      plan = await generateTrainingPlan({
        userId: user.id,
        raceId: targetRaceId,
        raceDistance: payload.goalDistance || 'olympic',
        volumeTier,
        biometrics: biometricsData as any,
        needsCalibration: false,
      });
    } else {
      // No biometrics -> Generate Calibration Week
      console.log('🧪 Generating calibration week (Test Me)...');
      
      plan = await generateCalibrationWeek(
        user.id,
        targetRaceId,
        payload.goalDistance || 'olympic',
        volumeTier
      );
    }

    res.json({ 
      user: updatedUser, 
      plan,
      calibrationRequired: !hasManualBiometrics,
      heartRateZones: zones,
    });

  } catch (error) {
    console.error('Onboarding error:', error);
    res.status(500).json({ message: 'Failed to complete onboarding' });
  }
});

// Legacy onboarding endpoint (redirects to new one)
userRoutes.post('/onboarding', async (req: AuthRequest, res) => {
  // Transform legacy payload to new format
  const {
    goal_distance,
    race_id,
    custom_race,
    experience_level,
    swim_pace,
    run_pace,
    bike_ftp,
    has_heart_rate_monitor,
    unit_preference,
  } = req.body;

  const newPayload: Partial<OnboardingPayload> = {
    primaryRaceId: race_id,
    experienceLevel: (experience_level === 'competitor' ? 'ADVANCED' : 'BEGINNER') as ExperienceLevel,
    goalDistance: goal_distance,
    unitPreference: unit_preference,
    customRace: custom_race ? {
      name: custom_race.name,
      date: custom_race.date,
      swimDistance: custom_race.swim_distance,
      bikeDistance: custom_race.bike_distance,
      runDistance: custom_race.run_distance,
    } : undefined,
    hardware: {
      hasHeartRateMonitor: has_heart_rate_monitor || false,
      hasPowerMeterBike: bike_ftp !== 'unknown',
      hasSmartTrainer: false,
    },
  };

  // Add biometrics if not "unknown"
  if (swim_pace !== 'unknown' || run_pace !== 'unknown' || bike_ftp !== 'unknown') {
    newPayload.manualBiometrics = {};
    if (swim_pace !== 'unknown') newPayload.manualBiometrics.css = swim_pace;
    if (run_pace !== 'unknown') newPayload.manualBiometrics.thresholdPace = run_pace;
    if (bike_ftp !== 'unknown') newPayload.manualBiometrics.ftp = bike_ftp;
  }

  // Forward to new endpoint by updating the request body
  req.body = newPayload;
  
  // Manually call the new endpoint handler
  // Get the handler from the route (we'll need to extract it)
  // For now, just return an error directing to use the new endpoint
  return res.status(410).json({ 
    message: 'This endpoint is deprecated. Please use /api/users/onboarding/complete',
    redirect: '/api/users/onboarding/complete'
  });
});

// Activate trial
userRoutes.post('/activate-trial', async (req: AuthRequest, res) => {
  try {
    const trialEndsAt = new Date();
    trialEndsAt.setDate(trialEndsAt.getDate() + 14);

    const { data: user, error } = await supabase
      .from('users')
      .update({
        subscription_status: 'trial',
        trial_ends_at: trialEndsAt.toISOString(),
      })
      .eq('auth_id', req.userId)
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to activate trial' });
    }

    res.json(user);
  } catch (error) {
    console.error('Activate trial error:', error);
    res.status(500).json({ message: 'Failed to activate trial' });
  }
});

// Get user's heart rate zones
userRoutes.get('/heart-rate-zones', async (req: AuthRequest, res) => {
  try {
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { data: zones, error } = await supabase
      .from('heart_rate_zones')
      .select('*')
      .eq('user_id', user.id)
      .order('zone_number', { ascending: true });

    if (error) {
      return res.status(500).json({ message: 'Failed to get heart rate zones' });
    }

    res.json(zones);
  } catch (error) {
    console.error('Get HR zones error:', error);
    res.status(500).json({ message: 'Failed to get heart rate zones' });
  }
});

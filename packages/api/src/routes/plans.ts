import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { generateTrainingPlan } from '../engine/planGenerator';

export const planRoutes = Router();

// Get active plan
planRoutes.get('/active', async (req: AuthRequest, res) => {
  try {
    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { data: plan, error } = await supabase
      .from('training_plans')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .single();

    if (error || !plan) {
      return res.status(404).json({ message: 'No active plan found' });
    }

    res.json(plan);
  } catch (error) {
    console.error('Get active plan error:', error);
    res.status(500).json({ message: 'Failed to fetch plan' });
  }
});

// Get all plans
planRoutes.get('/', async (req: AuthRequest, res) => {
  try {
    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { data: plans, error } = await supabase
      .from('training_plans')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch plans' });
    }

    res.json(plans || []);
  } catch (error) {
    console.error('Get plans error:', error);
    res.status(500).json({ message: 'Failed to fetch plans' });
  }
});

// Create new plan
planRoutes.post('/', async (req: AuthRequest, res) => {
  try {
    const { race_id, custom_race } = req.body;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get latest biometrics
    const { data: biometrics } = await supabase
      .from('biometrics')
      .select('*')
      .eq('user_id', user.id)
      .order('recorded_at', { ascending: false })
      .limit(1)
      .single();

    // Archive any existing active plans
    await supabase
      .from('training_plans')
      .update({ status: 'archived' })
      .eq('user_id', user.id)
      .eq('status', 'active');

    // Determine race details
    let raceDistance = 'olympic';
    let targetRaceId = race_id;

    if (race_id) {
      const { data: race } = await supabase
        .from('races')
        .select('distance_type')
        .eq('id', race_id)
        .single();
      if (race) raceDistance = race.distance_type;
    }

    // Generate new plan
    const plan = await generateTrainingPlan({
      userId: user.id,
      raceId: targetRaceId,
      raceDistance,
      experienceLevel: user.experience_level || 'finisher',
      needsCalibration: !biometrics?.css_pace_per_100 || !biometrics?.run_threshold_pace_per_mile || !biometrics?.bike_ftp,
      biometrics: biometrics || {},
    });

    res.json(plan);
  } catch (error) {
    console.error('Create plan error:', error);
    res.status(500).json({ message: 'Failed to create plan' });
  }
});


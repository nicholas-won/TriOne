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
    let raceDistance: 'sprint' | 'olympic' | '70.3' | '140.6' = 'olympic';
    let targetRaceId = race_id;

    if (race_id) {
      const { data: race } = await supabase
        .from('races')
        .select('distance_type')
        .eq('id', race_id)
        .single();
      if (race) {
        raceDistance = race.distance_type as 'sprint' | 'olympic' | '70.3' | '140.6';
      }
    }

    // Get volume tier from user
    const volumeTier = (user.training_volume_tier || 1) as 1 | 2 | 3;

    // Generate new plan
    const plan = await generateTrainingPlan({
      userId: user.id,
      raceId: targetRaceId,
      raceDistance,
      volumeTier,
      biometrics: biometrics || {},
      needsCalibration: !biometrics?.critical_swim_speed || !biometrics?.threshold_run_pace || !biometrics?.functional_threshold_power,
    });

    res.json(plan);
  } catch (error) {
    console.error('Create plan error:', error);
    res.status(500).json({ message: 'Failed to create plan' });
  }
});

// Transition from maintenance to race prep
planRoutes.post('/transition-to-race', async (req: AuthRequest, res) => {
  try {
    const { race_id, race_distance } = req.body;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get active maintenance plan
    const { data: maintenancePlan } = await supabase
      .from('training_plans')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .eq('plan_type', 'maintenance')
      .single();

    if (!maintenancePlan) {
      return res.status(404).json({ message: 'No active maintenance plan found' });
    }

    // Get race details
    let raceDate: Date;
    let raceName: string;
    let raceDistance = race_distance || 'olympic';

    if (race_id) {
      const { data: race } = await supabase
        .from('races')
        .select('*')
        .eq('id', race_id)
        .single();
      
      if (race) {
        raceDate = new Date(race.date);
        raceName = race.name;
        raceDistance = race.distance_type;
      } else {
        return res.status(404).json({ message: 'Race not found' });
      }
    } else {
      return res.status(400).json({ message: 'Race ID required' });
    }

    // Delete future maintenance workouts
    const today = new Date().toISOString().split('T')[0];
    await supabase
      .from('workouts')
      .delete()
      .eq('plan_id', maintenancePlan.id)
      .gte('scheduled_date', today);

    // Archive maintenance plan
    await supabase
      .from('training_plans')
      .update({ status: 'archived' })
      .eq('id', maintenancePlan.id);

    // Get latest biometrics
    const { data: biometrics } = await supabase
      .from('biometrics')
      .select('*')
      .eq('user_id', user.id)
      .order('recorded_at', { ascending: false })
      .limit(1)
      .single();

    // Generate race prep plan
    const newPlan = await generateTrainingPlan({
      userId: user.id,
      raceId: race_id,
      raceDistance: raceDistance as 'sprint' | 'olympic' | '70.3' | '140.6',
      volumeTier: maintenancePlan.volume_tier,
      biometrics: biometrics || {},
      needsCalibration: false,
    });

    // Update user's primary race
    await supabase
      .from('users')
      .update({ primary_race_id: race_id })
      .eq('id', user.id);

    res.json({ 
      message: 'Successfully transitioned from maintenance to race prep',
      plan: newPlan 
    });
  } catch (error) {
    console.error('Transition error:', error);
    res.status(500).json({ message: 'Failed to transition plan' });
  }
});


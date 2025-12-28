import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { v4 as uuid } from 'uuid';
import { handleWorkoutCompletion } from '../engine/adaptationEngine';

export const workoutRoutes = Router();

// Get workouts by date range
workoutRoutes.get('/', async (req: AuthRequest, res) => {
  try {
    const { start, end } = req.query;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get active plan
    const { data: plan } = await supabase
      .from('training_plans')
      .select('id')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .single();

    if (!plan) {
      return res.json([]);
    }

    let query = supabase
      .from('workouts')
      .select('*')
      .eq('plan_id', plan.id)
      .order('scheduled_date', { ascending: true });

    if (start) {
      query = query.gte('scheduled_date', start as string);
    }
    if (end) {
      query = query.lte('scheduled_date', end as string);
    }

    const { data: workouts, error } = await query;

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch workouts' });
    }

    res.json(workouts || []);
  } catch (error) {
    console.error('Get workouts error:', error);
    res.status(500).json({ message: 'Failed to fetch workouts' });
  }
});

// Get today's workout
workoutRoutes.get('/today', async (req: AuthRequest, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get active plan
    const { data: plan } = await supabase
      .from('training_plans')
      .select('id')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .single();

    if (!plan) {
      return res.json(null);
    }

    const { data: workout } = await supabase
      .from('workouts')
      .select('*')
      .eq('plan_id', plan.id)
      .eq('scheduled_date', today)
      .eq('status', 'planned')
      .single();

    res.json(workout || null);
  } catch (error) {
    console.error('Get today workout error:', error);
    res.status(500).json({ message: 'Failed to fetch today workout' });
  }
});

// Get week workouts
workoutRoutes.get('/week', async (req: AuthRequest, res) => {
  try {
    const dateParam = req.query.date as string | undefined;
    const targetDate = dateParam ? new Date(dateParam) : new Date();
    
    // Get Monday of the week
    const dayOfWeek = targetDate.getDay();
    const monday = new Date(targetDate);
    monday.setDate(targetDate.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
    
    // Get Sunday of the week
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);

    const start = monday.toISOString().split('T')[0];
    const end = sunday.toISOString().split('T')[0];

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get active plan
    const { data: plan } = await supabase
      .from('training_plans')
      .select('id')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .single();

    if (!plan) {
      return res.json([]);
    }

    const { data: workouts, error } = await supabase
      .from('workouts')
      .select('*')
      .eq('plan_id', plan.id)
      .gte('scheduled_date', start)
      .lte('scheduled_date', end)
      .order('scheduled_date', { ascending: true });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch workouts' });
    }

    res.json(workouts || []);
  } catch (error) {
    console.error('Get week workouts error:', error);
    res.status(500).json({ message: 'Failed to fetch workouts' });
  }
});

// Get workout by ID
workoutRoutes.get('/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;

    const { data: workout, error } = await supabase
      .from('workouts')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !workout) {
      return res.status(404).json({ message: 'Workout not found' });
    }

    res.json(workout);
  } catch (error) {
    console.error('Get workout error:', error);
    res.status(500).json({ message: 'Failed to fetch workout' });
  }
});

// Complete workout
workoutRoutes.post('/:id/complete', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { total_duration_seconds, total_distance_meters, avg_heart_rate, source, route_data } = req.body;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Update workout status
    const { error: updateError } = await supabase
      .from('workouts')
      .update({ status: 'completed' })
      .eq('id', id);

    if (updateError) {
      return res.status(500).json({ message: 'Failed to update workout' });
    }

    // Create activity log
    const activityLog = {
      id: uuid(),
      workout_id: id,
      user_id: user.id,
      completed_at: new Date().toISOString(),
      total_duration_seconds,
      total_distance_meters,
      avg_heart_rate,
      source: source || 'active_mode_recording',
      route_data,
    };

    const { data: activity, error: activityError } = await supabase
      .from('activity_logs')
      .insert(activityLog)
      .select()
      .single();

    if (activityError) {
      return res.status(500).json({ message: 'Failed to create activity log' });
    }

    // Process adaptation logic
    await handleWorkoutCompletion(user.id, id);

    res.json(activity);
  } catch (error) {
    console.error('Complete workout error:', error);
    res.status(500).json({ message: 'Failed to complete workout' });
  }
});

// Skip workout
workoutRoutes.post('/:id/skip', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;

    const { data: workout, error } = await supabase
      .from('workouts')
      .update({ status: 'skipped' })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to skip workout' });
    }

    res.json(workout);
  } catch (error) {
    console.error('Skip workout error:', error);
    res.status(500).json({ message: 'Failed to skip workout' });
  }
});


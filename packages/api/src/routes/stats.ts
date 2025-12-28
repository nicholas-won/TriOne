import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';

export const statsRoutes = Router();

// Get weekly summary
statsRoutes.get('/weekly', async (req: AuthRequest, res) => {
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
      return res.json({
        planned_duration: 0,
        actual_duration: 0,
        completed_workouts: 0,
        total_workouts: 0,
        by_type: {},
      });
    }

    // Get workouts for the week
    const { data: workouts } = await supabase
      .from('workouts')
      .select('*')
      .eq('plan_id', plan.id)
      .gte('scheduled_date', start)
      .lte('scheduled_date', end);

    // Get activity logs for the week
    const workoutIds = workouts?.map(w => w.id) || [];
    const { data: activities } = await supabase
      .from('activity_logs')
      .select('*')
      .in('workout_id', workoutIds);

    // Calculate stats
    const totalWorkouts = workouts?.length || 0;
    const completedWorkouts = workouts?.filter(w => w.status === 'completed').length || 0;
    
    const plannedDuration = workouts?.reduce((sum, w) => {
      return sum + (w.calculated_structure?.total_duration || 0);
    }, 0) || 0;

    const actualDuration = activities?.reduce((sum, a) => {
      return sum + (a.total_duration_seconds || 0);
    }, 0) || 0;

    // By type
    const byType: Record<string, { planned: number; actual: number }> = {};
    
    workouts?.forEach(w => {
      if (!byType[w.workout_type]) {
        byType[w.workout_type] = { planned: 0, actual: 0 };
      }
      byType[w.workout_type].planned += w.calculated_structure?.total_duration || 0;
    });

    activities?.forEach(a => {
      const workout = workouts?.find(w => w.id === a.workout_id);
      if (workout && byType[workout.workout_type]) {
        byType[workout.workout_type].actual += a.total_duration_seconds || 0;
      }
    });

    res.json({
      planned_duration: plannedDuration,
      actual_duration: actualDuration,
      completed_workouts: completedWorkouts,
      total_workouts: totalWorkouts,
      by_type: byType,
    });
  } catch (error) {
    console.error('Get weekly stats error:', error);
    res.status(500).json({ message: 'Failed to fetch stats' });
  }
});


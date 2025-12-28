import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { v4 as uuid } from 'uuid';
import { processFeedback } from '../engine/adaptationEngine';

export const feedbackRoutes = Router();

// Submit feedback for a completed workout
feedbackRoutes.post('/', async (req: AuthRequest, res) => {
  try {
    const { activity_log_id, rating, rpe } = req.body;

    if (!activity_log_id || !rating) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    if (!['easier', 'same', 'harder'].includes(rating)) {
      return res.status(400).json({ message: 'Invalid rating' });
    }

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get activity log to find comparison reference
    const { data: activityLog } = await supabase
      .from('activity_logs')
      .select('*, workout:workouts(*)')
      .eq('id', activity_log_id)
      .single();

    if (!activityLog) {
      return res.status(404).json({ message: 'Activity not found' });
    }

    // Find the previous similar workout for comparison
    const { data: previousSimilar } = await supabase
      .from('activity_logs')
      .select('id')
      .eq('user_id', user.id)
      .neq('id', activity_log_id)
      .lt('completed_at', activityLog.completed_at)
      .order('completed_at', { ascending: false })
      .limit(1)
      .single();

    // Create feedback log
    const { data: feedback, error } = await supabase
      .from('feedback_logs')
      .insert({
        id: uuid(),
        activity_log_id,
        comparison_ref_id: previousSimilar?.id,
        feedback_rating: rating,
        rpe_score: rpe,
      })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to submit feedback' });
    }

    // Process feedback through adaptation engine
    await processFeedback(user.id, req.params.id, rating);

    res.json(feedback);
  } catch (error) {
    console.error('Submit feedback error:', error);
    res.status(500).json({ message: 'Failed to submit feedback' });
  }
});


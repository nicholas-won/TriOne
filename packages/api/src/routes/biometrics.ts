import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { v4 as uuid } from 'uuid';

export const biometricsRoutes = Router();

// Get current biometrics
biometricsRoutes.get('/current', async (req: AuthRequest, res) => {
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

    const { data: biometrics, error } = await supabase
      .from('biometrics')
      .select('*')
      .eq('user_id', user.id)
      .order('recorded_at', { ascending: false })
      .limit(1)
      .single();

    if (error || !biometrics) {
      return res.status(404).json({ message: 'No biometrics found' });
    }

    res.json(biometrics);
  } catch (error) {
    console.error('Get biometrics error:', error);
    res.status(500).json({ message: 'Failed to fetch biometrics' });
  }
});

// Get biometrics history
biometricsRoutes.get('/history', async (req: AuthRequest, res) => {
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

    const { data: biometrics, error } = await supabase
      .from('biometrics')
      .select('*')
      .eq('user_id', user.id)
      .order('recorded_at', { ascending: false });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch biometrics' });
    }

    res.json(biometrics || []);
  } catch (error) {
    console.error('Get biometrics history error:', error);
    res.status(500).json({ message: 'Failed to fetch biometrics' });
  }
});

// Update biometrics
biometricsRoutes.post('/', async (req: AuthRequest, res) => {
  try {
    const { css_pace_per_100, run_threshold_pace_per_mile, bike_ftp, max_heart_rate, resting_heart_rate, calibration_source } = req.body;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { data: biometrics, error } = await supabase
      .from('biometrics')
      .insert({
        id: uuid(),
        user_id: user.id,
        recorded_at: new Date().toISOString(),
        css_pace_per_100,
        run_threshold_pace_per_mile,
        bike_ftp,
        max_heart_rate,
        resting_heart_rate,
        calibration_source: calibration_source || 'manual_entry',
      })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to update biometrics' });
    }

    res.json(biometrics);
  } catch (error) {
    console.error('Update biometrics error:', error);
    res.status(500).json({ message: 'Failed to update biometrics' });
  }
});


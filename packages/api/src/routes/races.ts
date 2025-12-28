import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { v4 as uuid } from 'uuid';

export const raceRoutes = Router();

// Search races
raceRoutes.get('/search', async (req: AuthRequest, res) => {
  try {
    const { q } = req.query;
    
    let query = supabase
      .from('races')
      .select('*')
      .eq('is_custom', false)
      .gte('date', new Date().toISOString().split('T')[0])
      .order('date', { ascending: true });

    if (q) {
      query = query.or(`name.ilike.%${q}%,location.ilike.%${q}%`);
    }

    const { data: races, error } = await query.limit(50);

    if (error) {
      return res.status(500).json({ message: 'Failed to search races' });
    }

    res.json(races || []);
  } catch (error) {
    console.error('Search races error:', error);
    res.status(500).json({ message: 'Failed to search races' });
  }
});

// Get all races (public + user's custom)
raceRoutes.get('/', async (req: AuthRequest, res) => {
  try {
    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    const { data: races, error } = await supabase
      .from('races')
      .select('*')
      .or(`is_custom.eq.false,user_id.eq.${user?.id}`)
      .gte('date', new Date().toISOString().split('T')[0])
      .order('date', { ascending: true });

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch races' });
    }

    res.json(races || []);
  } catch (error) {
    console.error('Get races error:', error);
    res.status(500).json({ message: 'Failed to fetch races' });
  }
});

// Get race by ID
raceRoutes.get('/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;

    const { data: race, error } = await supabase
      .from('races')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !race) {
      return res.status(404).json({ message: 'Race not found' });
    }

    res.json(race);
  } catch (error) {
    console.error('Get race error:', error);
    res.status(500).json({ message: 'Failed to fetch race' });
  }
});

// Create custom race
raceRoutes.post('/custom', async (req: AuthRequest, res) => {
  try {
    const { name, date, location, distance_type, swim_distance_meters, bike_distance_meters, run_distance_meters } = req.body;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { data: race, error } = await supabase
      .from('races')
      .insert({
        id: uuid(),
        name,
        date,
        location: location || 'Custom',
        distance_type,
        swim_distance_meters,
        bike_distance_meters,
        run_distance_meters,
        is_custom: true,
        user_id: user.id,
      })
      .select()
      .single();

    if (error) {
      return res.status(500).json({ message: 'Failed to create race' });
    }

    res.json(race);
  } catch (error) {
    console.error('Create race error:', error);
    res.status(500).json({ message: 'Failed to create race' });
  }
});


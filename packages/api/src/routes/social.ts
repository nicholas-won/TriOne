import { Router } from 'express';
import { supabase } from '../db/supabase';
import { AuthRequest } from '../middleware/auth';
import { v4 as uuid } from 'uuid';

export const socialRoutes = Router();

// Get activity feed
socialRoutes.get('/feed', async (req: AuthRequest, res) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = 20;
    const offset = (page - 1) * limit;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Get friends
    const { data: friendships } = await supabase
      .from('friendships')
      .select('friend_id')
      .eq('user_id', user.id)
      .eq('status', 'accepted');

    const friendIds = friendships?.map(f => f.friend_id) || [];

    // Include self in feed
    friendIds.push(user.id);

    // Get activities from friends (and public users)
    const { data: activities, error } = await supabase
      .from('activity_logs')
      .select(`
        *,
        user:users!activity_logs_user_id_fkey(id, email, display_name, avatar_url, is_private)
      `)
      .in('user_id', friendIds)
      .order('completed_at', { ascending: false })
      .range(offset, offset + limit);

    if (error) {
      console.error('Feed error:', error);
      return res.status(500).json({ message: 'Failed to fetch feed' });
    }

    // Get kudos counts and whether current user has given kudos
    const activityIds = activities?.map(a => a.id) || [];
    
    const { data: kudosCounts } = await supabase
      .from('kudos')
      .select('activity_log_id')
      .in('activity_log_id', activityIds);

    const { data: userKudos } = await supabase
      .from('kudos')
      .select('activity_log_id')
      .in('activity_log_id', activityIds)
      .eq('user_id', user.id);

    const kudosCountMap: Record<string, number> = {};
    kudosCounts?.forEach(k => {
      kudosCountMap[k.activity_log_id] = (kudosCountMap[k.activity_log_id] || 0) + 1;
    });

    const userKudosSet = new Set(userKudos?.map(k => k.activity_log_id));

    const enrichedActivities = activities?.map(a => ({
      ...a,
      kudos_count: kudosCountMap[a.id] || 0,
      has_kudos: userKudosSet.has(a.id),
    })) || [];

    res.json({
      activities: enrichedActivities,
      hasMore: activities?.length === limit,
    });
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({ message: 'Failed to fetch feed' });
  }
});

// Give kudos
socialRoutes.post('/kudos/:activityLogId', async (req: AuthRequest, res) => {
  try {
    const { activityLogId } = req.params;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if already given kudos
    const { data: existing } = await supabase
      .from('kudos')
      .select('id')
      .eq('activity_log_id', activityLogId)
      .eq('user_id', user.id)
      .single();

    if (existing) {
      return res.status(400).json({ message: 'Already given kudos' });
    }

    const { error } = await supabase
      .from('kudos')
      .insert({
        id: uuid(),
        activity_log_id: activityLogId,
        user_id: user.id,
        created_at: new Date().toISOString(),
      });

    if (error) {
      return res.status(500).json({ message: 'Failed to give kudos' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Give kudos error:', error);
    res.status(500).json({ message: 'Failed to give kudos' });
  }
});

// Remove kudos
socialRoutes.delete('/kudos/:activityLogId', async (req: AuthRequest, res) => {
  try {
    const { activityLogId } = req.params;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const { error } = await supabase
      .from('kudos')
      .delete()
      .eq('activity_log_id', activityLogId)
      .eq('user_id', user.id);

    if (error) {
      return res.status(500).json({ message: 'Failed to remove kudos' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Remove kudos error:', error);
    res.status(500).json({ message: 'Failed to remove kudos' });
  }
});

// Get friends list
socialRoutes.get('/friends', async (req: AuthRequest, res) => {
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

    const { data: friendships, error } = await supabase
      .from('friendships')
      .select(`
        friend:users!friendships_friend_id_fkey(id, email, display_name, avatar_url)
      `)
      .eq('user_id', user.id)
      .eq('status', 'accepted');

    if (error) {
      return res.status(500).json({ message: 'Failed to fetch friends' });
    }

    const friends = friendships?.map(f => f.friend) || [];
    res.json(friends);
  } catch (error) {
    console.error('Get friends error:', error);
    res.status(500).json({ message: 'Failed to fetch friends' });
  }
});

// Add friend
socialRoutes.post('/friends/:userId', async (req: AuthRequest, res) => {
  try {
    const { userId: friendId } = req.params;

    // Get user
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('auth_id', req.userId)
      .single();

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Create friendship (auto-accept for now)
    const { error } = await supabase
      .from('friendships')
      .insert({
        id: uuid(),
        user_id: user.id,
        friend_id: friendId,
        status: 'accepted',
        created_at: new Date().toISOString(),
      });

    if (error) {
      return res.status(500).json({ message: 'Failed to add friend' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Add friend error:', error);
    res.status(500).json({ message: 'Failed to add friend' });
  }
});


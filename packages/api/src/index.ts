import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { userRoutes } from './routes/users';
import { workoutRoutes } from './routes/workouts';
import { planRoutes } from './routes/plans';
import { raceRoutes } from './routes/races';
import { socialRoutes } from './routes/social';
import { feedbackRoutes } from './routes/feedback';
import { biometricsRoutes } from './routes/biometrics';
import { statsRoutes } from './routes/stats';
import { authMiddleware } from './middleware/auth';
import { processMissedWorkouts } from './engine/scheduler';
import { checkAndGenerateMaintenanceWorkouts } from './engine/maintenanceGenerator';

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Protected routes
app.use('/api/users', authMiddleware, userRoutes);
app.use('/api/workouts', authMiddleware, workoutRoutes);
app.use('/api/plans', authMiddleware, planRoutes);
app.use('/api/races', authMiddleware, raceRoutes);
app.use('/api/social', authMiddleware, socialRoutes);
app.use('/api/feedback', authMiddleware, feedbackRoutes);
app.use('/api/biometrics', authMiddleware, biometricsRoutes);
app.use('/api/stats', authMiddleware, statsRoutes);

// Error handler
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`🚀 TriOne API running on port ${PORT}`);
  
  // Set up daily cron jobs
  setupCronJobs();
});

// ============================================
// Cron Jobs
// ============================================

function setupCronJobs() {
  // Calculate milliseconds until next 00:01
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 1, 0, 0); // 00:01
  
  const msUntilMidnight = tomorrow.getTime() - now.getTime();
  
  // Schedule first run
  setTimeout(() => {
    runDailyJobs();
    
    // Then run every 24 hours
    setInterval(runDailyJobs, 24 * 60 * 60 * 1000);
  }, msUntilMidnight);
  
  console.log(`⏰ Cron jobs scheduled. Next run at ${tomorrow.toISOString()}`);
}

async function runDailyJobs() {
  console.log('🔄 Running daily cron jobs...');
  
  try {
    // Job 1: Process missed workouts
    const schedulerResult = await processMissedWorkouts();
    console.log(`✅ Scheduler: ${schedulerResult.processed} processed, ${schedulerResult.deleted} deleted, ${schedulerResult.rescheduled} rescheduled`);
    
    // Job 2: Generate maintenance workouts if needed
    const maintenanceResult = await checkAndGenerateMaintenanceWorkouts();
    console.log(`✅ Maintenance: ${maintenanceResult.plansChecked} plans checked, ${maintenanceResult.weeksGenerated} weeks generated`);
  } catch (error) {
    console.error('❌ Cron job error:', error);
  }
}

export default app;


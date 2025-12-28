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
});

export default app;


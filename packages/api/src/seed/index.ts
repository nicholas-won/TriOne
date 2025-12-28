import 'dotenv/config';
import { supabase } from '../db/supabase';
import { workoutTemplates } from './workoutTemplates';
import { races } from './races';

async function seed() {
  console.log('🌱 Starting seed...');

  // Seed workout templates
  console.log('Seeding workout templates...');
  const { error: templatesError } = await supabase
    .from('workout_templates')
    .upsert(workoutTemplates, { onConflict: 'id' });

  if (templatesError) {
    console.error('Failed to seed templates:', templatesError);
  } else {
    console.log(`✅ Seeded ${workoutTemplates.length} workout templates`);
  }

  // Seed races
  console.log('Seeding races...');
  const { error: racesError } = await supabase
    .from('races')
    .upsert(races, { onConflict: 'id' });

  if (racesError) {
    console.error('Failed to seed races:', racesError);
  } else {
    console.log(`✅ Seeded ${races.length} races`);
  }

  console.log('🎉 Seed complete!');
}

seed().catch(console.error);


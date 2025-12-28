export const workoutTemplates = [
  // SWIM WORKOUTS
  {
    id: '11111111-1111-1111-1111-111111111001',
    name: 'Endurance Swim',
    type: 'swim',
    difficulty_tier: 2,
    description: 'Building aerobic capacity in the water',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy freestyle' },
        { type: 'main', duration: 1800, target_zone: 2, description: 'Steady-state swimming' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy backstroke or choice' },
      ],
    },
  },
  {
    id: '11111111-1111-1111-1111-111111111002',
    name: 'Threshold Intervals',
    type: 'swim',
    difficulty_tier: 4,
    description: 'Building speed and lactate threshold',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy swimming with drills' },
        { type: 'interval', duration: 120, target_zone: 4, description: '100m hard' },
        { type: 'rest', duration: 30, target_zone: 1, description: 'Rest at wall' },
        { type: 'interval', duration: 120, target_zone: 4, description: '100m hard' },
        { type: 'rest', duration: 30, target_zone: 1, description: 'Rest at wall' },
        { type: 'interval', duration: 120, target_zone: 4, description: '100m hard' },
        { type: 'rest', duration: 30, target_zone: 1, description: 'Rest at wall' },
        { type: 'interval', duration: 120, target_zone: 4, description: '100m hard' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy swimming' },
      ],
    },
  },
  {
    id: '11111111-1111-1111-1111-111111111003',
    name: 'Technique & Drills',
    type: 'swim',
    difficulty_tier: 2,
    description: 'Improving swim efficiency',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 400, target_zone: 1, description: 'Easy freestyle' },
        { type: 'main', duration: 300, target_zone: 2, description: 'Catch-up drill' },
        { type: 'main', duration: 300, target_zone: 2, description: 'Fingertip drag drill' },
        { type: 'main', duration: 300, target_zone: 2, description: 'Single-arm freestyle' },
        { type: 'main', duration: 600, target_zone: 2, description: 'Full stroke focus' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy choice stroke' },
      ],
    },
  },

  // BIKE WORKOUTS
  {
    id: '22222222-2222-2222-2222-222222222001',
    name: 'Endurance Ride',
    type: 'bike',
    difficulty_tier: 2,
    description: 'Building aerobic base on the bike',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy spinning' },
        { type: 'main', duration: 3600, target_zone: 2, description: 'Steady endurance pace' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy spin down' },
      ],
    },
  },
  {
    id: '22222222-2222-2222-2222-222222222002',
    name: 'Threshold Intervals',
    type: 'bike',
    difficulty_tier: 4,
    description: 'Building FTP and sustainable power',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 900, target_zone: 1, description: 'Easy spinning with accelerations' },
        { type: 'interval', duration: 480, target_zone: 4, percent_ftp: 1.0, description: '8 min at threshold' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy spinning' },
        { type: 'interval', duration: 480, target_zone: 4, percent_ftp: 1.0, description: '8 min at threshold' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy spinning' },
        { type: 'interval', duration: 480, target_zone: 4, percent_ftp: 1.0, description: '8 min at threshold' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy spinning' },
        { type: 'interval', duration: 480, target_zone: 4, percent_ftp: 1.0, description: '8 min at threshold' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy spin down' },
      ],
    },
  },
  {
    id: '22222222-2222-2222-2222-222222222003',
    name: 'VO2 Max Intervals',
    type: 'bike',
    difficulty_tier: 5,
    description: 'Pushing aerobic ceiling',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 900, target_zone: 1, description: 'Progressive warmup' },
        { type: 'interval', duration: 180, target_zone: 5, percent_ftp: 1.15, description: '3 min VO2 effort' },
        { type: 'rest', duration: 180, target_zone: 1, description: 'Recovery spin' },
        { type: 'interval', duration: 180, target_zone: 5, percent_ftp: 1.15, description: '3 min VO2 effort' },
        { type: 'rest', duration: 180, target_zone: 1, description: 'Recovery spin' },
        { type: 'interval', duration: 180, target_zone: 5, percent_ftp: 1.15, description: '3 min VO2 effort' },
        { type: 'rest', duration: 180, target_zone: 1, description: 'Recovery spin' },
        { type: 'interval', duration: 180, target_zone: 5, percent_ftp: 1.15, description: '3 min VO2 effort' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy spin down' },
      ],
    },
  },
  {
    id: '22222222-2222-2222-2222-222222222004',
    name: 'Long Ride',
    type: 'bike',
    difficulty_tier: 3,
    description: 'Building endurance for race distance',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy warmup' },
        { type: 'main', duration: 7200, target_zone: 2, description: 'Steady endurance effort' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy cool down' },
      ],
    },
  },

  // RUN WORKOUTS
  {
    id: '33333333-3333-3333-3333-333333333001',
    name: 'Easy Run',
    type: 'run',
    difficulty_tier: 1,
    description: 'Recovery and aerobic maintenance',
    structure_json: {
      steps: [
        { type: 'main', duration: 2400, target_zone: 1, description: 'Easy conversational pace' },
      ],
    },
  },
  {
    id: '33333333-3333-3333-3333-333333333002',
    name: 'Tempo Run',
    type: 'run',
    difficulty_tier: 3,
    description: 'Building lactate threshold',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy jog' },
        { type: 'main', duration: 1200, target_zone: 4, description: 'Tempo effort - comfortably hard' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy jog' },
      ],
    },
  },
  {
    id: '33333333-3333-3333-3333-333333333003',
    name: 'Interval Run',
    type: 'run',
    difficulty_tier: 4,
    description: 'Speed development and VO2 Max',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy jog with strides' },
        { type: 'interval', duration: 180, target_zone: 5, description: '3 min hard' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy jog recovery' },
        { type: 'interval', duration: 180, target_zone: 5, description: '3 min hard' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy jog recovery' },
        { type: 'interval', duration: 180, target_zone: 5, description: '3 min hard' },
        { type: 'rest', duration: 120, target_zone: 1, description: 'Easy jog recovery' },
        { type: 'interval', duration: 180, target_zone: 5, description: '3 min hard' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy jog' },
      ],
    },
  },
  {
    id: '33333333-3333-3333-3333-333333333004',
    name: 'Long Run',
    type: 'run',
    difficulty_tier: 3,
    description: 'Building endurance for race day',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 300, target_zone: 1, description: 'Easy start' },
        { type: 'main', duration: 5400, target_zone: 2, description: 'Steady endurance pace' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy finish' },
      ],
    },
  },
  {
    id: '33333333-3333-3333-3333-333333333005',
    name: 'Fartlek Run',
    type: 'run',
    difficulty_tier: 3,
    description: 'Unstructured speed play',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy jog' },
        { type: 'main', duration: 1800, target_zone: 3, description: 'Fartlek: alternate hard/easy by feel' },
        { type: 'cooldown', duration: 600, target_zone: 1, description: 'Easy jog' },
      ],
    },
  },

  // BRICK WORKOUTS
  {
    id: '44444444-4444-4444-4444-444444444001',
    name: 'Bike-Run Brick',
    type: 'brick',
    difficulty_tier: 4,
    description: 'Practicing the T2 transition',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 600, target_zone: 1, description: 'Easy bike warmup' },
        { type: 'main', duration: 2700, target_zone: 3, description: 'Tempo bike' },
        { type: 'main', duration: 300, target_zone: 1, description: 'Quick transition' },
        { type: 'main', duration: 1200, target_zone: 3, description: 'Tempo run off the bike' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Easy jog' },
      ],
    },
  },

  // STRENGTH WORKOUTS
  {
    id: '55555555-5555-5555-5555-555555555001',
    name: 'Core & Stability',
    type: 'strength',
    difficulty_tier: 2,
    description: 'Building core strength for triathlon',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 300, target_zone: 1, description: 'Dynamic stretching' },
        { type: 'main', duration: 1800, target_zone: 2, description: 'Core circuit: plank, side plank, dead bug, bird dog' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Static stretching' },
      ],
    },
  },
  {
    id: '55555555-5555-5555-5555-555555555002',
    name: 'Functional Strength',
    type: 'strength',
    difficulty_tier: 3,
    description: 'Building triathlon-specific strength',
    structure_json: {
      steps: [
        { type: 'warmup', duration: 300, target_zone: 1, description: 'Dynamic warmup' },
        { type: 'main', duration: 2400, target_zone: 3, description: 'Squats, lunges, deadlifts, rows, pushups' },
        { type: 'cooldown', duration: 300, target_zone: 1, description: 'Foam rolling and stretching' },
      ],
    },
  },
];


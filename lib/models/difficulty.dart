enum Difficulty {
  couchPotato(
    label: 'Couch Potato',
    description: 'lazy, predictable',
    emoji: '😴',
    pauseMs: 1200,
    creepMs: 1400,
    dartMs: 380,
    teaseMs: 0, // no teasing
    pauseWeight: 0.40,
    creepWeight: 0.45,
    dartWeight: 0.15,
    teaseWeight: 0.0,
    speedRampMax: 1.3,
    laserRadius: 36.0,
    tapRadiusBoost: 1.30,
  ),
  officeCat(
    label: 'Office Cat',
    description: 'casual mischief',
    emoji: '🐈',
    pauseMs: 950,
    creepMs: 1100,
    dartMs: 280,
    teaseMs: 300,
    pauseWeight: 0.25,
    creepWeight: 0.42,
    dartWeight: 0.28,
    teaseWeight: 0.05,
    speedRampMax: 1.7,
    laserRadius: 30.0,
    tapRadiusBoost: 1.10,
  ),
  zoomies(
    label: '3am Zoomies',
    description: 'pure chaos',
    emoji: '🌀',
    pauseMs: 700,
    creepMs: 900,
    dartMs: 220,
    teaseMs: 260,
    pauseWeight: 0.20,
    creepWeight: 0.30,
    dartWeight: 0.30,
    teaseWeight: 0.20,
    speedRampMax: 2.2,
    laserRadius: 28.0,
    tapRadiusBoost: 1.0,
  );

  const Difficulty({
    required this.label,
    required this.description,
    required this.emoji,
    required this.pauseMs,
    required this.creepMs,
    required this.dartMs,
    required this.teaseMs,
    required this.pauseWeight,
    required this.creepWeight,
    required this.dartWeight,
    required this.teaseWeight,
    required this.speedRampMax,
    required this.laserRadius,
    required this.tapRadiusBoost,
  });

  final String label;
  final String description;
  final String emoji;
  final int pauseMs;
  final int creepMs;
  final int dartMs;
  final int teaseMs;
  final double pauseWeight;
  final double creepWeight;
  final double dartWeight;
  final double teaseWeight;
  final double speedRampMax;
  final double laserRadius;
  final double tapRadiusBoost;

  String get bestScoreKey => 'lasercat_best_$name';
}

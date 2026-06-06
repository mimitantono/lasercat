import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/new_high_score_dialog.dart';
import '../models/difficulty.dart';
import '../painters/laser_painter.dart';
import '../painters/paw_painter.dart';
import '../services/sound_service.dart';

// ── Laser movement state machine ──────────────────────────────────────────────

enum _LaserState { pause, creep, dart, tease }

class _LaserBehaviour {
  final _LaserState state;
  final Duration duration;
  final Offset? target;

  const _LaserBehaviour(this.state, this.duration, [this.target]);
}

// ── Game screen ───────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  final SoundService sounds;
  final Difficulty difficulty;
  const GameScreen({super.key, required this.sounds, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  // Paw cursor only on desktop web — mobile web synthesises hover from touch
  // which makes the paw stick to the last touch position.
  static final bool _isDesktopWeb = kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS);

  // Base hit radius; multiplied by difficulty.tapRadiusBoost
  double get _tapRadius => (_isDesktopWeb ? 68.0 : 52.0) * widget.difficulty.tapRadiusBoost;
  static const _pawSize = 68.0;

  final _rng = Random();

  // Laser position
  late AnimationController _moveCtrl;
  late Animation<Offset> _moveAnim;
  Offset _current = const Offset(200, 400);
  Offset _target  = const Offset(200, 400);
  Size _arenaSize = Size.zero;

  // Paw cursor (web only)
  Offset? _mousePos;
  late AnimationController _pawCtrl;
  late Animation<double> _pawScale;

  // Game state
  int _score = 0;
  int _combo = 0;
  int _highScore = 0;
  int _prevHighAtStart = 0; // for "new best" detection
  bool _gameOver = false;
  double _timeLeft = 30;

  Timer? _gameTimer;
  Timer? _behaviourTimer;

  // Combo flash
  String? _flashLabel;
  double _flashOpacity = 0;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _moveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _moveAnim = AlwaysStoppedAnimation(_current);
    _moveCtrl.addListener(() => setState(() => _current = _moveAnim.value));

    _pawCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _pawScale = Tween<double>(begin: 1.0, end: 0.65).animate(
      CurvedAnimation(parent: _pawCtrl, curve: Curves.easeIn),
    );

    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _highScore = prefs.getInt(widget.difficulty.bestScoreKey) ?? 0);
    }
  }

  Future<void> _saveHighScore() async {
    if (_score <= _highScore) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(widget.difficulty.bestScoreKey, _score);
    if (mounted) setState(() => _highScore = _score);
  }

  // ── Behaviour scheduling ──────────────────────────────────────────────────

  void _scheduleBehaviour() {
    if (_gameOver) return;
    final behaviour = _nextBehaviour();
    if (behaviour.target != null) {
      _animateTo(behaviour.target!, behaviour.duration);
    }
    _behaviourTimer = Timer(behaviour.duration, _scheduleBehaviour);
  }

  _LaserBehaviour _nextBehaviour() {
    final d = widget.difficulty;
    final speedMult = _speedMultiplier();
    final roll = _rng.nextDouble();

    final pauseEnd = d.pauseWeight;
    final creepEnd = pauseEnd + d.creepWeight;
    final dartEnd  = creepEnd + d.dartWeight;

    if (roll < pauseEnd) {
      return _LaserBehaviour(_LaserState.pause, Duration(milliseconds: (d.pauseMs / speedMult).round()));
    } else if (roll < creepEnd) {
      return _LaserBehaviour(
        _LaserState.creep,
        Duration(milliseconds: (d.creepMs / speedMult).round()),
        _randomPoint(maxStep: 0.25),
      );
    } else if (roll < dartEnd) {
      return _LaserBehaviour(
        _LaserState.dart,
        Duration(milliseconds: (d.dartMs / speedMult).round()),
        _randomPoint(minStep: 0.30),
      );
    } else {
      final micro = _randomPoint(maxStep: 0.12);
      _animateTo(micro, Duration(milliseconds: (120 / speedMult).round()));
      return _LaserBehaviour(
        _LaserState.tease,
        Duration(milliseconds: (d.teaseMs / speedMult).round()),
        _target,
      );
    }
  }

  double _speedMultiplier() {
    final elapsed = 30 - _timeLeft;
    return 1.0 + (elapsed / 30) * (widget.difficulty.speedRampMax - 1.0);
  }

  Offset _randomPoint({double minStep = 0, double maxStep = 1.0}) {
    if (_arenaSize == Size.zero) return _target;
    final w = _arenaSize.width;
    final h = _arenaSize.height;
    const margin = 40.0;
    Offset candidate;
    int tries = 0;
    do {
      candidate = Offset(
        margin + _rng.nextDouble() * (w - margin * 2),
        margin + _rng.nextDouble() * (h - margin * 2),
      );
      tries++;
    } while (tries < 20 && _stepRatio(candidate) < minStep && _stepRatio(candidate) > maxStep);
    return candidate;
  }

  double _stepRatio(Offset point) {
    if (_arenaSize == Size.zero) return 0;
    final d = (_current - point).distance;
    final maxD = sqrt(_arenaSize.width * _arenaSize.width + _arenaSize.height * _arenaSize.height);
    return d / maxD;
  }

  void _animateTo(Offset dest, Duration dur) {
    _target = dest;
    _moveAnim = Tween<Offset>(begin: _current, end: dest).animate(
      CurvedAnimation(parent: _moveCtrl, curve: Curves.easeInOut),
    );
    _moveCtrl.duration = dur;
    _moveCtrl.forward(from: 0);
  }

  // ── Game lifecycle ────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _score = 0;
      _combo = 0;
      _timeLeft = 30;
      _gameOver = false;
      _prevHighAtStart = _highScore;
    });

    if (_arenaSize != Size.zero) {
      _current = Offset(_arenaSize.width / 2, _arenaSize.height / 2);
      _target = _current;
    }

    _scheduleBehaviour();

    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _timeLeft = (_timeLeft - 0.1).clamp(0, 30));
      if (_timeLeft <= 0) {
        t.cancel();
        _endGame();
      }
    });
  }

  static const _nameKey = 'leaderboard_player_name';
  static const _countryKey = 'leaderboard_country_code';

  void _endGame() {
    _behaviourTimer?.cancel();
    _moveCtrl.stop();
    _saveHighScore();
    widget.sounds.playMeow();
    setState(() => _gameOver = true);
    _maybeSubmitToLeaderboard();
  }

  Future<void> _maybeSubmitToLeaderboard() async {
    final score = _score;
    final difficulty = widget.difficulty.name;
    bool qualifies = false;
    try {
      qualifies = await LeaderboardService.qualifies(
        gameId: 'lasercat',
        difficulty: difficulty,
        score: score,
      );
    } catch (_) {}
    if (!mounted || !qualifies) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await showNewHighScoreDialog(
      context,
      gameId: 'lasercat',
      difficulty: difficulty,
      score: score,
      rememberedName: prefs.getString(_nameKey),
      rememberedCountryCode: prefs.getString(_countryKey),
      onNameRemembered: (n) => prefs.setString(_nameKey, n),
      onCountryRemembered: (c) => prefs.setString(_countryKey, c),
    );
  }

  // ── Tap / mouse handling ──────────────────────────────────────────────────

  void _onTapDown(TapDownDetails _) {
    if (_isDesktopWeb) _pawCtrl.forward(from: 0);
  }

  void _onTapUp(TapUpDetails details) {
    if (_isDesktopWeb) _pawCtrl.reverse();
    if (_gameOver) return;

    final pos = details.localPosition;
    final dist = (pos - _current).distance;

    if (dist <= _tapRadius) {
      _combo++;
      final points = _comboPoints();
      setState(() => _score += points);
      if (_combo == 5 || _combo == 10) {
        widget.sounds.playCombo();
      } else {
        widget.sounds.playHit();
      }
      _showFlash(points);
    } else {
      _combo = 0;
    }
  }

  void _onTapCancel() {
    if (_isDesktopWeb) _pawCtrl.reverse();
  }

  int _comboPoints() {
    if (_combo >= 10) return 5;
    if (_combo >= 5) return 3;
    if (_combo >= 3) return 2;
    return 1;
  }

  void _showFlash(int points) {
    final label = _combo >= 5 ? '+$points 🔥' : '+$points';
    _flashTimer?.cancel();
    setState(() {
      _flashLabel = label;
      _flashOpacity = 1.0;
    });
    _flashTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flashOpacity = 0);
    });
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    _pawCtrl.dispose();
    _gameTimer?.cancel();
    _behaviourTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              score: _score,
              highScore: _highScore,
              timeLeft: _timeLeft,
              started: !_gameOver,
              difficultyLabel: widget.difficulty.label,
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                _arenaSize = Size(constraints.maxWidth, constraints.maxHeight);

                Widget arena = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
                          ),
                        ),
                      ),
                      if (!_gameOver)
                        CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: LaserPainter(
                            position: _current,
                            glowRadius: widget.difficulty.laserRadius,
                          ),
                        ),
                      if (_flashLabel != null)
                        Positioned(
                          left: _current.dx - 40,
                          top: _current.dy - 60,
                          child: AnimatedOpacity(
                            opacity: _flashOpacity,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _flashLabel!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.red, blurRadius: 8)],
                              ),
                            ),
                          ),
                        ),
                      // Desktop-web paw cursor
                      if (_isDesktopWeb && _mousePos != null && !_gameOver)
                        Positioned(
                          left: _mousePos!.dx - _pawSize / 2,
                          top: _mousePos!.dy - _pawSize / 2,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _pawScale,
                              builder: (_, child) => Transform.scale(
                                scale: _pawScale.value,
                                child: CustomPaint(
                                  size: const Size(_pawSize, _pawSize),
                                  painter: PawPainter(opacity: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_gameOver)
                        _GameOverOverlay(
                          score: _score,
                          highScore: _highScore,
                          isNewHigh: _score > 0 && _score > _prevHighAtStart,
                          onPlayAgain: _startGame,
                          onMenu: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                );

                // On desktop web: wrap in MouseRegion to track position and hide system cursor
                if (_isDesktopWeb) {
                  arena = MouseRegion(
                    cursor: SystemMouseCursors.none,
                    onHover: (e) => setState(() => _mousePos = e.localPosition),
                    onExit: (_) => setState(() => _mousePos = null),
                    child: arena,
                  );
                }

                return arena;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int score;
  final int highScore;
  final double timeLeft;
  final bool started;
  final String difficultyLabel;

  const _TopBar({
    required this.score,
    required this.highScore,
    required this.timeLeft,
    required this.started,
    required this.difficultyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final urgentColor = timeLeft < 8 ? Colors.red : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(difficultyLabel.toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
          if (started)
            Column(children: [
              Text(
                timeLeft.toStringAsFixed(1),
                style: TextStyle(
                  color: urgentColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  shadows: timeLeft < 8 ? [const Shadow(color: Colors.red, blurRadius: 12)] : null,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 120 * (timeLeft / 30),
                height: 3,
                decoration: BoxDecoration(
                  color: urgentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('BEST', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
            Text('$highScore', style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}

// ── Game over overlay ─────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  final int score;
  final int highScore;
  final bool isNewHigh;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.score,
    required this.highScore,
    required this.isNewHigh,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.80),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🐱', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          const Text(
            'Time\'s up!',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Text('$score pts', style: const TextStyle(color: Colors.amber, fontSize: 52, fontWeight: FontWeight.bold)),
          if (isNewHigh)
            const Text('New best! 🔥', style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Best: $highScore', style: const TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF1744),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onPlayAgain,
              child: const Text('PLAY AGAIN',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onMenu,
            child: const Text('Menu', style: TextStyle(color: Colors.white38, fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

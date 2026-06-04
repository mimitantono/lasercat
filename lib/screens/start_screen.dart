import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import '../services/sound_service.dart';
import 'game_screen.dart';

const _loadingMessages = [
  'Warming up laser...',
  'Waking up cat...',
  'Calibrating existential dread...',
  'Loading whiskers...',
  'Consulting feline behavioural scientists...',
  'Charging laser batteries...',
  'Initialising paw coordination...',
  'Negotiating with the dot...',
];

const _descriptions = [
  'A groundbreaking empathy simulator.\nExperience life as a cat: chase a laser dot that can never be caught.',
  'The dot cannot be caught.\nThe dot was never meant to be caught.\nAnd yet, here you are.',
  'Clinically proven to increase human frustration by 400%.\nAlso — you\'re the cat now.',
  'Winner of zero awards.\nBeloved by zero cats (they can\'t use phones).\nA triumph of the human spirit.',
  'Finally understand your cat\'s daily existential crisis.\nSpoiler: it\'s this.',
  'Rated 5★ by cats who can\'t type.\nA revolutionary study in futility and reflexes.',
  'Ever wondered why your cat is willing to sprint across the house at 3 a.m. for a tiny red dot?',
  'Experience life as a cat: dedicate your entire existence to the pursuit of an unattainable laser dot.',
  'For years, your cat has chased the laser dot.\nNow it\'s your turn.',
  'Become the cat. Chase the dot. Question your life choices. Chase the dot again.',
  'They say you should put yourself in someone else\'s shoes.\nThis game puts you in your cat\'s paws.',
];

class StartScreen extends StatefulWidget {
  final SoundService sounds;
  const StartScreen({super.key, required this.sounds});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  bool _loadingDone = false;
  int _loadingIndex = 0;
  late String _description;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _msgTimer;
  Difficulty _difficulty = Difficulty.officeCat;
  final Map<Difficulty, int> _bestScores = {
    for (final d in Difficulty.values) d: 0,
  };

  @override
  void initState() {
    super.initState();
    _description = _descriptions[Random().nextInt(_descriptions.length)];
    _loadBestScores();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Cycle loading messages every 400ms, finish after ~2s
    _msgTimer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      setState(() => _loadingIndex = (_loadingIndex + 1) % _loadingMessages.length);
    });

    Timer(const Duration(milliseconds: 2000), () {
      _msgTimer?.cancel();
      setState(() => _loadingDone = true);
      _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final d in Difficulty.values) {
        _bestScores[d] = prefs.getInt(d.bestScoreKey) ?? 0;
      }
    });
  }

  void _play() {
    widget.sounds.warmUp();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(sounds: widget.sounds, difficulty: _difficulty),
      ),
    ).then((_) => _loadBestScores());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _loadingDone ? _buildTitle() : _buildLoading(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      key: const ValueKey('loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Color(0xFFFF1744),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _loadingMessages[_loadingIndex],
            key: ValueKey(_loadingIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        key: const ValueKey('title'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐱', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text(
            'LASER CAT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.7,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _description = _descriptions[Random().nextInt(_descriptions.length)];
              });
            },
            child: const Text(
              'another one ↻',
              style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 32),
          _DifficultyPicker(
            selected: _difficulty,
            bestScores: _bestScores,
            onSelect: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _play,
                  child: const Text(
                    'PLAY',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => widget.sounds.toggleMute()),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Icon(
                    widget.sounds.muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white54,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap the dot  •  Combos score more  •  30 seconds',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  final Difficulty selected;
  final Map<Difficulty, int> bestScores;
  final ValueChanged<Difficulty> onSelect;

  const _DifficultyPicker({
    required this.selected,
    required this.bestScores,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: Difficulty.values.map((d) {
            final isSelected = d == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2A0A12) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFF1744) : const Color(0xFF333333),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        d.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFFF6B8B) : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'best ${bestScores[d] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          selected.description,
          style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

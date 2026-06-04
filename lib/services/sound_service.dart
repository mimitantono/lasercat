import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const _muteKey = 'lasercat_muted';

  final _hitPool    = [AudioPlayer(), AudioPlayer()];
  final _comboPool  = [AudioPlayer(), AudioPlayer()];
  final _meowPool   = [AudioPlayer(), AudioPlayer()];
  int _hi = 0, _ci = 0, _mi = 0;

  bool _muted = false;
  bool get muted => _muted;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_muteKey) ?? false;
    for (final p in [..._hitPool, ..._comboPool, ..._meowPool]) {
      p.setReleaseMode(ReleaseMode.stop);
    }
    try {
      await Future.wait([
        ..._hitPool.map((p)   => p.setSource(AssetSource('sounds/hit.ogg'))),
        ..._comboPool.map((p) => p.setSource(AssetSource('sounds/combo.ogg'))),
        ..._meowPool.map((p)  => p.setSource(AssetSource('sounds/meow.ogg'))),
      ]);
      debugPrint('[SoundService] init: all sources loaded');
    } catch (e, st) {
      debugPrint('[SoundService] init FAILED: $e\n$st');
    }
  }

  Future<void> warmUp() async {
    if (_muted) return;
    debugPrint('[SoundService] warmUp start');
    try {
      for (final p in [..._hitPool, ..._comboPool, ..._meowPool]) {
        await p.setVolume(0);
        await p.resume();
        await p.stop();
        await p.setVolume(1);
      }
      debugPrint('[SoundService] warmUp done');
    } catch (e, st) {
      debugPrint('[SoundService] warmUp FAILED: $e\n$st');
    }
  }

  void toggleMute() {
    _muted = !_muted;
    SharedPreferences.getInstance().then((p) => p.setBool(_muteKey, _muted));
  }

  void playHit() {
    if (_muted) return;
    _hi = (_hi + 1) % _hitPool.length;
    _hitPool[_hi].play(AssetSource('sounds/hit.ogg')).then(
      (_) => debugPrint('[SoundService] playHit ok'),
      onError: (e) => debugPrint('[SoundService] playHit FAILED: $e'),
    );
  }

  void playCombo() {
    if (_muted) return;
    _ci = (_ci + 1) % _comboPool.length;
    _comboPool[_ci].play(AssetSource('sounds/combo.ogg')).then(
      (_) => debugPrint('[SoundService] playCombo ok'),
      onError: (e) => debugPrint('[SoundService] playCombo FAILED: $e'),
    );
  }

  void playMeow() {
    if (_muted) return;
    _mi = (_mi + 1) % _meowPool.length;
    _meowPool[_mi].play(AssetSource('sounds/meow.ogg')).then(
      (_) => debugPrint('[SoundService] playMeow ok'),
      onError: (e) => debugPrint('[SoundService] playMeow FAILED: $e'),
    );
  }

  void dispose() {
    for (final p in [..._hitPool, ..._comboPool, ..._meowPool]) {
      p.dispose();
    }
  }
}

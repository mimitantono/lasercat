import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/start_screen.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const LaserCatApp());
}

class LaserCatApp extends StatefulWidget {
  const LaserCatApp({super.key});

  @override
  State<LaserCatApp> createState() => _LaserCatAppState();
}

class _LaserCatAppState extends State<LaserCatApp> {
  final _sounds = SoundService();

  @override
  void initState() {
    super.initState();
    _sounds.init();
  }

  @override
  void dispose() {
    _sounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laser Cat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF1744),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: StartScreen(sounds: _sounds),
    );
  }
}

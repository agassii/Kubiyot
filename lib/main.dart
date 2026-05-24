import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/game_provider.dart';
import 'services/hive_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final hiveService = HiveService();
  await hiveService.init();

  runApp(
    ProviderScope(
      overrides: [
        gameProvider.overrideWith(
          (ref) => GameNotifier(hiveService: hiveService),
        ),
      ],
      child: const KubiyotApp(),
    ),
  );
}

class KubiyotApp extends StatelessWidget {
  const KubiyotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'קוביות',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_strings.dart';
import 'providers/game_provider.dart';
import 'providers/language_provider.dart';
import 'services/hive_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Strip any path suffix — supabase_flutter needs just scheme://host
  final rawUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final parsedUri = Uri.parse(rawUrl);
  final supabaseUrl = parsedUri.hasScheme
      ? '${parsedUri.scheme}://${parsedUri.host}'
      : rawUrl;
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  await Hive.initFlutter();
  await Hive.openBox('settings');
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

class KubiyotApp extends ConsumerWidget {
  const KubiyotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp(
      title: 'קוביות',
      debugShowCheckedModeBanner: false,
      locale: lang == AppLanguage.he ? const Locale('he') : const Locale('en'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('he')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config.dart';
// import 'screens/friday_initialization_screen.dart'; // Unused
import 'screens/friday_home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file: $e");
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Remove or set to false in production
  );

  // Determine Initial Screen
  final bool isLoggedIn = AuthService().isLoggedIn;

  runApp(
    FridayApp(
      initialScreen: isLoggedIn ? const FridayHomeScreen() : const AuthScreen(),
    ),
  );
}

class FridayApp extends StatelessWidget {
  final Widget initialScreen;

  const FridayApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friday',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: initialScreen,
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 1. Initialize Supabase & Brain
    // Note: Background tasks need their own Supabase init if accessed
    // 2. Perform a "Silent Check"
    // 3. If a conflict is found, trigger a Local Notification
    print("FRIDAY is performing a background systems check...");
    return Future.value(true);
  });
}

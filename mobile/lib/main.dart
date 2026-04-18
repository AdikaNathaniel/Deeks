import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/auth_service.dart';
import 'notifications/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const DeeksApp());
}

class DeeksApp extends StatelessWidget {
  const DeeksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService()..bootstrap(),
      child: MaterialApp(
        title: 'Deeks',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Consumer<AuthService>(
          builder: (context, auth, _) =>
              auth.isAuthenticated ? const HomeScreen() : const AuthScreen(),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();
  runApp(const OmNatalieApp());
}

class OmNatalieApp extends StatelessWidget {
  const OmNatalieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OM Natalie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      builder: kIsWeb
          ? (ctx, child) {
              final screenW = MediaQuery.sizeOf(ctx).width;
              if (screenW <= 520) return child!;
              // desktop browser: center app in phone-sized frame
              return Container(
                color: const Color(0xFF1A0010),
                child: Center(
                  child: SizedBox(
                    width: 480,
                    child: MediaQuery(
                      data: MediaQuery.of(ctx).copyWith(
                        size: Size(480, MediaQuery.sizeOf(ctx).height),
                      ),
                      child: ClipRect(child: child!),
                    ),
                  ),
                ),
              );
            }
          : null,
      home: const AuthScreen(),
    );
  }
}

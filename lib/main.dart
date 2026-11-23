
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/vault_service.dart';
import 'screens/vault_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    CodeVantaVaultApp(
      initialDarkMode: prefs.getBool('is_dark_mode') ?? true,
    ),
  );
}

class CodeVantaVaultApp extends StatefulWidget {
  const CodeVantaVaultApp({
    super.key,
    required this.initialDarkMode,
  });

  final bool initialDarkMode;

  @override
  State<CodeVantaVaultApp> createState() =>
      CodeVantaVaultAppState();

  static CodeVantaVaultAppState of(BuildContext context) {
    return context.findAncestorStateOfType<CodeVantaVaultAppState>()!;
  }
}

class CodeVantaVaultAppState extends State<CodeVantaVaultApp> {
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.initialDarkMode;
  }

  Future<void> toggleTheme() async {
    setState(() {
      isDarkMode = !isDarkMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF071326);
    const blue = Color(0xFF168BFF);

    return MaterialApp(
      title: 'CodeVanta Vault',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: navy,
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: VaultService.instance.isConfigured(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return VaultGate(
            isFirstSetup: snapshot.data != true,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/vault_service.dart';
import 'screens/vault_gate.dart';
import 'screens/vault_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  runApp(CodeVantaVaultApp(initialDarkMode: isDark));
}

class CodeVantaVaultApp extends StatefulWidget {
  const CodeVantaVaultApp({super.key, required this.initialDarkMode});

  final bool initialDarkMode;

  @override
  State<CodeVantaVaultApp> createState() => _CodeVantaVaultAppState();

  static _CodeVantaVaultAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_CodeVantaVaultAppState>()!;
}

class _CodeVantaVaultAppState extends State<CodeVantaVaultApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  Future<void> toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF071326);
    const blue = Color(0xFF168BFF);
    return MaterialApp(
      title: 'CodeVanta Vault',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF4F7FB), foregroundColor: navy),
        cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: navy,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
        cardTheme: CardThemeData(elevation: 0, color: const Color(0xFF101F35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      home: FutureBuilder<bool>(
        future: VaultService.instance.isConfigured(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == true ? const VaultGate() : const VaultGate(isFirstSetup: true);
        },
      ),
    );
  }
}

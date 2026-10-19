import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'screens.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final store = AppStore();
  await store.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(DomashkaApp(store: store));
}

class DomashkaApp extends StatelessWidget {
  const DomashkaApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Домашка', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xfff5f8fe),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff246af3),
        brightness: Brightness.light, surface: Colors.white),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff5f8fe),
        elevation: 0, centerTitle: false, scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: Color(0xff142b50), fontSize: 21,
          fontWeight: FontWeight.w800)),
      cardTheme: CardThemeData(color: Colors.white, surfaceTintColor: Colors.white,
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: const Color(0xff246af3), foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    ),
    home: SplashScreen(store: store),
  );
}
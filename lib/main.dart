import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'glass_nav_bar.dart';
import 'home_page.dart';

void main() => runApp(const Dz6gApp());

class Dz6gApp extends StatelessWidget {
  const Dz6gApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园墙',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFC9A96E),
          secondary: Color(0xFFF5F5F5),
          surface: Color(0xFFFFFFFF),
        ),
        useMaterial3: true,
      ),
      home: const CampusWallPage(),
    );
  }
}

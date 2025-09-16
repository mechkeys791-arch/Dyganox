import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'homepage.dart';

void main() {
  runApp(const ServiceProviderApp());
}

class ServiceProviderApp extends StatelessWidget {
  const ServiceProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Service Provider App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF), // White background as per XML
      ),
      home: const HomePage(),
    );
  }
}

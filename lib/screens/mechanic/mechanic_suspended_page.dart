import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mechanic_help_chat_page.dart';

/// Shown when admin has suspended the mechanic. Access revoked; can only contact help center.
class MechanicSuspendedPage extends StatelessWidget {
  final String? mechanicEmail;

  const MechanicSuspendedPage({
    super.key,
    this.mechanicEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    size: 56,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'You have been suspended',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your access has been revoked. Please contact the help center.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (mechanicEmail != null && mechanicEmail!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MechanicHelpChatPage(mechanicEmail: mechanicEmail!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 22),
                      label: const Text('Chat with Help Center'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

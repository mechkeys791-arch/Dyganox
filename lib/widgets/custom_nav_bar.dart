import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../homepage.dart';
import '../screens/profile/profile_page.dart';
import '../emergency_assistance_page.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex; // 0: Home, 1: Emergency, 2: Profile
  
  const CustomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15.0,
            spreadRadius: 2.0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home Navigation Item
            _buildNavItem(
              context,
              Icons.home_filled,
              'Home',
              currentIndex == 0,
              0,
            ),
            // Emergency FAB - Center
            _buildFABNavItem(
              context,
              Icons.report_problem_rounded,
              'Emergency',
              currentIndex == 1,
              1,
            ),
            // Profile Navigation Item
            _buildNavItem(
              context,
              Icons.account_circle,
              'Profile',
              currentIndex == 2,
              2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, int index) {
    // Navigation item using theme color #706DC7 for all states
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        
        // Navigate to the appropriate page
        if (index == 0 && currentIndex != 0) {
          // Navigate to Home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else if (index == 2 && currentIndex != 2) {
          // Navigate to Profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        }
        // If already on the page, do nothing
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            // Selected: Full theme color #706DC7
            // Inactive: Lighter shade of theme color for consistency
            color: isSelected 
                ? const Color(0xFF706DC7) 
                : const Color(0xFF706DC7).withOpacity(0.35),
            size: 28,
          ),
          const SizedBox(height: 6),
          // Indicator dot uses theme color
          if (isSelected)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF706DC7), // Theme color dot
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFABNavItem(BuildContext context, IconData icon, String label, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        
        // Navigate to Emergency page if not already there
        if (currentIndex != 1) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const EmergencyAssistancePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
            ),
          );
        }
      },
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}


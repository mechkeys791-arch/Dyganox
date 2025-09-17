import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 926),
              decoration: const BoxDecoration(color: Color(0xFFF4F8FE)),
              child: Stack(
                children: [
                  // Header with back button and profile title
                  Positioned(
                    left: 16,
                    top: 46,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF202244),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Color(0xFF202244),
                            fontSize: 21,
                            fontFamily: 'Jost',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Profile picture with edit button
                  Positioned(
                    left: 159,
                    top: 116,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: const ShapeDecoration(
                            color: Color(0xFFD7D7D7),
                            shape: OvalBorder(
                              side: BorderSide(
                                width: 4,
                                strokeAlign: BorderSide.strokeAlignOutside,
                                color: Color(0xFF167F71),
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 10,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                  width: 3,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                  color: Color(0xFF167F71),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Color(0xFF167F71),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // User name
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 240,
                    child: Text(
                      'James S. Hernandez',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF202244),
                        fontSize: 24,
                        fontFamily: 'Jost',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  // User email
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 279,
                    child: Text(
                      'hernandex.redial@gmail.ac.in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF545454),
                        fontSize: 13,
                        fontFamily: 'Mulish',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  
                  // Profile menu items
                  ...buildProfileMenuItems(),
                  
                  // Bottom navigation
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: 100,
                      decoration: const BoxDecoration(color: Color(0xFFF4F8FE)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBottomNavItem('HOME', false),
                          _buildBottomNavItem('MY COURSES', false),
                          _buildBottomNavItem('INBOX', false),
                          _buildBottomNavItem('TRANSACTION', false),
                          _buildBottomNavItem('PROFILE', true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildProfileMenuItems() {
    final menuItems = [
      {'title': 'Edit Profile', 'top': 321.0, 'icon': Icons.edit},
      {'title': 'Payment Option', 'top': 377.0, 'icon': Icons.payment},
      {'title': 'Notifications', 'top': 433.0, 'icon': Icons.notifications},
      {'title': 'Security', 'top': 489.0, 'icon': Icons.security},
      {'title': 'Permissions', 'top': 546.0, 'icon': Icons.admin_panel_settings},
      {'title': 'Transaction Details', 'top': 602.0, 'icon': Icons.receipt_long},
      {'title': 'Terms & Conditions', 'top': 658.0, 'icon': Icons.description},
      {'title': 'Help Center', 'top': 713.0, 'icon': Icons.help_center},
      {'title': 'Invite Friends', 'top': 772.0, 'icon': Icons.people},
      {'title': 'Logout', 'top': 828.0, 'icon': Icons.logout},
    ];

    return menuItems.map((item) {
      return Positioned(
        left: 35,
        right: 35,
        top: item['top'] as double,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                color: const Color(0xFF167F71),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item['title'] as String,
                  style: const TextStyle(
                    color: Color(0xFF202244),
                    fontSize: 15,
                    fontFamily: 'Mulish',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF545454),
                size: 16,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildBottomNavItem(String title, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _getIconForNavItem(title),
          color: isActive ? const Color(0xFF167F71) : const Color(0xFF202244),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? const Color(0xFF167F71) : const Color(0xFF202244),
            fontSize: 9,
            fontFamily: 'Mulish',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.40,
          ),
        ),
      ],
    );
  }

  IconData _getIconForNavItem(String title) {
    switch (title) {
      case 'HOME':
        return Icons.home;
      case 'MY COURSES':
        return Icons.book;
      case 'INBOX':
        return Icons.inbox;
      case 'TRANSACTION':
        return Icons.receipt;
      case 'PROFILE':
        return Icons.person;
      default:
        return Icons.circle;
    }
  }
}

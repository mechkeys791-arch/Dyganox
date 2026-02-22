import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'user_help_chat_page.dart';

/// Landing: Create a case — Know about ProMech, Have a query, Have a question, Talk to customer support.
/// Shows recent solved conversations. On "Talk to customer support": Message -> request-help then open chat.
class UserSupportLandingPage extends StatefulWidget {
  final String userEmail;

  const UserSupportLandingPage({super.key, required this.userEmail});

  @override
  State<UserSupportLandingPage> createState() => _UserSupportLandingPageState();
}

class _UserSupportLandingPageState extends State<UserSupportLandingPage> {
  List<Map<String, dynamic>> _recentSolved = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSolved();
  }

  Future<void> _loadRecentSolved() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/person/support?email=${Uri.encodeComponent(widget.userEmail)}'));
      if (!mounted) return;
      if (r.statusCode != 200) { setState(() => _loadingRecent = false); return; }
      final body = jsonDecode(r.body);
      final list = body is List<dynamic> ? body : <dynamic>[];
      final msgs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final List<Map<String, dynamic>> closed = [];
      for (int i = 0; i < msgs.length; i++) {
        if ((msgs[i]['messageType'] ?? '').toString() == 'CONVERSATION_ENDED') {
          final createdAt = msgs[i]['createdAt']?.toString() ?? '';
          closed.add({'closedAt': createdAt, 'index': i});
        }
      }
      closed.sort((a, b) => (b['closedAt'] as String).compareTo(a['closedAt'] as String));
      setState(() {
        _recentSolved = closed;
        _loadingRecent = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Create a case',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'How can we help you today?',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade700),
              ),
              if (_recentSolved.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Recent solved',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                ..._recentSolved.take(5).map((e) {
                  final at = e['closedAt']?.toString() ?? '';
                  String dateStr = at;
                  try {
                    if (at.length >= 10) dateStr = DateTime.parse(at.substring(0, 10)).toString().substring(0, 10);
                  } catch (_) {}
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => UserHelpChatPage(userEmail: widget.userEmail),
                            ),
                          ).then((_) => _loadRecentSolved());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Color(0xFF16a34a), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Solved conversation',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.info_outline_rounded,
                title: 'Know about ProMech',
                subtitle: 'Learn about our services',
                onTap: () => _showSnack(context, 'Visit our app homepage for more about ProMech.'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.search_rounded,
                title: 'Have a query',
                subtitle: 'Find answers to common questions',
                onTap: () => _showSnack(context, 'You can browse FAQs in the app or ask in chat.'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.help_outline_rounded,
                title: 'Have a question',
                subtitle: 'Get quick answers',
                onTap: () => _showSnack(context, 'Tap "Talk to customer support" to ask via chat.'),
              ),
              const SizedBox(height: 12),
              _OptionTile(
                icon: Icons.support_agent_rounded,
                title: 'Talk to customer support',
                subtitle: 'Chat or request a call',
                onTap: () => _showTalkToSupportOptions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Color(0xFF334155)));
  }

  void _showTalkToSupportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 24, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request call – normally in 2 minutes',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'We’ll call you back shortly.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showSnack(context, 'Call request noted. We’ll call you within 2 minutes.');
              },
              icon: const Icon(Icons.phone_outlined, size: 20),
              label: const Text('Request call'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF334155),
                side: BorderSide(color: Color(0xFF334155)),
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Message – an agent will join within 1 minute',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'A notification is sent to the support dashboard. Wait until an admin joins.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _requestHelpAndOpenChat(context);
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text('Start chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestHelpAndOpenChat(BuildContext context) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/support/request-help'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail}),
      );
      if (!context.mounted) return;
      if (r.statusCode == 201 || r.statusCode == 200) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserHelpChatPage(userEmail: widget.userEmail),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start support. Try again.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Color(0xFF475569), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

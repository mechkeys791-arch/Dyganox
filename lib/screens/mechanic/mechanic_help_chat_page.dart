import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';

/// Help chat for mechanics. Messages by date, "Customer care is typing", real-time polling. No photo.
class MechanicHelpChatPage extends StatefulWidget {
  final String mechanicEmail;

  const MechanicHelpChatPage({super.key, required this.mechanicEmail});

  @override
  State<MechanicHelpChatPage> createState() => _MechanicHelpChatPageState();
}

class _MechanicHelpChatPageState extends State<MechanicHelpChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _adminTyping = false;
  Timer? _pollTimer;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        _loadMessages();
        _fetchAdminTyping();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_loading && _messages.isNotEmpty) return;
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/mechanic/help?email=${Uri.encodeComponent(widget.mechanicEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        setState(() {
          _messages = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAdminTyping() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/mechanic/help/typing?email=${Uri.encodeComponent(widget.mechanicEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() => _adminTyping = d['adminTyping'] == true);
      }
    } catch (_) {}
  }

  void _setMechanicTyping(bool typing) {
    _typingTimer?.cancel();
    http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/mechanic/help/typing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': widget.mechanicEmail, 'isTyping': typing}),
    ).ignore();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 2), () => _setMechanicTyping(false));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final m in _messages) {
      String key;
      try {
        key = DateTime.parse(m['createdAt'].toString()).toLocal().toIso8601String().split('T')[0];
      } catch (_) {
        key = DateTime.now().toIso8601String().split('T')[0];
      }
      groups.putIfAbsent(key, () => []).add(m);
    }
    return groups;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _setMechanicTyping(false);
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/mechanic/help'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.mechanicEmail, 'message': text}),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _sending = false);
      if (r.statusCode == 201 || r.statusCode == 200) {
        await _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${d.month >= 1 && d.month <= 12 ? months[d.month - 1] : ''} ${d.year}';
    } catch (_) { return isoDate; }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    final sortedDates = groups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Help Chat', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          if (_adminTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Text('Customer care is typing...',
                  style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.amber.shade900)),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: sortedDates.fold<int>(0, (sum, d) => sum + (groups[d]!.length) + 1),
                    itemBuilder: (context, idx) {
                      int i = 0;
                      for (final date in sortedDates) {
                        if (i == idx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                _formatDate(date),
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          );
                        }
                        i++;
                        for (final m in groups[date]!) {
                          if (i == idx) {
                            final isMechanic = (m['sender'] ?? '').toString().toUpperCase() == 'MECHANIC';
                            final time = _formatTime((m['createdAt'] ?? '').toString());
                            return Align(
                              alignment: isMechanic ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                decoration: BoxDecoration(
                                  color: isMechanic ? const Color(0xFF6366F1) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['message'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: isMechanic ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          time,
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: isMechanic ? Colors.white70 : Colors.grey),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                          i++;
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (_) => _setMechanicTyping(true),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}





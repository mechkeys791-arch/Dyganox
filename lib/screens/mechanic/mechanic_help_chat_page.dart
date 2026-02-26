import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mechanic_help_faq.dart';

/// Help chat for mechanics - local FAQ bot. No backend. Responds to questions with ProMech FAQs.
class MechanicHelpChatPage extends StatefulWidget {
  final String mechanicEmail;

  const MechanicHelpChatPage({super.key, required this.mechanicEmail});

  @override
  State<MechanicHelpChatPage> createState() => _MechanicHelpChatPageState();
}

class _MechanicHelpChatPageState extends State<MechanicHelpChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Hello! I\'m the ProMech Help bot. Ask me anything about the app: bookings, profile, services, payments, notifications, and more. Try "How do I receive booking requests?" or tap a suggestion below.',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add({
        'sender': 'BOT',
        'message': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({
        'sender': 'MECHANIC',
        'message': text,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    _addUserMessage(text);

    // Simulate slight delay
    await Future.delayed(const Duration(milliseconds: 400));

    final answer = MechanicHelpFaq.getAnswer(text);
    if (mounted) {
      if (answer != null) {
        _addBotMessage(answer);
      } else {
        _addBotMessage(
          'I couldn\'t find an exact answer for that. Try one of these: "How do I receive booking requests?", "How do I add services?", "Why am I not getting notifications?" Or type "Help" for suggestions.',
        );
      }
      setState(() => _sending = false);
    }
  }

  void _onSuggestionTap(String question) {
    _messageController.text = question;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Help', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF111111), Color(0xFFFBBF24)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick questions',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: MechanicHelpFaq.suggestedQuestions.map((q) {
                            return GestureDetector(
                              onTap: () => _onSuggestionTap(q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                                ),
                                child: Text(
                                  q,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }
                final m = _messages[index - 1];
                final isMechanic = (m['sender'] ?? '').toString().toUpperCase() == 'MECHANIC';
                final time = _formatTime((m['createdAt'] ?? '').toString());
                return Align(
                  alignment: isMechanic ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: isMechanic ? const Color(0xFFFBBF24) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMechanic)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'ProMech Bot',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                            ),
                          ),
                        Text(
                          m['message'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: isMechanic ? const Color(0xFF111111) : const Color(0xFF1E293B),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              time,
                              style: GoogleFonts.inter(fontSize: 11, color: isMechanic ? Colors.black54 : Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)),
                          )
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: const Color(0xFF111111),
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

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/api_config.dart';

/// Customer support chat. Messages by date, typing indicator, photo permission flow, real-time polling.
class UserHelpChatPage extends StatefulWidget {
  final String userEmail;

  const UserHelpChatPage({super.key, required this.userEmail});

  @override
  State<UserHelpChatPage> createState() => _UserHelpChatPageState();
}

class _UserHelpChatPageState extends State<UserHelpChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _photoAllowed = false;
  bool _adminTyping = false;
  bool _requestedPhotoPermission = false;
  bool _waitingForAdmin = false;
  bool _adminHasJoined = false;
  bool _conversationClosed = false;
  Timer? _pollTimer;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkPhotoPermission();
    _fetchHelpStatus();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        _loadMessages();
        _fetchAdminTyping();
        _fetchHelpStatus();
      }
    });
  }

  Future<void> _fetchHelpStatus() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/person/support/help-status?email=${Uri.encodeComponent(widget.userEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() => _waitingForAdmin = d['waitingForAdmin'] == true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPhotoPermission() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/person/support/photo-permission?email=${Uri.encodeComponent(widget.userEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() => _photoAllowed = d['allowed'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (_loading && _messages.isNotEmpty) return;
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/person/support?email=${Uri.encodeComponent(widget.userEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final list = body is List<dynamic> ? body : <dynamic>[];
        final msgs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final lastType = msgs.isNotEmpty ? (msgs.last['messageType'] ?? '').toString() : '';
        final closed = lastType == 'CONVERSATION_ENDED';
        final adminJoined = msgs.any((m) => (m['messageType'] ?? '').toString() == 'ADMIN_JOINED');
        setState(() {
          _messages = msgs;
          _loading = false;
          _conversationClosed = closed;
          _adminHasJoined = adminJoined;
        });
        _scrollToBottom();
        _checkIfRequestedPhotoPermission();
        _checkPhotoPermission();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _checkIfRequestedPhotoPermission() {
    final requested = _messages.any((m) =>
        (m['messageType'] ?? '').toString().toUpperCase().contains('PHOTO_PERMISSION_REQUEST'));
    if (requested && !_requestedPhotoPermission) setState(() => _requestedPhotoPermission = true);
  }

  Future<void> _fetchAdminTyping() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/person/support/typing?email=${Uri.encodeComponent(widget.userEmail)}'));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() => _adminTyping = d['adminTyping'] == true);
      }
    } catch (_) {}
  }

  void _setUserTyping(bool typing) {
    _typingTimer?.cancel();
    http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/person/support/typing'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': widget.userEmail, 'isTyping': typing}),
    ).ignore();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 2), () => _setUserTyping(false));
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

  Future<void> _requestPhotoPermission() async {
    if (_requestedPhotoPermission) return;
    setState(() => _sending = true);
    try {
      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/support/request-photo-permission'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail}),
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _requestedPhotoPermission = r.statusCode == 201 || r.statusCode == 200;
      });
      if (_requestedPhotoPermission) await _loadMessages();
    } catch (e) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto(File file) async {
    if (!_photoAllowed || _sending) return;
    setState(() => _sending = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/upload/support-photo'),
      );
      request.fields['email'] = widget.userEmail;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send();
      final r = await http.Response.fromStream(streamed);
      if (!mounted) return;
      if (r.statusCode != 200) {
        setState(() => _sending = false);
        String errMsg = 'Photo upload failed';
        try {
          final errBody = jsonDecode(r.body) as Map<String, dynamic>;
          final err = errBody['error']?.toString();
          if (err != null && err.isNotEmpty) errMsg = err;
        } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
        return;
      }
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final url = d['url']?.toString() ?? '';
      if (url.isEmpty) {
        setState(() => _sending = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo upload failed: no URL returned'), backgroundColor: Colors.red));
        return;
      }
      final msgRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/support'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail, 'message': '[Photo]', 'imageUrl': url, 'messageType': 'IMAGE'}),
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (msgRes.statusCode == 201 || msgRes.statusCode == 200) await _loadMessages();
    } catch (e) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _setUserTyping(false);
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/support'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail, 'message': text}),
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (r.statusCode == 201 || r.statusCode == 200) {
        await _loadMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send'), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate();
    final sortedDates = groups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Customer Support', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          if (_waitingForAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFECFDF5),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: Color(0xFF059669)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Admin will join shortly. You will be connected within 1 minute.',
                      style: GoogleFonts.inter(fontSize: 13, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            ),
          if (_adminHasJoined && !_waitingForAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF0FDF4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF16a34a)),
                  const SizedBox(width: 8),
                  Text('Admin has joined.', style: GoogleFonts.inter(fontSize: 13, color: Color(0xFF166534))),
                ],
              ),
            ),
          if (_conversationClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFFF0FDF4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Conversation closed. Thank you for using ProMech. Chat with us if you find any difficulty.',
                    style: GoogleFonts.inter(fontSize: 13, color: Color(0xFF166534)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Start new conversation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF334155),
                      side: BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
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
                            final isUser = (m['sender'] ?? '').toString().toUpperCase() == 'USER';
                            final isSystem = (m['messageType'] ?? '').toString().contains('PHOTO_PERMISSION');
                            final isAdminJoined = (m['messageType'] ?? '').toString() == 'ADMIN_JOINED';
                            final isConvEnded = (m['messageType'] ?? '').toString() == 'CONVERSATION_ENDED';
                            return _buildBubble(m, isUser, isSystem || isAdminJoined || isConvEnded);
                          }
                          i++;
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
          if (!_conversationClosed && !_photoAllowed && !_requestedPhotoPermission)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _sending ? null : _requestPhotoPermission,
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Request permission to send photos'),
              ),
            ),
          if (!_conversationClosed && _photoAllowed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : () async {
                      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null && mounted) _sendPhoto(File(picked.path));
                    },
                    icon: const Icon(Icons.photo_camera),
                  ),
                  const Text('Send photo', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          if (!_conversationClosed)
          Container(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  if (_photoAllowed)
                    IconButton(
                      onPressed: _sending
                          ? null
                          : () async {
                              final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
                              if (picked != null && mounted) {
                                final f = File(picked.path);
                                if (f.existsSync()) _sendPhoto(f);
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF1E40AF),
                      ),
                    ),
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
                      onChanged: (_) => _setUserTyping(true),
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
                      backgroundColor: const Color(0xFF334155),
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

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day} ${_month(d.month)} ${d.year}';
    } catch (_) { return isoDate; }
  }

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return m >= 1 && m <= 12 ? months[m - 1] : '';
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return url ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl.endsWith('/') ? ApiConfig.baseUrl : ApiConfig.baseUrl + '/';
    return base + (url.startsWith('/') ? url.substring(1) : url);
  }

  Widget _buildBubble(Map<String, dynamic> m, bool isUser, bool isSystem) {
    final msg = m['message'] ?? '';
    final imageUrl = _resolveImageUrl(m['imageUrl']?.toString());
    final time = _formatTime((m['createdAt'] ?? '').toString());
    final bool showIcon = !isSystem;
    final Widget iconWidget = showIcon
        ? Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUser ? Icons.person_outline : Icons.headset_mic_rounded,
              size: 20,
              color: isUser ? const Color(0xFF475569) : Colors.white,
            ),
          )
        : const SizedBox.shrink();

    final Widget bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isSystem ? Colors.amber.shade100 : (isUser ? const Color(0xFFF1F5F9) : const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSystem ? null : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(msg, style: GoogleFonts.inter(fontSize: 15, color: isUser ? const Color(0xFF1E293B) : Colors.white))),
              ),
            )
          else
            Text(msg, style: GoogleFonts.inter(fontSize: 15, color: isUser ? const Color(0xFF1E293B) : Colors.white)),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(time, style: GoogleFonts.inter(fontSize: 11, color: isUser ? Colors.grey : Colors.white70)),
            ),
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: isUser ? [bubble, if (showIcon) ...[const SizedBox(width: 8), iconWidget]] : [if (showIcon) ...[iconWidget, const SizedBox(width: 8)], bubble],
        ),
      ),
    );
  }
}

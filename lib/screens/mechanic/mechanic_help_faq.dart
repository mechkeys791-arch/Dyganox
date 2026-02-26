/// 60+ FAQs for ProMech/Dyganox mechanics - used by help bot
class MechanicHelpFaq {
  static const List<Map<String, String>> faqs = [
    {'q': 'How do I receive booking requests?', 'a': 'You receive requests via push notifications on your phone. Make sure notifications are enabled. When a customer nearby needs help, you get a notification with their name and distance.'},
    {'q': 'How do I accept or reject a booking?', 'a': 'Tap the notification to open the app, then go to Bookings. You will see the request with a map, customer details, and Accept/Decline buttons. Tap Accept to confirm or Decline to reject.'},
    {'q': 'What happens when I accept a booking?', 'a': 'The customer is notified. You can call them, navigate to their location, and complete the job. Remember to mark the booking as Completed when done.'},
    {'q': 'How do I update my availability status?', 'a': 'Use the status dropdown in the top-right of your dashboard. Set yourself to Available, Busy, or Offline. Customers see only Available mechanics.'},
    {'q': 'How do I add or remove services I offer?', 'a': 'Go to My Services from the dashboard. Tap any service to add it, or tap the X on an active service to remove. Changes save to the database immediately.'},
    {'q': 'What services can I add?', 'a': 'You can add: General Repair, Engine Service, Electrical Works, Brake Service, AC Repair, Body Works, Tire Service, Battery Service. Add all services you are qualified to perform.'},
    {'q': 'How do I update my profile?', 'a': 'Tap your profile card on the dashboard. Edit your name, phone, email, specialty, experience, shop address, and profile photo. Tap Save to update.'},
    {'q': 'How do I set my shop location?', 'a': 'In Edit Profile, go to Shop Location. Tap to pick a location on the map. Your location helps customers find nearby mechanics.'},
    {'q': 'What is night time availability?', 'a': 'If you offer service at night, enable "Available for night service" in your profile. Customers can filter for mechanics who work at night.'},
    {'q': 'How do I get paid?', 'a': 'Payment is handled through the app. When you mark a booking as Completed, the amount is processed. Check the Today\'s Earning and earnings overview on your dashboard.'},
    {'q': 'How do I complete a booking?', 'a': 'After finishing the job, open the booking in Bookings and tap "Mark as Completed". The customer is notified and payment is processed.'},
    {'q': 'Can I call the customer?', 'a': 'Yes. In each booking card there is a Call button next to the phone number. Tap it to dial the customer directly.'},
    {'q': 'How do I navigate to the customer?', 'a': 'Open the booking details. Tap the Navigate button to open Google Maps with the customer\'s location. Or use the map in the booking card.'},
    {'q': 'Why am I not getting notifications?', 'a': 'Check: 1) Notifications are enabled in app settings. 2) Battery optimization is off for the app. 3) You have opened the dashboard at least once (registers your device).'},
    {'q': 'How do I register as a mechanic?', 'a': 'Download the app, choose "Mechanic" at login, and fill the registration form. Submit documents. After admin approval, you can log in and start receiving requests.'},
    {'q': 'What documents do I need for registration?', 'a': 'You need Aadhar card and shop-related documents. Upload them during registration. Admin will verify before approval.'},
    {'q': 'How long does approval take?', 'a': 'Admin reviews applications usually within 1-2 business days. You will get a notification when approved. If rejected, you will see the reason.'},
    {'q': 'My account was suspended. What do I do?', 'a': 'Contact support via Help Chat. Explain your situation. The support team will review and assist.'},
    {'q': 'What is the Help Chat / bot?', 'a': 'The Help bot answers common questions about the ProMech app. Tap Help Chat from the dashboard or the floating bot icon to ask questions. Type your question and get instant answers.'},
    {'q': 'How does the floating bot work?', 'a': 'The bot icon at bottom-right of the dashboard opens the same Help Chat. Tap it anytime to get help. Both Help Chat and the bot lead to the same screen.'},
    {'q': 'Can I change my phone number?', 'a': 'Yes. Go to Edit Profile and update your phone number. Remember to save. Your new number will be used for customer calls.'},
    {'q': 'How do I change my profile photo?', 'a': 'In Edit Profile, tap the profile picture circle. Choose a photo from your gallery. Tap Save to update.'},
    {'q': 'What if I accidentally decline a booking?', 'a': 'Once declined, the request goes to other mechanics. You cannot undo. Be careful when tapping Decline.'},
    {'q': 'How many bookings can I accept at once?', 'a': 'You can accept multiple bookings. Set your status to Busy when handling a job to avoid new requests if needed. Switch back to Available when free.'},
    {'q': 'What does Pending mean?', 'a': 'Pending bookings are new requests waiting for your response. Accept or Decline them quickly so customers get help fast.'},
    {'q': 'What does Accepted mean?', 'a': 'Accepted means you have agreed to help. Go to the customer, complete the job, and Mark as Completed.'},
    {'q': 'How do I see my earnings?', 'a': 'Check the Stats Cards (Total Jobs, Pending, Today) and the Today\'s Earning / Earnings Overview sections on your dashboard.'},
    {'q': 'Is there a subscription fee?', 'a': 'Contact support for current pricing. The app may have a commission or subscription for mechanics.'},
    {'q': 'How do I log out?', 'a': 'Go to your profile or app settings. Look for Log out or Sign out. You will need to log in again to receive requests.'},
    {'q': 'What if the customer location is wrong?', 'a': 'Call the customer to confirm the address. You can use Navigate to reach them. If there is an issue, contact support.'},
    {'q': 'Can I cancel an accepted booking?', 'a': 'Once accepted, try to complete the job. If you must cancel, contact support. Frequent cancellations may affect your account.'},
    {'q': 'How do I report a problem?', 'a': 'Use the Help Chat to describe your issue. Or contact support via the contact details in the app.'},
    {'q': 'What if the app crashes?', 'a': 'Restart the app. Ensure you have the latest version. If it keeps crashing, report via Help Chat with your device model and Android version.'},
    {'q': 'How do I update the app?', 'a': 'Go to Play Store (or App Store), search for ProMech/Dyganox, and tap Update if available.'},
    {'q': 'Why can\'t I see the map in a booking?', 'a': 'The customer may not have shared location. If coordinates are missing, the map shows "Location not shared". Call the customer for the address.'},
    {'q': 'How does the mechanic finder work for customers?', 'a': 'Customers open the app, allow location, and see nearby mechanics on a map. They select you and send a request. You get a notification.'},
    {'q': 'What is the difference between Available and Busy?', 'a': 'Available: You are free and customers can send you requests. Busy: You are on a job; fewer or no new requests.'},
    {'q': 'Should I stay Online?', 'a': 'When you are ready to take jobs, set status to Available and keep the app open or in background. Notifications will reach you.'},
    {'q': 'How do I improve my rating?', 'a': 'Complete jobs on time, communicate well with customers, and provide quality service. Customers may rate you after completion.'},
    {'q': 'Where can I see my rating?', 'a': 'Your rating is shown on your profile card on the dashboard. It reflects customer feedback.'},
    {'q': 'What is Total Jobs?', 'a': 'Total Jobs shows how many bookings you have completed. It reflects your experience on the platform.'},
    {'q': 'How do I enable night service?', 'a': 'In Edit Profile, turn ON "Available for night service". Customers who need help at night will see you.'},
    {'q': 'Can I block a customer?', 'a': 'Contact support to report issues with a customer. They can assist with blocking if needed.'},
    {'q': 'What payment methods does the app support?', 'a': 'The app supports multiple payment options. Payment is handled through the platform. Check the payment section for details.'},
    {'q': 'When do I get paid?', 'a': 'Payment is processed after you mark a booking Completed. Settlement timing depends on the platform policy. Check earnings for details.'},
    {'q': 'How do I add my bank details?', 'a': 'Go to Profile or Settings. Look for Payment or Bank Details. Add your account for receiving payments.'},
    {'q': 'What if a customer doesn\'t pay?', 'a': 'Payment is taken through the app before or during the job. If there is a dispute, contact support with the booking ID.'},
    {'q': 'How do I see my pending bookings?', 'a': 'Tap Bookings on the dashboard. Use the filter chips: All, Pending, Accepted, Completed. Pending shows new requests.'},
    {'q': 'What information do I see in a booking?', 'a': 'Each booking shows: customer name, phone (with Call button), service type, vehicle, location (with map), date/time, and amount.'},
    {'q': 'Can I charge extra?', 'a': 'The amount is set in the app. Do not charge customers extra. If there are additional costs, discuss with support.'},
    {'q': 'How do I contact support?', 'a': 'Use Help Chat (tap Help Chat or the floating bot). Type your question. For urgent issues, check the app for a phone number or email.'},
    {'q': 'What is the ProMech app?', 'a': 'ProMech (Dyganox) connects vehicle owners with mechanics. Customers request help, mechanics receive notifications and can accept jobs. It simplifies roadside assistance and workshop visits.'},
    {'q': 'Who built this app?', 'a': 'ProMech/Dyganox is built to help mechanics grow their business and serve customers efficiently. For technical or business inquiries, contact support.'},
    {'q': 'Is my data secure?', 'a': 'We use secure connections and follow best practices to protect your data. Do not share your login details with anyone.'},
    {'q': 'How do I change my password?', 'a': 'After admin approval, you set a password during first login. To change it, go to Profile or Settings and look for Change Password.'},
    {'q': 'I forgot my password. What do I do?', 'a': 'Use the Forgot Password option on the login screen. Enter your email to receive a reset link.'},
    {'q': 'Can I use the app on multiple devices?', 'a': 'You can log in on one device at a time. Notifications go to the device where you last opened the dashboard.'},
    {'q': 'How do I delete my account?', 'a': 'Contact support to request account deletion. They will guide you through the process.'},
    {'q': 'What if I have a suggestion?', 'a': 'We love feedback! Use Help Chat to send your suggestions. The team reviews all feedback.'},
    {'q': 'How do I get more bookings?', 'a': 'Stay Available, add all services you offer, keep your profile updated, maintain a good rating, and enable night service if you can.'},
    {'q': 'What should I do if a customer is not at the location?', 'a': 'Call the customer to confirm. If they are not there, you may need to wait or contact support. Do not mark Completed until the job is done.'},
    {'q': 'Can I see customer reviews?', 'a': 'Check your profile for your overall rating. Individual reviews may be visible in the app depending on the version.'},
    {'q': 'What is the minimum payout?', 'a': 'Check the payment or earnings section for minimum payout thresholds. Contact support for exact details.'},
    {'q': 'How do I verify my identity?', 'a': 'During registration you upload Aadhar and other documents. Admin verifies them. You may need to re-verify if asked.'},
    {'q': 'What if I need training?', 'a': 'Use this Help bot to learn. You can also contact support for training or onboarding assistance.'},
    {'q': 'Hello', 'a': 'Hello! I\'m the ProMech Help bot. How can I assist you today? Try asking: "How do I receive booking requests?" or "How do I add services?"'},
    {'q': 'Hi', 'a': 'Hi! Welcome to ProMech Help. What would you like to know? You can ask about bookings, profile, payments, or any app feature.'},
    {'q': 'Help', 'a': 'I\'m here to help! Ask me anything about the ProMech app: receiving requests, accepting bookings, updating profile, adding services, payments, and more. Try: "How do I accept a booking?"'},
    {'q': 'Thanks', 'a': 'You\'re welcome! If you have more questions, just ask. Stay safe and happy repairing!'},
    {'q': 'Thank you', 'a': 'Glad I could help! Feel free to ask more anytime.'},
  ];

  /// Find best matching answer for user message. Returns null if no good match.
  static String? getAnswer(String userMessage) {
    if (userMessage.trim().isEmpty) return null;
    final lower = userMessage.trim().toLowerCase();
    // Exact or high similarity match
    for (final faq in faqs) {
      final q = faq['q']!.toLowerCase();
      if (q == lower || q.contains(lower) || lower.contains(q)) {
        return faq['a'];
      }
    }
    // Keyword match
    final words = lower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    int bestScore = 0;
    String? bestAnswer;
    for (final faq in faqs) {
      final q = faq['q']!.toLowerCase();
      int score = 0;
      for (final w in words) {
        if (q.contains(w)) score++;
      }
      if (score > bestScore && score >= (words.length / 2).ceil()) {
        bestScore = score;
        bestAnswer = faq['a'];
      }
    }
    return bestAnswer;
  }

  /// Suggested questions for quick access
  static List<String> get suggestedQuestions => [
    'How do I receive booking requests?',
    'How do I accept a booking?',
    'How do I add services?',
    'How do I update my profile?',
    'Why am I not getting notifications?',
    'How do I get paid?',
  ];
}

/// Problem categories and diagnostic questions for Book Mechanic flow.
/// Car and bike have separate problem lists; some keys overlap (e.g. tyre_puncture).

import 'package:flutter/material.dart';

class ProblemItem {
  final String id;
  final String label;
  final String? suggestion;
  final List<DiagnosticQuestion>? diagnosticQuestions;
  final IconData icon;

  const ProblemItem({
    required this.id,
    required this.label,
    this.suggestion,
    this.diagnosticQuestions,
    this.icon = Icons.build_circle_outlined,
  });
}

class DiagnosticQuestion {
  final String id;
  final String question;
  final List<String> options; // e.g. ["Yes", "No"]

  const DiagnosticQuestion({required this.id, required this.question, required this.options});
}

// ---------- Car problems ----------
const List<ProblemItem> carProblems = [
  ProblemItem(
    id: 'tyre_puncture',
    label: 'Tyre puncture / flat',
    icon: Icons.tire_repair,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'which_tyre', question: 'Which tyre is affected?', options: ['Front left', 'Front right', 'Rear left', 'Rear right', 'Multiple']),
      DiagnosticQuestion(id: 'repair_or_replace', question: 'Do you want repair or replace?', options: ['Repair (puncture)', 'Replace (worn/damaged)']),
    ],
  ),
  ProblemItem(
    id: 'battery_jump',
    label: 'Vehicle not starting (battery)',
    icon: Icons.battery_charging_full,
    suggestion: 'Try: Check if lights work. If completely dead, battery jump or replacement may be needed.',
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'dashboard_lights', question: 'When you turn the key, do dashboard lights turn ON?', options: ['Yes', 'No']),
      DiagnosticQuestion(id: 'clicking_sound', question: 'Do you hear a clicking sound?', options: ['Yes', 'No']),
      DiagnosticQuestion(id: 'manual_auto', question: 'Is your vehicle manual or automatic?', options: ['Manual', 'Automatic']),
    ],
  ),
  ProblemItem(
    id: 'ev_vehicle_charge',
    label: 'EV charging / out of charge',
    icon: Icons.ev_station,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'charge_level', question: 'Approximate battery level?', options: ['Under 10%', '10–30%', '30–60%', 'Not sure']),
      DiagnosticQuestion(id: 'connector', question: 'Connector type (if known)?', options: ['CCS2', 'Type 2', 'CHAdeMO', 'Not sure']),
    ],
  ),
  ProblemItem(
    id: 'engine_repair',
    label: 'Engine issue / smoke / overheating',
    icon: Icons.engineering,
    suggestion: 'Stop the vehicle if smoke or overheating. Do not drive. A mechanic can diagnose on-site.',
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'smoke_color', question: 'What color is the smoke (if any)?', options: ['White', 'Blue', 'Black', 'No smoke']),
      DiagnosticQuestion(id: 'when_smoke', question: 'When does it happen?', options: ['On start', 'While driving', 'When accelerating', 'When idle']),
    ],
  ),
  ProblemItem(
    id: 'brake_issue',
    label: 'Brake problem',
    icon: Icons.car_crash,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'brake_type', question: 'What are you experiencing?', options: ['Spongy brake pedal', 'Brake noise', 'Vehicle pulls to one side', 'Brake warning light']),
    ],
  ),
  ProblemItem(
    id: 'electrical',
    label: 'Electrical / lights / battery',
    icon: Icons.electric_bolt,
  ),
  ProblemItem(
    id: 'ac_issue',
    label: 'AC not cooling',
    icon: Icons.ac_unit,
  ),
  ProblemItem(
    id: 'general_checkup',
    label: 'General checkup (not sure what\'s wrong)',
    icon: Icons.search,
    suggestion: 'Mechanic will call you after you book the service. Describe what you notice if you can.',
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'vehicle_condition', question: 'How would you describe the issue?', options: ['Strange noise', 'Warning light on', 'Performance issue', 'Routine check', 'Not sure']),
      DiagnosticQuestion(id: 'when_notice', question: 'When did you first notice it?', options: ['Today', 'This week', 'This month', 'Gradually over time']),
      DiagnosticQuestion(id: 'mileage', question: 'When was the last full service?', options: ['Within 3 months', '3–6 months ago', '6–12 months ago', 'Over a year ago', 'Never / new vehicle']),
      DiagnosticQuestion(id: 'urgency', question: 'How urgent is it?', options: ['Can wait a few days', 'Need within 24 hours', 'As soon as possible']),
    ],
  ),
];

// ---------- Bike problems ----------
const List<ProblemItem> bikeProblems = [
  ProblemItem(
    id: 'tyre_puncture',
    label: 'Tyre puncture / flat',
    icon: Icons.tire_repair,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'which_tyre', question: 'Which tyre?', options: ['Front', 'Rear', 'Both']),
      DiagnosticQuestion(id: 'repair_or_replace', question: 'Repair or replace?', options: ['Repair', 'Replace']),
    ],
  ),
  ProblemItem(
    id: 'battery_jump',
    label: 'Bike not starting (battery)',
    icon: Icons.battery_charging_full,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'dashboard_lights', question: 'Do dashboard/headlight turn ON when you switch key?', options: ['Yes', 'No']),
      DiagnosticQuestion(id: 'clicking_sound', question: 'Do you hear a clicking sound?', options: ['Yes', 'No']),
    ],
  ),
  ProblemItem(
    id: 'ev_vehicle_charge',
    label: 'EV / e-bike charging help',
    icon: Icons.ev_station,
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'charge_level', question: 'Approximate charge left?', options: ['Empty', 'Low', 'Medium', 'Not sure']),
    ],
  ),
  ProblemItem(
    id: 'engine_repair',
    label: 'Engine issue / smoke / unusual sound',
    icon: Icons.engineering,
    suggestion: 'Do not ride if there is smoke or loud knocking. Mechanic can check on-site.',
  ),
  ProblemItem(
    id: 'brake_issue',
    label: 'Brake problem',
    icon: Icons.car_crash,
  ),
  ProblemItem(
    id: 'electrical',
    label: 'Electrical / lights / horn',
    icon: Icons.electric_bolt,
  ),
  ProblemItem(
    id: 'general_checkup',
    label: 'General checkup (not sure what\'s wrong)',
    icon: Icons.search,
    suggestion: 'Mechanic will call you after you book the service.',
    diagnosticQuestions: [
      DiagnosticQuestion(id: 'vehicle_condition', question: 'How would you describe the issue?', options: ['Strange noise', 'Starting problem', 'Performance issue', 'Routine check', 'Not sure']),
      DiagnosticQuestion(id: 'when_notice', question: 'When did you first notice it?', options: ['Today', 'This week', 'This month', 'Gradually over time']),
      DiagnosticQuestion(id: 'last_service', question: 'Last full service?', options: ['Within 3 months', '3–6 months ago', '6–12 months ago', 'Over a year ago']),
      DiagnosticQuestion(id: 'urgency', question: 'How urgent?', options: ['Can wait', 'Within 24 hours', 'As soon as possible']),
    ],
  ),
];

List<ProblemItem> getProblemsForVehicle(String type) {
  return (type.toUpperCase() == 'BIKE') ? bikeProblems : carProblems;
}

ProblemItem? getProblemById(String type, String id) {
  final list = getProblemsForVehicle(type);
  try {
    return list.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

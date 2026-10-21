import '../models/models.dart';

/// Simple in-memory "backend" so the UI is fully interactive out of the box.
/// Replace each method's body with real Firebase/Firestore calls when ready
/// — the shape of the data is deliberately kept close to the planned
/// Firestore collections (users, careRecipients, devices, medicineReminders,
/// notifications, healthData, mlPredictions).
class AppData {
  AppData._();
  static final AppData instance = AppData._();

  AppUser currentUser = const AppUser(name: 'John Carter', email: 'john@example.com');

  CareRecipient careRecipient = CareRecipient(
    name: 'Margaret Carter',
    age: 74,
    gender: 'Female',
    bloodGroup: 'O+',
    heightCm: 162,
    weightKg: 68,
    diseases: const ['Hypertension', 'Type 2 Diabetes'],
    allergies: const ['Penicillin'],
    medicines: const ['Metformin 500mg', 'Amlodipine 5mg'],
    contacts: [
      EmergencyContact(name: 'John Carter', relationship: 'Son', phone: '+1 202 555 0110'),
      EmergencyContact(name: 'Alice Carter', relationship: 'Daughter', phone: '+1 202 555 0133'),
    ],
    doctorNumber: '+1 202 555 0199',
    ambulanceNumber: '911',
  );

  WatchDevice? device = WatchDevice(
    id: 'WATCH001',
    connected: true,
    batteryPercent: 86,
    lastSync: DateTime.now().subtract(const Duration(minutes: 12)),
  );

  VitalsReading currentVitals = VitalsReading(
    heartRate: 78,
    spo2: 98,
    measuredAt: DateTime.now().subtract(const Duration(minutes: 3)),
  );

  final int avgHeartRate = 76;
  final int avgSpo2 = 98;
  final int medicineCompliancePercent = 95;
  final HealthStatus overallStatus = HealthStatus.good;
  final int aiRiskScorePercent = 5;

  List<MedicineReminder> medicineReminders = [];

  List<AppNotification> notifications = const [
    AppNotification(title: 'Medicine Reminder — BP Tablet', time: '10:30 AM', severity: NotificationSeverity.info),
    AppNotification(title: 'Heart Rate Increased to 102 BPM', time: '12:45 PM', severity: NotificationSeverity.warning),
    AppNotification(title: 'SOS Button Pressed', time: '2:15 PM', severity: NotificationSeverity.critical),
    AppNotification(title: 'Watch Went Offline', time: 'Yesterday', severity: NotificationSeverity.warning),
    AppNotification(title: 'Low Battery (15%)', time: 'Yesterday', severity: NotificationSeverity.info),
  ];

  void toggleMedicineTaken(String id) {
    final med = medicineReminders.firstWhere((m) => m.id == id);
    med.taken = !med.taken;
  }
}

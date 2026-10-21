enum HealthStatus { good, attention, emergency }

class AppUser {
  final String name;
  final String email;
  const AppUser({required this.name, required this.email});
}

class CareRecipient {
  String name;
  int age;
  String gender;
  String bloodGroup;
  double heightCm;
  double weightKg;
  List<String> diseases;
  List<String> allergies;
  List<String> medicines;
  List<EmergencyContact> contacts;
  String doctorNumber;
  String? ambulanceNumber;

  CareRecipient({
    required this.name,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.heightCm,
    required this.weightKg,
    required this.diseases,
    required this.allergies,
    required this.medicines,
    required this.contacts,
    required this.doctorNumber,
    this.ambulanceNumber,
  });
}

class EmergencyContact {
  String name;
  String relationship;
  String phone;
  EmergencyContact({required this.name, required this.relationship, required this.phone});
}

class WatchDevice {
  final String id;
  bool connected;
  int batteryPercent;
  DateTime lastSync;
  WatchDevice({
    required this.id,
    required this.connected,
    required this.batteryPercent,
    required this.lastSync,
  });
}

class MedicineReminder {
  final String id;
  String name;
  String time; // e.g. "8:00 AM"
  String label; // e.g. "Morning"
  bool taken;
  DateTime? repeatFromDate;
  DateTime? repeatToDate;

  MedicineReminder({
    required this.id,
    required this.name,
    required this.time,
    required this.label,
    this.taken = false,
    this.repeatFromDate,
    this.repeatToDate,
  });
}

class AppNotification {
  final String title;
  final String time;
  final NotificationSeverity severity;
  const AppNotification({required this.title, required this.time, required this.severity});
}

enum NotificationSeverity { info, warning, critical }

class VitalsReading {
  final int heartRate;
  final int spo2;
  final DateTime measuredAt;
  const VitalsReading({required this.heartRate, required this.spo2, required this.measuredAt});
}

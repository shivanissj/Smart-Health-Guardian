import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedFirestore() async {
  final db = FirebaseFirestore.instance;

  // USERS
  await db.collection("users").doc("sample_uid").set({
    "email": "sample@gmail.com",
    "created_at": Timestamp.now(),
  });

  // CARE RECIPIENT
  await db.collection("care_recipient_details").doc("sample_uid").set({
    "patient_name": "John Doe",
    "age": 70,
    "gender": "Male",
    "blood_group": "O+",
    "height": 170,
    "weight": 72,
    "medical_conditions": ["Diabetes"],
    "allergies": ["Dust"]
  });

  // EMERGENCY CONTACT
  await db.collection("emergency_contacts").add({
    "uid": "sample_uid",
    "contact_name": "Raj",
    "contact_number": "9876543210",
    "relationship": "Son"
  });

  // DOCTOR
  await db.collection("doctor_details").doc("sample_uid").set({
    "doctor_name": "Dr Kumar",
    "doctor_phone": "9999999999",
    "ambulance_number": "108"
  });

  // WATCH
  await db.collection("watch_details").doc("WATCH001").set({
    "uid": "sample_uid",
    "device_id": "WATCH001",
    "battery_percentage": 100,
    "paired": false,
    "last_sync": Timestamp.now(),
  });

  // MEDICINE
  await db.collection("medicine_reminders").add({
    "uid": "sample_uid",
    "medicine_name": "BP Tablet",
    "reminder_time": Timestamp.now(),
    "reminder_label": "Morning",
    "repeat_from_date": Timestamp.now(),
    "repeat_to_date": Timestamp.now(),
  });

  // HEALTH DATA
  await db.collection("health_data").add({
    "uid": "sample_uid",
    "device_id": "WATCH001",
    "heart_rate": 82,
    "spo2": 98,
    "battery_percentage": 98,
    "timestamp": Timestamp.now(),
  });

  // ML PREDICTION
  await db.collection("ml_predictions").add({
    "uid": "sample_uid",
    "risk_level": "Low",
    "probability": 0.04,
    "recommendation": "Healthy",
    "timestamp": Timestamp.now(),
  });

  // EMERGENCY
  await db.collection("emergency_events").add({
    "uid": "sample_uid",
    "event_type": "SOS Button",
    "timestamp": Timestamp.now(),
  });

  // NOTIFICATIONS
  await db.collection("notifications").add({
    "uid": "sample_uid",
    "title": "Medicine Reminder",
    "message": "Take BP Tablet",
    "timestamp": Timestamp.now(),
  });
}

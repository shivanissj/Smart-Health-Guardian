import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../create_care_recipient_screen.dart';

class CareRecipientProfileScreen extends StatefulWidget {
  const CareRecipientProfileScreen({super.key});

  @override
  State<CareRecipientProfileScreen> createState() => _CareRecipientProfileScreenState();
}

class _CareRecipientProfileScreenState extends State<CareRecipientProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sample_uid';

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Care Recipient', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCareRecipientScreen(isEdit: true)),
            ),
            child: const Text('Edit', style: TextStyle(color: AppColors.teal)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("care_recipient_details").doc(uid).snapshots(),
        builder: (context, recipientSnap) {
          if (recipientSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!recipientSnap.hasData || !recipientSnap.data!.exists) {
            return const Center(child: Text("No details found", style: TextStyle(color: AppColors.grey500)));
          }

          final recipientData = recipientSnap.data!.data() as Map<String, dynamic>;
          final name = recipientData["patient_name"] ?? "—";
          final age = recipientData["age"] ?? 0;
          final gender = recipientData["gender"] ?? "—";
          final bloodGroup = recipientData["blood_group"] ?? "—";
          final height = recipientData["height"] ?? 0.0;
          final weight = recipientData["weight"] ?? 0.0;
          final medicalConditions = List<String>.from(recipientData["medical_conditions"] ?? []);
          final allergies = List<String>.from(recipientData["allergies"] ?? []);

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection("doctor_details").doc(uid).snapshots(),
            builder: (context, doctorSnap) {
              final doctorData = doctorSnap.hasData && doctorSnap.data!.exists
                  ? doctorSnap.data!.data() as Map<String, dynamic>
                  : {};
              final doctorName = doctorData["doctor_name"] ?? "—";
              final doctorPhone = doctorData["doctor_phone"] ?? "—";
              final ambulanceNumber = doctorData["ambulance_number"] ?? "—";

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("emergency_contacts")
                    .where("uid", isEqualTo: uid)
                    .snapshots(),
                builder: (context, contactsSnap) {
                  final contactsDocs = contactsSnap.hasData ? contactsSnap.data!.docs : [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Patient Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2A2A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.teal.withOpacity(0.2),
                                child: Text(
                                  name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$age yrs • $gender • $bloodGroup',
                                      style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: StatTile(label: 'Height', value: '${height.toStringAsFixed(0)} cm', icon: Icons.height_rounded)),
                            const SizedBox(width: 12),
                            Expanded(child: StatTile(label: 'Weight', value: '${weight.toStringAsFixed(0)} kg', icon: Icons.monitor_weight_rounded)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Medical Details'),
                        _chipGroup('Existing Diseases', medicalConditions),
                        _chipGroup('Allergies', allergies),

                        const SizedBox(height: 8),
                        const SectionHeader(title: 'Emergency Contacts'),
                        if (contactsDocs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text("No emergency contacts registered", style: TextStyle(color: AppColors.grey500, fontSize: 13)),
                          )
                        else
                          ...contactsDocs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;
                            final cData = doc.data() as Map<String, dynamic>;
                            final cName = cData["contact_name"] ?? "—";
                            final cRelation = cData["relationship"] ?? "—";
                            final cPhone = cData["contact_number"] ?? "—";

                            late final Color iconBg;
                            late final Color iconColor;
                            late final IconData iconData;

                            if (index == 0) {
                              iconBg = const Color(0xFF0FB6A6).withOpacity(0.18);
                              iconColor = const Color(0xFF0FB6A6);
                              iconData = Icons.account_circle_rounded;
                            } else if (index == 1) {
                              iconBg = const Color(0xFFE0A93B).withOpacity(0.18);
                              iconColor = const Color(0xFFE0A93B);
                              iconData = Icons.person_3_rounded;
                            } else {
                              iconBg = AppColors.grey600.withOpacity(0.18);
                              iconColor = AppColors.grey500;
                              iconData = Icons.person_rounded;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2A2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: iconColor.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(iconData, size: 17, color: iconColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.white)),
                                        Text(cRelation, style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  Text(cPhone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.teal)),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.local_hospital_rounded, size: 17, color: AppColors.teal),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doctorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.white)),
                                    const Text("Doctor", style: TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Text(doctorPhone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.teal)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        StatTile(label: 'Ambulance Number', value: ambulanceNumber, icon: Icons.emergency_rounded, accent: AppColors.danger),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _chipGroup(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text("None", style: TextStyle(color: AppColors.grey500, fontSize: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

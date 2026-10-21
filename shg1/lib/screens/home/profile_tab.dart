import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../auth_screen.dart';
import 'care_recipient_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email ?? '—';
    final uid = firebaseUser?.uid ?? 'sample_uid';
    // Derive a display name from Firebase Auth as fallback
    final authDisplayName = firebaseUser?.displayName
        ?? (email != '—' ? email.split('@').first : 'User');

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, userSnap) {
          final docExists = userSnap.hasData && userSnap.data!.exists;
          final userData = docExists
              ? userSnap.data!.data() as Map<String, dynamic>
              : {};

          // Auto-create missing users doc from Firebase Auth info
          if (userSnap.connectionState != ConnectionState.waiting && !docExists && uid != 'sample_uid') {
            FirebaseFirestore.instance.collection('users').doc(uid).set({
              'name': authDisplayName,
              'email': email,
              'created_at': Timestamp.now(),
            }, SetOptions(merge: true));
          }

          final userName = (userData["name"] as String?)?.trim().isNotEmpty == true
              ? userData["name"] as String
              : authDisplayName;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection("care_recipient_details").doc(uid).snapshots(),
            builder: (context, recipientSnap) {
              final recipientData = recipientSnap.hasData && recipientSnap.data!.exists
                  ? recipientSnap.data!.data() as Map<String, dynamic>
                  : {};
              final recipientName = recipientData["patient_name"] ?? "—";
              final age = recipientData["age"] ?? 0;
              final bloodGroup = recipientData["blood_group"] ?? "—";

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'User Account'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.grey700.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.teal.withOpacity(0.2),
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(color: AppColors.grey500, fontSize: 12.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Care Recipient'),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareRecipientProfileScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2A2A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.favorite_rounded, color: AppColors.teal, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(recipientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.white)),
                                  Text('$age yrs • $bloodGroup',
                                      style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                        label: const Text('Log Out', style: TextStyle(color: AppColors.danger)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/vitals_socket_service.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  @override
  void initState() {
    super.initState();
    VitalsSocketService.instance.initSocket();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sample_uid';

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications & Alerts', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: VitalsSocketService.instance.emergencyAlertNotifier,
        builder: (context, socketEmergency, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final dbDocs = snapshot.hasData ? snapshot.data!.docs : [];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('emergency_contacts')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, contactsSnap) {
                  final contactDocs = contactsSnap.hasData ? contactsSnap.data!.docs : [];
                  final registeredNumbers = contactDocs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return "${d['contact_name'] ?? d['name'] ?? 'Contact'} (${d['contact_number'] ?? d['phone'] ?? ''})";
                  }).toList();

                  if (registeredNumbers.isEmpty) {
                    registeredNumbers.addAll(['Raj (9876543210)', 'John Carter (+1 202 555 0110)']);
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Socket.IO Emergency Alert Banner
                        if (socketEmergency != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.dangerTint,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.danger, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.sos_rounded, color: AppColors.danger, size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        socketEmergency['title'] ?? '🚨 CRITICAL EMERGENCY ALERT',
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  socketEmergency['message'] ?? 'Critical Vitals detected! Emergency SMS dispatched to all registered numbers.',
                                  style: const TextStyle(color: AppColors.white, fontSize: 13, height: 1.35),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Registered Contact Numbers Alerted:',
                                  style: TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: registeredNumbers.map((numStr) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.send_to_mobile_rounded, color: AppColors.danger, size: 14),
                                          const SizedBox(width: 6),
                                          Text(numStr, style: const TextStyle(color: AppColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SectionHeader(title: 'Activity & History'),
                        if (dbDocs.isEmpty && socketEmergency == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(child: Text('No notifications yet', style: TextStyle(color: AppColors.grey500))),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dbDocs.length,
                            itemBuilder: (context, i) {
                              final data = dbDocs[i].data() as Map<String, dynamic>;
                              final title = (data['title'] ?? 'Notification').toString();
                              final message = (data['message'] ?? '').toString();
                              final severityStr = (data['severity'] ?? 'info').toString();
                              final ts = data['timestamp'] as Timestamp?;
                              final timeStr = ts != null ? _fmtTime(ts.toDate()) : 'Recent';

                              return _NotificationTile(
                                title: title,
                                message: message,
                                time: timeStr,
                                severity: severityStr,
                                isLast: i == dbDocs.length - 1,
                              );
                            },
                          ),
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

  String _fmtTime(DateTime? dt) {
    if (dt == null) return 'Recent';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final String severity;
  final bool isLast;

  const _NotificationTile({
    required this.title,
    required this.message,
    required this.time,
    required this.severity,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;

    switch (severity.toLowerCase()) {
      case 'critical':
      case 'emergency':
        color = AppColors.danger;
        icon = Icons.sos_rounded;
        break;
      case 'warning':
        color = AppColors.warn;
        icon = Icons.warning_rounded;
        break;
      default:
        color = AppColors.teal;
        icon = Icons.info_rounded;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 17),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.grey100.withOpacity(0.2))),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
                      Text(time, style: const TextStyle(color: AppColors.grey500, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(message, style: const TextStyle(color: AppColors.grey500, fontSize: 12.5, height: 1.3)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

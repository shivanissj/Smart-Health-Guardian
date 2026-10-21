import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/vitals_socket_service.dart';

class LiveMonitoringTab extends StatefulWidget {
  const LiveMonitoringTab({super.key});

  @override
  State<LiveMonitoringTab> createState() => _LiveMonitoringTabState();
}

class _LiveMonitoringTabState extends State<LiveMonitoringTab> {
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
        title: const Text('Live Monitoring', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: VitalsSocketService.instance.vitalsNotifier,
        builder: (context, socketData, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('health_data')
                .where('uid', isEqualTo: uid)
                .snapshots(),
            builder: (context, healthSnap) {
              final docs = healthSnap.hasData ? healthSnap.data!.docs : [];

              int heartRate = 0;
              int spo2 = 0;
              DateTime? measuredAt;

              if (docs.isNotEmpty) {
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hr = (data['heart_rate'] ?? 0) as int;
                  final sp = (data['spo2'] ?? 0) as int;
                  if (hr > 0 || sp > 0) {
                    heartRate = hr;
                    spo2 = sp;
                    final ts = data['timestamp'] as Timestamp?;
                    measuredAt = ts?.toDate();
                    break;
                  }
                }
              }

              final displayHr = socketData?['heart_rate'] ?? (heartRate > 0 ? heartRate : null);
              final displaySpo2 = socketData?['spo2'] ?? (spo2 > 0 ? spo2 : null);
              final batteryVal = socketData?['battery_percentage'] ?? 0;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('watch_details')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, watchSnap) {
                  final watchDocs = watchSnap.hasData ? watchSnap.data!.docs : [];
                  final watchData = watchDocs.isNotEmpty ? watchDocs.first.data() as Map<String, dynamic> : {};
                  final batteryPercent = batteryVal > 0 ? batteryVal : (watchData['battery_percentage'] ?? 0);
                  final lastSyncTs = watchData['last_sync'] as Timestamp?;
                  final lastSync = lastSyncTs?.toDate();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _VitalCard(
                                icon: Icons.favorite_rounded,
                                label: 'Heart Rate',
                                value: displayHr != null ? '$displayHr' : '--',
                                unit: 'BPM',
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _VitalCard(
                                icon: Icons.air_rounded,
                                label: 'SpO₂',
                                value: displaySpo2 != null ? '$displaySpo2' : '--',
                                unit: '%',
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Device'),
                        StatTile(
                          label: 'Last Recorded Time',
                          value: socketData != null ? 'Just Now (Socket.IO)' : _fmtTime(measuredAt),
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(height: 10),
                        StatTile(label: 'Watch Battery', value: '$batteryPercent%', icon: Icons.battery_5_bar_rounded),
                        const SizedBox(height: 10),
                        StatTile(label: 'Last Sync', value: _fmtTime(lastSync), icon: Icons.sync_rounded),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFF1A2A2A), borderRadius: BorderRadius.circular(14)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.teal),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Readings auto-refresh live via Socket.IO whenever new measurements arrive from your ESP32 sensor.',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.grey500, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
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
    if (dt == null) return '--:--';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _VitalCard({required this.icon, required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: AppColors.grey500, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

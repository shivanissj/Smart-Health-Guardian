import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../services/vitals_socket_service.dart';
import 'health_reports_screen.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Connect to Node.js Socket.IO server
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
        title: const Text('Health Dashboard', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthReportsScreen())),
            icon: const Icon(Icons.description_outlined, size: 18, color: AppColors.teal),
            label: const Text('Reports', style: TextStyle(color: AppColors.teal)),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: VitalsSocketService.instance.vitalsNotifier,
          builder: (context, socketData, _) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('health_data')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, healthSnap) {
                final docs = healthSnap.hasData ? healthSnap.data!.docs : [];

                int latestHr = 0;
                int latestSpo2 = 0;
                int avgHr = 0;
                int avgSpo2 = 0;

                if (docs.isNotEmpty) {
                  final validHRs = <int>[];
                  final validSpO2s = <int>[];

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final hr = (data['heart_rate'] ?? 0) as int;
                    final sp = (data['spo2'] ?? 0) as int;
                    if (hr > 0) validHRs.add(hr);
                    if (sp > 0) validSpO2s.add(sp);
                  }

                  if (validHRs.isNotEmpty) {
                    latestHr = validHRs.first;
                    avgHr = (validHRs.reduce((a, b) => a + b) / validHRs.length).round();
                  }
                  if (validSpO2s.isNotEmpty) {
                    latestSpo2 = validSpO2s.first;
                    avgSpo2 = (validSpO2s.reduce((a, b) => a + b) / validSpO2s.length).round();
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ml_predictions')
                      .where('uid', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, mlSnap) {
                    final mlDocs = mlSnap.hasData ? mlSnap.data!.docs : [];
                    final latestMl = mlDocs.isNotEmpty ? mlDocs.first.data() as Map<String, dynamic> : {};

                    // Extract Socket.IO or Firestore real data
                    final currentLiveHr = (socketData?['heart_rate'] ?? latestHr) as int;
                    final currentLiveSpo2 = (socketData?['spo2'] ?? latestSpo2) as int;
                    final currentAvgHr = (socketData?['avg_heart_rate'] ?? avgHr) as int;
                    final currentAvgSpo2 = (socketData?['avg_spo2'] ?? avgSpo2) as int;

                    final displayLiveHrText = currentLiveHr > 0 ? '$currentLiveHr BPM' : '-- BPM';
                    final displayLiveSpo2Text = currentLiveSpo2 > 0 ? '$currentLiveSpo2%' : '--%';
                    final displayAvgHrText = currentAvgHr > 0 ? '$currentAvgHr BPM' : '-- BPM';
                    final displayAvgSpo2Text = currentAvgSpo2 > 0 ? '$currentAvgSpo2%' : '--%';

                    final riskLevel = (socketData?['risk_level'] ?? latestMl['risk_level'] ?? 'Low').toString();
                    final confidenceNum = socketData?['confidence'] ?? ((latestMl['probability'] ?? 0.05) as num) * 100;
                    final confidencePercent = (confidenceNum as num).round();

                    final isHighRisk = riskLevel.toLowerCase() == 'high';
                    final isMediumRisk = riskLevel.toLowerCase() == 'medium';

                    HealthStatus overallStatus = HealthStatus.good;
                    if (isHighRisk || (currentLiveHr > 0 && (currentLiveHr > 120 || currentLiveHr < 50)) || (currentLiveSpo2 > 0 && currentLiveSpo2 < 90)) {
                      overallStatus = HealthStatus.emergency;
                    } else if (isMediumRisk || (currentLiveHr > 100) || (currentLiveSpo2 > 0 && currentLiveSpo2 < 95)) {
                      overallStatus = HealthStatus.attention;
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2A2A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Overall Health', style: TextStyle(color: AppColors.grey500, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: socketData != null ? AppColors.teal : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          socketData != null ? 'Socket Live' : 'Connecting...',
                                          style: TextStyle(
                                            color: socketData != null ? AppColors.teal : AppColors.grey500,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StatusPill(status: overallStatus),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const SectionHeader(title: 'Live Sensor Summary'),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.8,
                            children: [
                              StatTile(label: 'Live Heart Rate', value: displayLiveHrText, icon: Icons.favorite_rounded, accent: AppColors.danger),
                              StatTile(label: 'Live SpO₂', value: displayLiveSpo2Text, icon: Icons.air_rounded, accent: AppColors.teal),
                              StatTile(label: 'Average Heart Rate', value: displayAvgHrText, icon: Icons.show_chart_rounded),
                              StatTile(label: 'Average SpO₂', value: displayAvgSpo2Text, icon: Icons.cloud_done_rounded),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SectionHeader(title: "Today's Status"),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isHighRisk ? AppColors.dangerTint : (isMediumRisk ? AppColors.warnTint : const Color(0xFF1A3D34)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isHighRisk ? AppColors.danger.withOpacity(0.4) : (isMediumRisk ? const Color(0xFF9A7517) : AppColors.teal.withOpacity(0.4))),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isHighRisk ? Icons.warning_amber_rounded : (isMediumRisk ? Icons.info_outline_rounded : Icons.check_circle_rounded),
                                  color: isHighRisk ? AppColors.danger : (isMediumRisk ? const Color(0xFF9A7517) : AppColors.teal),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isHighRisk ? 'Requires Immediate Attention' : (isMediumRisk ? 'Monitor Closely' : 'Healthy'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isHighRisk ? AppColors.danger : (isMediumRisk ? const Color(0xFF9A7517) : AppColors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SectionHeader(title: 'AI Prediction'),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isHighRisk ? AppColors.dangerTint : (isMediumRisk ? AppColors.warnTint : AppColors.tealTint),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isHighRisk ? Icons.warning_rounded : (isMediumRisk ? Icons.error_outline_rounded : Icons.verified_rounded),
                                  color: isHighRisk ? AppColors.danger : (isMediumRisk ? const Color(0xFF9A7517) : AppColors.tealDark),
                                  size: 30,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        riskLevel == 'Low' ? 'Normal Risk' : '$riskLevel Risk',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                          color: isHighRisk ? AppColors.danger : (isMediumRisk ? const Color(0xFF9A7517) : AppColors.tealDark),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'AI Model Confidence  $confidencePercent%',
                                        style: const TextStyle(color: AppColors.grey500, fontSize: 12.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
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
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../pair_watch_screen.dart';
import 'health_dashboard_screen.dart';
import 'live_monitoring_tab.dart';
import 'medicine_tab.dart';
import 'notifications_tab.dart';
import 'care_recipient_profile_screen.dart';

class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sample_uid';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.hasData && userSnap.data!.exists
            ? userSnap.data!.data() as Map<String, dynamic>
            : {};
        final userName = userData["name"] ?? "User";
        final firstName = userName.split(' ').first;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("watch_details")
              .where("uid", isEqualTo: uid)
              .snapshots(),
          builder: (context, watchSnap) {
            final watchDocs = watchSnap.hasData ? watchSnap.data!.docs : [];
            final watchData = watchDocs.isNotEmpty ? watchDocs.first.data() as Map<String, dynamic> : {};
            final isConnected = watchData["paired"] ?? false;
            final batteryPercent = watchData["battery_percentage"] ?? 0;
            final lastSyncTimestamp = watchData["last_sync"] as Timestamp?;
            final lastSync = lastSyncTimestamp?.toDate();

            return Container(
              color: AppColors.black,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: AppColors.black,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_greeting(), style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                                Text(
                                  'Welcome, $firstName',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showSosDialog(context),
                            icon: const Icon(Icons.sos_rounded, size: 28),
                            color: AppColors.danger,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.danger.withOpacity(0.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isConnected ? AppColors.teal.withOpacity(0.18) : AppColors.danger.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.watch_rounded,
                                  color: isConnected ? AppColors.teal : AppColors.danger, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isConnected ? 'Connected' : 'Disconnected',
                                    style: TextStyle(
                                      color: isConnected ? AppColors.teal : AppColors.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Battery $batteryPercent%  •  Last Sync ${_fmtTime(lastSync)}',
                                    style: TextStyle(color: AppColors.white.withOpacity(0.7), fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.05,
                      ),
                      delegate: SliverChildListDelegate([
                        DashboardCard(
                          icon: Icons.watch_rounded,
                          title: 'Pair Watch',
                          subtitle: 'Device status & battery',
                          backgroundColor: const Color(0xFF1A4D47),
                          accent: AppColors.teal,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairWatchScreen())),
                        ),
                        DashboardCard(
                          icon: Icons.favorite_rounded,
                          title: 'Health Dashboard',
                          subtitle: 'Overall status & AI insight',
                          backgroundColor: const Color(0xFF4D1A4A),
                          accent: AppColors.danger,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthDashboardScreen())),
                        ),
                        DashboardCard(
                          icon: Icons.show_chart_rounded,
                          title: 'Live Monitoring',
                          subtitle: 'Real-time HR & SpO₂',
                          backgroundColor: const Color(0xFF2D4D1A),
                          accent: const Color(0xFF7AC84D),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveMonitoringTab())),
                        ),
                        DashboardCard(
                          icon: Icons.medication_rounded,
                          title: 'Medicine Reminder',
                          subtitle: 'Today\'s schedule',
                          backgroundColor: const Color(0xFF4D3D1A),
                          accent: const Color(0xFFE0A93B),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineTab())),
                        ),
                        DashboardCard(
                          icon: Icons.notifications_rounded,
                          title: 'Notifications',
                          subtitle: 'Alerts & activity',
                          backgroundColor: const Color(0xFF4D1A2D),
                          accent: const Color(0xFFFF6B9D),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsTab())),
                        ),
                        DashboardCard(
                          icon: Icons.person_rounded,
                          title: 'Care Recipient',
                          subtitle: 'Patient profile',
                          backgroundColor: const Color(0xFF1A3D4D),
                          accent: const Color(0xFF4DBDE0),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CareRecipientProfileScreen())),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.sos_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Text('Send Emergency Alert?', style: TextStyle(color: AppColors.white)),
          ],
        ),
        content: const Text(
          'This will notify all emergency contacts and share the care recipient\'s current location and vitals.',
          style: TextStyle(color: AppColors.grey500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.grey500))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }
}

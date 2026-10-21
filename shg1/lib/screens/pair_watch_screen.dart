import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'home/home_shell.dart';

class PairWatchScreen extends StatefulWidget {
  const PairWatchScreen({super.key});

  @override
  State<PairWatchScreen> createState() => _PairWatchScreenState();
}

class _PairWatchScreenState extends State<PairWatchScreen> {
  bool _scanning = false;
  bool _connected = false;

  void _startScan() async {
    setState(() => _scanning = true);
    // TODO: integrate real QR scanner (e.g. mobile_scanner package) + BLE pairing
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection("watch_details").doc("SHG001").set({
          "uid": uid,
          "device_id": "SHG001",
          "battery_percentage": 100,
          "paired": true,
          "last_sync": Timestamp.now(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving watch details: $e");
      }
    }

    setState(() {
      _scanning = false;
      _connected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Pair Watch', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2A2A),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _connected ? AppColors.teal.withOpacity(0.4) : AppColors.grey600.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: _scanning
                            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                            : Icon(
                                _connected ? Icons.watch_rounded : Icons.qr_code_scanner_rounded,
                                size: 80,
                                color: _connected ? AppColors.teal : AppColors.grey500,
                              ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _connected
                            ? 'Connected Successfully'
                            : (_scanning ? 'Scanning for device…' : 'Scan the QR code on your watch'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (_connected)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2A2A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              _kv('Watch ID', AppData.instance.device?.id ?? 'WATCH001'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Status', style: TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600)),
                                  SizedBox(width: 8),
                                  Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 16),
                                  SizedBox(width: 4),
                                  Text('Connected', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_connected)
                ElevatedButton(
                  onPressed: _scanning ? null : _startScan,
                  child: Text(_scanning ? 'Scanning…' : 'Scan QR Code'),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeShell()),
                      (route) => false,
                    );
                  },
                  child: const Text('Continue to Dashboard'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$k  ', style: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.white)),
        ],
      );
}

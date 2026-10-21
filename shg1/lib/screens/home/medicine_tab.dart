import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/vitals_socket_service.dart';

class MedicineTab extends StatefulWidget {
  const MedicineTab({super.key});

  @override
  State<MedicineTab> createState() => _MedicineTabState();
}

class _MedicineTabState extends State<MedicineTab> {
  /// IDs removed by the server via Socket.IO (expired repeats).
  final Set<String> _expiredIds = {};

  @override
  void initState() {
    super.initState();
    VitalsSocketService.instance.reminderExpiredNotifier
        .addListener(_onRemindersExpired);
  }

  void _onRemindersExpired() {
    final ids = VitalsSocketService.instance.reminderExpiredNotifier.value;
    if (ids.isEmpty) return;
    setState(() => _expiredIds.addAll(ids));
    debugPrint('🗑️ [MedicineTab] Hiding expired reminders: $ids');
  }

  @override
  void dispose() {
    VitalsSocketService.instance.reminderExpiredNotifier
        .removeListener(_onRemindersExpired);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sample_uid';

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        title: const Text('Medicine Reminder', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.teal),
            onPressed: () => _showAddEditMedicineSheet(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medicine_reminders')
            .where('uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.danger),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Filter out reminders already expired via Socket.IO signal
          final visibleDocs =
              docs.where((d) => !_expiredIds.contains(d.id)).toList();

          if (visibleDocs.isEmpty) {
            return const Center(
              child: Text(
                'No medicines added yet',
                style: TextStyle(color: AppColors.grey500),
              ),
            );
          }

          final meds = visibleDocs.map((doc) => _mapDocToReminder(doc)).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: meds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _MedicineCard(
              med: meds[i],
              onDelete: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('medicine_reminders')
                      .doc(meds[i].id)
                      .delete();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete reminder: $e')),
                    );
                  }
                }
              },
              onEdit: () => _showAddEditMedicineSheet(context, meds[i]),
            ),
          );
        },
      ),
    );
  }

  MedicineReminder _mapDocToReminder(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String timeStr = '—';
    if (data['reminder_time'] is Timestamp) {
      final dateTime = (data['reminder_time'] as Timestamp).toDate();
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final minute = dateTime.minute.toString().padLeft(2, '0');
      timeStr = '$hour:$minute $ampm';
    } else if (data['reminder_time'] is String) {
      timeStr = data['reminder_time'];
    }

    DateTime? fromDate;
    if (data['repeat_from_date'] is Timestamp) {
      fromDate = (data['repeat_from_date'] as Timestamp).toDate();
    }

    DateTime? toDate;
    if (data['repeat_to_date'] is Timestamp) {
      toDate = (data['repeat_to_date'] as Timestamp).toDate();
    }

    return MedicineReminder(
      id: doc.id,
      name: data['medicine_name'] ?? '—',
      time: timeStr,
      label: data['reminder_label'] ?? 'Morning',
      taken: data['taken'] ?? false,
      repeatFromDate: fromDate,
      repeatToDate: toDate,
    );
  }

  void _showAddEditMedicineSheet(BuildContext context, [MedicineReminder? editMed]) {
    final isEdit = editMed != null;
    final nameCtrl = TextEditingController(text: isEdit ? editMed.name : '');

    TimeOfDay? selectedTime;
    if (isEdit) {
      try {
        final parts = editMed.time.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        if (parts[1].toLowerCase() == 'pm' && hour < 12) {
          hour += 12;
        } else if (parts[1].toLowerCase() == 'am' && hour == 12) {
          hour = 0;
        }
        selectedTime = TimeOfDay(hour: hour, minute: minute);
      } catch (_) {
        selectedTime = TimeOfDay.now();
      }
    }

    final timeCtrl = TextEditingController(
      text: isEdit ? editMed.time : '',
    );

    String selectedLabel = isEdit ? editMed.label : 'Morning';

    DateTime? fromDate = isEdit ? editMed.repeatFromDate : null;
    DateTime? toDate = isEdit ? editMed.repeatToDate : null;

    final fromDateCtrl = TextEditingController(
      text: fromDate != null ? "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}" : '',
    );

    final toDateCtrl = TextEditingController(
      text: toDate != null ? "${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}" : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Medicine' : 'Add Medicine',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white),
                  ),
                  const SizedBox(height: 16),

                  // Medicine Name Field
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Medicine Name',
                      labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.grey700)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Time Field (Opens Clock time picker)
                  TextField(
                    controller: timeCtrl,
                    readOnly: true,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Time',
                      labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600),
                      hintText: 'Tap to select time',
                      suffixIcon: const Icon(Icons.access_time_rounded, color: AppColors.grey500),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.grey700)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
                    ),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setSheetState(() {
                          selectedTime = pickedTime;
                          timeCtrl.text = pickedTime.format(context);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Label Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedLabel,
                    dropdownColor: AppColors.surfaceDark,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Label',
                      labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.grey700)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                      DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                      DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedLabel = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Repeat From Date Picker
                  TextField(
                    controller: fromDateCtrl,
                    readOnly: true,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Repeat From Date',
                      labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600),
                      hintText: 'Tap to select date',
                      suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.grey500),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.grey700)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: (fromDate != null && fromDate!.isAfter(today)) ? fromDate! : today,
                        firstDate: today,
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setSheetState(() {
                          fromDate = pickedDate;
                          fromDateCtrl.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Repeat To Date Picker
                  TextField(
                    controller: toDateCtrl,
                    readOnly: true,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Repeat To Date',
                      labelStyle: const TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w600),
                      hintText: 'Tap to select date',
                      suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.grey500),
                      filled: true,
                      fillColor: AppColors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.grey700)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.teal, width: 1.6)),
                    ),
                    onTap: () async {
                      final now2 = DateTime.now();
                      final today2 = DateTime(now2.year, now2.month, now2.day);
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: (toDate != null && toDate!.isAfter(today2)) ? toDate! : today2,
                        firstDate: today2,
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setSheetState(() {
                          toDate = pickedDate;
                          toDateCtrl.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final name = nameCtrl.text.trim();
                        final label = selectedLabel;

                        final finalTime = selectedTime ?? TimeOfDay.now();
                        final now = DateTime.now();
                        final reminderDateTime = DateTime(now.year, now.month, now.day, finalTime.hour, finalTime.minute);
                        final reminderTimestamp = Timestamp.fromDate(reminderDateTime);

                        final localFromDate = fromDate;
                        final fromTimestamp = localFromDate != null ? Timestamp.fromDate(localFromDate) : null;
                        
                        final localToDate = toDate;
                        final toTimestamp = localToDate != null ? Timestamp.fromDate(localToDate) : null;

                        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'sample_uid';

                        final dataMap = {
                          "uid": uid,
                          "medicine_name": name,
                          "reminder_time": reminderTimestamp,
                          "reminder_label": label,
                          "repeat_from_date": fromTimestamp,
                          "repeat_to_date": toTimestamp,
                        };

                        try {
                          final db = FirebaseFirestore.instance;
                          if (isEdit) {
                            await db.collection("medicine_reminders").doc(editMed.id).update(dataMap);
                          } else {
                            await db.collection("medicine_reminders").add({
                              ...dataMap,
                              "taken": false,
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error saving reminder: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isEdit ? 'Update' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineReminder med;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MedicineCard({
    required this.med,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final labelLower = med.label.toLowerCase();
    late final Color cardBg;
    late final Color accentColor;

    if (labelLower.contains('morning')) {
      cardBg = const Color(0xFF14222E); // Deep Blue
      accentColor = const Color(0xFF2196F3); // Blue
    } else if (labelLower.contains('afternoon')) {
      cardBg = const Color(0xFF2A2015); // Deep Amber
      accentColor = const Color(0xFFFF9800); // Amber
    } else if (labelLower.contains('evening') || labelLower.contains('night')) {
      cardBg = const Color(0xFF24152A); // Deep Purple
      accentColor = const Color(0xFF9C27B0); // Purple
    } else {
      cardBg = AppColors.surfaceDark;
      accentColor = AppColors.teal;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medication_rounded, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${med.label}  •  ${med.time}',
                  style: const TextStyle(color: AppColors.grey500, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  med.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.white),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey500),
            onSelected: (v) {
              if (v == 'delete') {
                onDelete();
              } else if (v == 'edit') {
                onEdit();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'pair_watch_screen.dart';

class CreateCareRecipientScreen extends StatefulWidget {
  final bool isEdit;
  const CreateCareRecipientScreen({super.key, this.isEdit = false});

  @override
  State<CreateCareRecipientScreen> createState() => _CreateCareRecipientScreenState();
}

class _CreateCareRecipientScreenState extends State<CreateCareRecipientScreen> {
  int _currentStep = 0;
  int _contactCount = 2; // Initial contact fields count

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    try {
      // 1. Load Care Recipient details
      final recipientDoc = await db.collection("care_recipient_details").doc(uid).get();
      if (recipientDoc.exists) {
        final data = recipientDoc.data()!;
        setState(() {
          _fullNameController.text = data["patient_name"] ?? "";
          _ageController.text = (data["age"] ?? "").toString();
          _selectedGender = data["gender"];
          _selectedBloodGroup = data["blood_group"];
          _heightController.text = (data["height"] ?? "").toString();
          _weightController.text = (data["weight"] ?? "").toString();

          final conditions = List<String>.from(data["medical_conditions"] ?? []);
          for (var c in conditions) {
            if (_medicalConditions.containsKey(c)) {
              _medicalConditions[c] = true;
            }
          }

          final allergies = List<String>.from(data["allergies"] ?? []);
          if (allergies.isNotEmpty) {
            _hasAllergy = allergies.contains("Yes") || allergies.contains("Dust");
          }
        });
      }

      // 2. Load Doctor details
      final doctorDoc = await db.collection("doctor_details").doc(uid).get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data()!;
        setState(() {
          _doctorNameController.text = data["doctor_name"] ?? "";
          _doctorPhoneController.text = data["doctor_phone"] ?? "";
          _ambulanceController.text = data["ambulance_number"] ?? "";
        });
      }

      // 3. Load Emergency Contacts
      final contactsSnap = await db.collection("emergency_contacts").where("uid", isEqualTo: uid).get();
      if (contactsSnap.docs.isNotEmpty) {
        setState(() {
          _contactCount = contactsSnap.docs.length;

          // Recreate controllers
          _contactNameControllers.clear();
          _contactRelationControllers.clear();
          _contactPhoneControllers.clear();

          for (var doc in contactsSnap.docs) {
            final data = doc.data();
            _contactNameControllers.add(TextEditingController(text: data["contact_name"] ?? ""));
            _contactRelationControllers.add(TextEditingController(text: data["relationship"] ?? ""));
            _contactPhoneControllers.add(TextEditingController(text: data["contact_number"] ?? ""));
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading existing data: $e");
    }
  }

  // All steps now use the same blue/indigo color for consistent UI
  final Color _primaryBlue = const Color(0xFF5C6BC0);

  final List<String> _stepTitles = [
    'Personal Details',
    'Medical Details',
    'Contact Numbers',
  ];

  // Medical Conditions checkbox states
  final Map<String, bool> _medicalConditions = {
    'Hypertension': false,
    'Diabetes': false,
    'Asthma': false,
    'Heart Disease': false,
    'COPD': false,
    'Kidney Disease': false,
    'Other': false,
  };

  // HasAllergy selection (true = Yes, false = No)
  bool? _hasAllergy;

  // Selected values for dropdowns
  String? _selectedGender;
  String? _selectedBloodGroup;

  // Form field controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _doctorPhoneController = TextEditingController();
  final TextEditingController _ambulanceController = TextEditingController();

  final List<TextEditingController> _contactNameControllers = [TextEditingController(), TextEditingController()];
  final List<TextEditingController> _contactRelationControllers = [TextEditingController(), TextEditingController()];
  final List<TextEditingController> _contactPhoneControllers = [TextEditingController(), TextEditingController()];

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _doctorNameController.dispose();
    _doctorPhoneController.dispose();
    _ambulanceController.dispose();
    for (var c in _contactNameControllers) {
      c.dispose();
    }
    for (var c in _contactRelationControllers) {
      c.dispose();
    }
    for (var c in _contactPhoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: const Text(
          'Register Care Recipient',
          style: TextStyle(color: AppColors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Indicator Header (Dark theme style)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              color: AppColors.surfaceDark,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepItem(0, Icons.person_rounded),
                  _buildStepDivider(0),
                  _buildStepItem(1, Icons.medical_services_rounded),
                  _buildStepDivider(1),
                  _buildStepItem(2, Icons.contact_phone_rounded),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.grey700),
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActiveStepHeader(),
                    const SizedBox(height: 20),
                    _buildActiveStepContent(),
                    const SizedBox(height: 24),
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int stepIndex, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepCircle(stepIndex, icon),
        const SizedBox(height: 8),
        _buildStepLabel(stepIndex),
      ],
    );
  }

  Widget _buildStepCircle(int stepIndex, IconData icon) {
    final bool isActive = _currentStep == stepIndex;
    final bool isCompleted = _currentStep > stepIndex;
    final Color color = isCompleted ? _primaryBlue : (isActive ? _primaryBlue : AppColors.grey600);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : AppColors.black,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: isActive ? 2.5 : (isCompleted ? 2.0 : 1.5),
        ),
      ),
      child: Center(
        child: Icon(
          isCompleted ? Icons.check_rounded : icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStepDivider(int afterStep) {
    final bool isCompleted = _currentStep > afterStep;
    final Color color = isCompleted ? _primaryBlue : AppColors.grey700;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 20), // Align horizontal line with circles
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 3,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStepLabel(int stepIndex) {
    final bool isActive = _currentStep == stepIndex;
    final bool isCompleted = _currentStep > stepIndex;
    final Color color = isActive ? _primaryBlue : (isCompleted ? AppColors.white : AppColors.grey500);

    return SizedBox(
      width: 90,
      child: Text(
        _stepTitles[stepIndex],
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActiveStepHeader() {
    final String subtitle;
    if (_currentStep == 0) {
      subtitle = "Tell us about the person you're monitoring";
    } else if (_currentStep == 1) {
      subtitle = "Provide existing medical history for accurate tracking";
    } else {
      subtitle = "Add emergency and support contact information";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stepTitles[_currentStep],
          style: TextStyle(
            color: _primaryBlue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.grey300, fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActiveStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            _LabeledField('Full Name', hint: 'e.g. Margaret Carter', controller: _fullNameController),
            Row(children: [
              Expanded(child: _LabeledField('Age', hint: '74', keyboardType: TextInputType.number, controller: _ageController)),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdownField(
                  label: 'Gender',
                  hint: 'Select',
                  options: const ['Female', 'Male', 'Other'],
                  value: _selectedGender,
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val;
                    });
                  },
                ),
              ),
            ]),
            Row(children: [
              Expanded(
                child: _LabeledDropdownField(
                  label: 'Blood Group',
                  hint: 'Select',
                  options: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                  value: _selectedBloodGroup,
                  onChanged: (val) {
                    setState(() {
                      _selectedBloodGroup = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _LabeledField('Height (cm)', hint: '162', keyboardType: TextInputType.number, controller: _heightController)),
            ]),
            _LabeledField('Weight (kg)', hint: '68', keyboardType: TextInputType.number, controller: _weightController),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medical Conditions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey700),
              ),
              child: Column(
                children: _medicalConditions.keys.map((condition) {
                  return CheckboxListTile(
                    title: Text(
                      condition,
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w500),
                    ),
                    value: _medicalConditions[condition],
                    activeColor: AppColors.teal,
                    checkColor: AppColors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (bool? value) {
                      setState(() {
                        _medicalConditions[condition] = value ?? false;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Has Allergy',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _hasAllergy = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _hasAllergy == true
                            ? AppColors.teal.withOpacity(0.15)
                            : AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasAllergy == true ? AppColors.teal : AppColors.grey700,
                          width: _hasAllergy == true ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasAllergy == true
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: _hasAllergy == true ? AppColors.teal : AppColors.grey500,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Yes',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _hasAllergy = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _hasAllergy == false
                            ? AppColors.teal.withOpacity(0.15)
                            : AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasAllergy == false ? AppColors.teal : AppColors.grey700,
                          width: _hasAllergy == false ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasAllergy == false
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: _hasAllergy == false ? AppColors.teal : AppColors.grey500,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'No',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic contact fields list
            ...List.generate(
              _contactCount,
              (index) => _ContactBlock(
                number: index + 1,
                nameController: _contactNameControllers[index],
                relationshipController: _contactRelationControllers[index],
                phoneController: _contactPhoneControllers[index],
              ),
            ),
            // Add Contact Button
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _contactCount++;
                    _contactNameControllers.add(TextEditingController());
                    _contactRelationControllers.add(TextEditingController());
                    _contactPhoneControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add More Contacts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  side: BorderSide(color: _primaryBlue.withOpacity(0.5), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSpecialContact(
              label: 'Doctor Number',
              hint: '+1 202 555 0199',
              icon: Icons.local_hospital_rounded,
              bgColor: AppColors.teal.withOpacity(0.15),
              iconColor: AppColors.teal,
              controller: _doctorPhoneController,
            ),
            _LabeledField('Doctor Name', hint: 'e.g. Dr. John Doe', controller: _doctorNameController),
            const SizedBox(height: 14),
            _buildSpecialContact(
              label: 'Ambulance Number',
              hint: '911',
              icon: Icons.emergency_rounded,
              bgColor: AppColors.danger.withOpacity(0.15),
              iconColor: AppColors.danger,
              controller: _ambulanceController,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSpecialContact({
    required String label,
    required String hint,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceDark,
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grey500),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: iconColor, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_fullNameController.text.trim().isEmpty) {
        _showValidationSnackBar('Please enter Full Name in Personal Details');
        return false;
      }
      if (_ageController.text.trim().isEmpty) {
        _showValidationSnackBar('Please enter Age in Personal Details');
        return false;
      }
    } else if (_currentStep == 2) {
      bool hasAtLeastOneContact = false;
      for (int i = 0; i < _contactCount; i++) {
        if (_contactPhoneControllers[i].text.trim().isNotEmpty) {
          hasAtLeastOneContact = true;
          break;
        }
      }
      if (!hasAtLeastOneContact && _doctorPhoneController.text.trim().isEmpty) {
        _showValidationSnackBar('Please enter at least one Emergency Contact Number or Doctor Number');
        return false;
      }
    }
    return true;
  }

  void _showValidationSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveData() async {
    if (!_validateCurrentStep()) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "SHG_USER_${DateTime.now().millisecondsSinceEpoch}";

    final medicalConditionsList = _medicalConditions.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final careRecipientMap = {
      "patient_name": _fullNameController.text.trim(),
      "age": int.tryParse(_ageController.text.trim()) ?? 0,
      "gender": _selectedGender ?? "Female",
      "blood_group": _selectedBloodGroup ?? "O+",
      "height": double.tryParse(_heightController.text.trim()) ?? 0.0,
      "weight": double.tryParse(_weightController.text.trim()) ?? 0.0,
      "medical_conditions": medicalConditionsList,
      "allergies": _hasAllergy == true ? ["Yes"] : ["No"],
      "uid": uid,
    };

    final doctorMap = {
      "doctor_name": _doctorNameController.text.trim(),
      "doctor_phone": _doctorPhoneController.text.trim(),
      "ambulance_number": _ambulanceController.text.trim(),
    };

    final List<Map<String, dynamic>> emergencyContactsList = [];
    for (int i = 0; i < _contactCount; i++) {
      final name = _contactNameControllers[i].text.trim();
      final phone = _contactPhoneControllers[i].text.trim();
      final relation = _contactRelationControllers[i].text.trim();

      if (name.isNotEmpty || phone.isNotEmpty || relation.isNotEmpty) {
        emergencyContactsList.add({
          "contact_name": name,
          "contact_number": phone,
          "relationship": relation,
          "uid": uid,
        });
      }
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool saved = false;

      // First attempt: Client-side Firestore SDK
      try {
        final db = FirebaseFirestore.instance;
        await db.collection("care_recipient_details").doc(uid).set(careRecipientMap);
        await db.collection("doctor_details").doc(uid).set(doctorMap);
        final contactsQuery = await db.collection("emergency_contacts").where("uid", isEqualTo: uid).get();
        for (var doc in contactsQuery.docs) {
          await doc.reference.delete();
        }
        for (var contact in emergencyContactsList) {
          await db.collection("emergency_contacts").add(contact);
        }
        saved = true;
      } catch (clientErr) {
        debugPrint("Client Firestore write failed, trying backend Admin SDK fallback: $clientErr");
      }

      // Fallback attempt: Node.js Backend API (Admin SDK bypasses client permissions)
      if (!saved) {
        final response = await http.post(
          Uri.parse("http://localhost:5000/api/save-care-recipient"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "uid": uid,
            "careRecipient": careRecipientMap,
            "doctor": doctorMap,
            "emergencyContacts": emergencyContactsList,
          }),
        );
        if (response.statusCode == 200) {
          saved = true;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loader
        if (saved) {
          if (widget.isEdit) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PairWatchScreen()),
            );
          }
        } else {
          _showValidationSnackBar('Failed to save details. Please check network connection.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loader
        _showValidationSnackBar('Failed to save details: $e');
      }
    }
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.grey600, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              if (!_validateCurrentStep()) return;
              if (_currentStep < 2) {
                setState(() {
                  _currentStep++;
                });
              } else {
                _saveData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(_currentStep < 2 ? 'Next' : 'Save Care Recipient'),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  const _LabeledField(this.label, {required this.hint, this.keyboardType, this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White font color for labels to stand out on black background
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.white)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceDark,
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grey500),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> options;
  final String? value;
  final ValueChanged<String?>? onChanged;

  const _LabeledDropdownField({
    required this.label,
    required this.hint,
    required this.options,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            dropdownColor: AppColors.surfaceDark,
            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.grey500, size: 28),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceDark,
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grey500),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
              ),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ContactBlock extends StatelessWidget {
  final int number;
  final TextEditingController nameController;
  final TextEditingController relationshipController;
  final TextEditingController phoneController;

  const _ContactBlock({
    required this.number,
    required this.nameController,
    required this.relationshipController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    late final Color iconBg;
    late final Color iconColor;
    late final IconData iconData;

    if (number == 1) {
      iconBg = const Color(0xFF0FB6A6).withOpacity(0.15);
      iconColor = const Color(0xFF0FB6A6);
      iconData = Icons.account_circle_rounded;
    } else if (number == 2) {
      iconBg = const Color(0xFFE0A93B).withOpacity(0.15);
      iconColor = const Color(0xFFE0A93B);
      iconData = Icons.person_3_rounded;
    } else {
      iconBg = AppColors.grey700.withOpacity(0.3);
      iconColor = AppColors.grey300;
      iconData = Icons.person_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                'Contact $number',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LabeledField('Name', hint: 'Full name', controller: nameController),
          Row(
            children: [
              Expanded(child: _LabeledField('Relationship', hint: 'Son / Daughter...', controller: relationshipController)),
              const SizedBox(width: 12),
              Expanded(child: _LabeledField('Phone Number', hint: '+1 202 555 0110', keyboardType: TextInputType.phone, controller: phoneController)),
            ],
          ),
        ],
      ),
    );
  }
}

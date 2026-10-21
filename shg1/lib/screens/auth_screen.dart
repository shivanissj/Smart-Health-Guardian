import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'create_care_recipient_screen.dart';
import 'home/home_shell.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = true;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final db = FirebaseFirestore.instance;

      if (_isSignUp) {
        // Create user with Firebase Auth
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = credential.user?.uid;

        if (uid != null) {
          try {
            // Store user in database
            await db.collection("users").doc(uid).set({
              "name": name,
              "email": email,
              "created_at": Timestamp.now(),
            });
          } catch (dbError) {
            debugPrint("Firestore User Doc creation warning: $dbError");
          }
        }
      } else {
        // Sign In with Firebase Auth
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // Hide progress indicator & navigate
      if (mounted) {
        Navigator.of(context).pop();
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _isSignUp
                ? const CreateCareRecipientScreen(isEdit: false)
                : const HomeShell(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        String userMsg = e.message ?? 'Authentication error occurred.';
        if (e.code == 'email-already-in-use') {
          userMsg = 'This email is already registered. Please click "Sign In" below to log in.';
        } else if (e.code == 'weak-password') {
          userMsg = 'Password must be at least 6 characters long.';
        } else if (e.code == 'invalid-email') {
          userMsg = 'Please enter a valid email address.';
        } else if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          userMsg = 'Incorrect email or password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 380;
    final isLargeMobile = screenWidth >= 420;
    final padding = isSmallMobile ? 16.0 : (isMobile ? 20.0 : 48.0);
    final topPadding = isSmallMobile ? 12.0 : (isMobile ? 16.0 : 28.0);
    final iconSize = isSmallMobile ? 48.0 : (isMobile ? 64.0 : 72.0);
    final iconInnerSize = isSmallMobile ? 22.0 : (isMobile ? 30.0 : 36.0);
    final titleFontSize = isSmallMobile ? 24.0 : (isMobile ? 32.0 : 40.0);
    final subtitleFontSize = isSmallMobile ? 10.0 : 11.0;
    final headingFontSize = isSmallMobile ? 16.0 : (isLargeMobile ? 18.0 : 18.0);
    final headingSubFontSize = isSmallMobile ? 11.0 : 12.0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, topPadding, padding, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centered Header
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.favorite_rounded, color: AppColors.white, size: iconInnerSize),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Smart Health Guardian',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Health Monitoring & Alerts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.7),
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmallMobile ? 16 : 24),

                // Removed main heading and subtitle per request — tighten spacing
                SizedBox(height: isSmallMobile ? 12 : 18),

                if (_isSignUp) ...[
                  const _FieldLabel('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      hintText: 'John Doe',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      hintStyle: const TextStyle(fontSize: 13),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  SizedBox(height: isSmallMobile ? 12 : 14),
                ],

                 const _FieldLabel('Email'),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 13),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.white,
                    hintText: 'you@example.com',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    hintStyle: const TextStyle(fontSize: 13),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                SizedBox(height: isSmallMobile ? 12 : 14),

                 const _FieldLabel('Password'),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w600, fontSize: 13),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.white,
                    hintText: '••••••••',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    hintStyle: const TextStyle(fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.grey500, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                ),

                SizedBox(height: isSmallMobile ? 20 : 24),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 14)),
                ),
                SizedBox(height: isSmallMobile ? 12 : 16),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: AppColors.white.withOpacity(0.7), fontSize: isSmallMobile ? 12 : 13),
                      children: [
                        TextSpan(text: _isSignUp ? 'Already have an account?  ' : "Don't have an account?  "),
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Create Account',
                          style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700),
                          recognizer: (TapGestureRecognizer()
                            ..onTap = () => setState(() => _isSignUp = !_isSignUp)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final isSmallMobile = MediaQuery.of(context).size.width < 380;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmallMobile ? 14.0 : 15.0, color: AppColors.grey500)),
    );
  }
}

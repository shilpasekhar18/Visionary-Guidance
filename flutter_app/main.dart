import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visionary_guidance/signup.dart'; 
import 'package:visionary_guidance/login.dart';
import 'package:visionary_guidance/dash.dart';
import 'package:visionary_guidance/emergencydash.dart';
import 'firebase_options.dart';
void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visionary Guidance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _getInitialScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
  Widget _getInitialScreen() {
    // If user is logged in, go to dashboard, else show login page
    return FirebaseAuth.instance.currentUser != null ? ControlPanel() : LoginPage();
  }
}

// Add this function to your main.dart or wherever you want to show the popup
void showEmergencyLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return EmergencyLoginDialog();
    },
  );
}

// EmergencyLoginDialog widget
class EmergencyLoginDialog extends StatefulWidget {
  @override
  _EmergencyLoginDialogState createState() => _EmergencyLoginDialogState();
}

class _EmergencyLoginDialogState extends State<EmergencyLoginDialog> {
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  @override
  void dispose() {
    _deleteAnonymousUser();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _deleteAnonymousUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.isAnonymous) {
      await user.delete();
      print("🗑️ Anonymous user deleted on exit.");
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      print("✅ Signed in anonymously as: ${userCredential.user?.uid}");
    } catch (e) {
      print("❌ Anonymous Sign-in Failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Anonymous Sign-in Failed: ${e.toString()}")),
      );
    }
  }

  Future<void> _checkEmergencyAccess() async {
    setState(() {
      isLoading = true;
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      String phoneNumber = phoneController.text.trim();

      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a phone number")),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 🔍 Search directly in emergency_contacts collection
      QuerySnapshot contactsSnapshot = await _firestore
          .collectionGroup("emergency_contacts")
          .where("phone", isEqualTo: phoneNumber)
          .get();

      print("📌 Firestore Emergency Contacts Found: ${contactsSnapshot.docs.length}");

      if (contactsSnapshot.docs.isNotEmpty) {
        for (var contact in contactsSnapshot.docs) {
          print("✅ Emergency Contact Found: ${contact.data()}");
          
          // Get the user ID from the document path
          String trackedUserId = contact.reference.parent.parent?.id ?? "Unknown";

          // Close dialog and navigate to EmergencyViewPage
          Navigator.pop(context); // Close the dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyViewPage(trackedUserId: trackedUserId),
            ),
          );
          return;
        }
      }

      print("❌ ACCESS DENIED: No matching emergency contact found.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Access Denied: Not an emergency contact")),
      );
      setState(() {
        isLoading = false;
      });

    } catch (e) {
      print("🚨 ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Emergency Contact Login",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: "Enter Phone Number",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _checkEmergencyAccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text("Login",
                        style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/back.png'), // BACKGROUND IMAGE HERE
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark Overlay
          Container(
            color: Colors.black.withOpacity(00.3 ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top:360.0,left: 20.0,right: 20.0,bottom: 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  const Center(
                    child: Column(
                      children: [
                        Image(
                          image: AssetImage('assets/logo.png'),
                          width: 220,
                          height: 150,
                          color: Colors.white,
                        ),
                        // SizedBox(height: 10),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Login Buttons
                  _buildButton(
                    text: 'Continue with email',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                    onPressed: () {
                      Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const Login()),
                            );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    text: 'Emergency View',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                    onPressed: () => showEmergencyLoginDialog(context),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    text: 'Register',
                    backgroundColor: Colors.blue,
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPage()),
                            );
                    },
                  ),
                  const Spacer(),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Navigate to Privacy Policy
                          },
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () {
                            // Navigate to Terms of Service
                          },
                          child: const Text(
                            'Terms of service',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
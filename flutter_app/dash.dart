import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:visionary_guidance/login.dart';
import 'package:visionary_guidance/map.dart';
import 'package:visionary_guidance/twilio.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({Key? key}) : super(key: key);

  @override
  _ControlPanelState createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> with WidgetsBindingObserver {
  WebSocketChannel? channel;
  bool isConnected = false;
  bool speechEnabled = true;
  TextEditingController ipController = TextEditingController();
  String serverResponse = "No message received";
  final FlutterTts flutterTts = FlutterTts();
  String ip = "";
  Timer? _locationTimer;
  bool _firstLocationSent = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocationUpdates();
    _loadSavedIP(); // Load saved IP on startup
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      if (ip.isNotEmpty && !isConnected) {
        connectToServer(ip);
      }
    }
  }

  void _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("❌ Location permission denied");
      return;
    }

    if (!_firstLocationSent) {
      _firstLocationSent = true; // Mark first update as done
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _saveLocation(position.latitude, position.longitude);
    }

    _locationTimer?.cancel(); // Prevent multiple timers
    _locationTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _saveLocation(position.latitude, position.longitude);
    });
  }

  Future<void> _saveLocation(double lat, double lng) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("locations")
          .add({
        "latitude": lat,
        "longitude": lng,
        "timestamp": FieldValue.serverTimestamp(),
      });
      print("✅ Location stored: $lat, $lng");
    }
  }

  String formatPhoneNumber(String phone) {
    if (!phone.startsWith("+")) {
      return "+91$phone"; // Change +91 to your country code
    }
    return phone;
  }

  Future<void> _sendEmergencySMS() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // 🔹 Get Current Location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String locationUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      // 🔹 Fetch Emergency Contacts from Firebase
      QuerySnapshot contactsSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("emergency_contacts")
          .get();

      if (contactsSnapshot.docs.isEmpty) {
        print("❌ No emergency contacts found!");
        return;
      }

      TwilioService twilio = TwilioService();

      for (var doc in contactsSnapshot.docs) {
        String rawPhoneNumber = doc["phone"];
        String formattedPhone = formatPhoneNumber(rawPhoneNumber); // Convert to +E.164

        String message = "🚨 Emergency Alert! I need help. My location: $locationUrl";
        await twilio.sendSMS(formattedPhone, message);
      }

      print("✅ Emergency SMS sent to all contacts!");
      _speak('Emergency SMS sent ');
    } catch (e) {
      print("❌ Error sending SMS: $e");
    }
  }

  Future<void> _loadSavedIP() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString("saved_ip");
    if (savedIp != null) {
      setState(() {
        ip = savedIp;
        ipController.text = savedIp; // Prefill input field
      });
      
      // Auto-connect to saved IP if it exists
      if (ip.isNotEmpty) {
        connectToServer(ip);
      }
    }
  }

  Future<void> _saveIP(String ipAddress) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("saved_ip", ipAddress);
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    _cancelReconnectTimer();
    if (ip.isNotEmpty && mounted) {
      _reconnectTimer = Timer(Duration(seconds: 3), () {
        if (!isConnected && mounted) {
          print("🔄 Attempting to reconnect to $ip");
          connectToServer(ip);
        }
      });
    }
  }

  void connectToServer(String ip) {
    try {
      // Close any existing connection
      channel?.sink.close();
      
      setState(() {
        isConnected = false;
      });

      channel = WebSocketChannel.connect(Uri.parse('ws://$ip:8765'));
      print("🔌 Attempting connection to $ip");
      
      channel?.stream.listen(
        (message) {
          setState(() {
            serverResponse = message;
            if (message == "connected") {
              isConnected = true;
              _saveIP(ip);
              _cancelReconnectTimer();
              print("✅ Connected to server");
            }
          });
          _speak(serverResponse);
        },
        onError: (error) {
          print("❌ WebSocket error: $error");
          setState(() => isConnected = false);
          _scheduleReconnect();
        },
        onDone: () {
          print("🔌 WebSocket connection closed");
          setState(() => isConnected = false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print("❌ Connection attempt failed: $e");
      setState(() => isConnected = false);
      _scheduleReconnect();
    }
  }

  void sendMessage(String command) {
    if (isConnected && channel != null) {
      try {
        channel!.sink.add(command);
        _speak('$command command sent');
      } catch (e) {
        print("❌ Error sending message: $e");
        setState(() => isConnected = false);
        _scheduleReconnect();
      }
    } else if (!isConnected && ip.isNotEmpty) {
      // Try to reconnect if not connected but we have an IP
      connectToServer(ip);
      // Queue the message to be sent after connection
      Future.delayed(Duration(seconds: 2), () {
        if (isConnected && channel != null) {
          channel!.sink.add(command);
          _speak('$command command sent');
        } else {
          _speak('Not connected. Please try again.');
        }
      });
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Logout", style: TextStyle(color: Colors.white)),
          content: const Text("Are you sure you want to log out?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => _speak('long press to cancel'),
              onLongPress: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => _speak('long press to logout'),
              onLongPress: () async{
                Navigator.pop(context);
                _speak("Logged out");
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Login()),
                );
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showContactDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Add Emergency Contact", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Contact Name',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],  // Dark background color
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white24), // Thin white border
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue), // Highlight when focused
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _speak('long press to cancel'),
              onLongPress: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => _speak('long press to add contact'),
              onLongPress: () async{
                await FirebaseFirestore.instance.collection("users")
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection("emergency_contacts")
                    .add({
                  "name" : nameController.text.trim(),
                  "phone": phoneController.text.trim(),
                  "timestamp": FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                _speak("Added contact");
              },
              child: const Text("Add", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _cancelReconnectTimer();
    _locationTimer?.cancel();
    channel?.sink.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.only(top: 150.0, bottom: 100.0),
                child: Image.asset(
                  'assets/logo.png',
                  height: 80,
                  width: 200,
                  color: Colors.white,
                ),
              ),

              // Connect Glasses Panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connect Glasses',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 300.0,
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isConnected?
                                Padding(
                                  padding: const EdgeInsets.all(16.0), 
                                  child:Center( 
                                    child: Text(
                                    'Connected to: $ip',
                                    style: const TextStyle(color: Colors.green, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  ),
                                )
                                  :
                               TextField(
                                controller: ipController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Enter your IP address',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 350,
                              child: ElevatedButton(
                                onPressed: isConnected ? null : () {
                                  connectToServer(ipController.text);
                                  ip = ipController.text;
                                  ipController.clear();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isConnected?Colors.green:  Colors.blue[700],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  isConnected ? 'Connected' : 'Connect',
                                  style: TextStyle(color: isConnected?Colors.green:Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Padding(
                        padding: const EdgeInsets.only(top:30.0),
                       child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/glassess.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons Grid
              Padding(
                padding: const EdgeInsets.only(top: 40.0, left: 20.0, right: 20.0, bottom: 5.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Quit',
                            command: 'Quit',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Run',
                            command: 'Run',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Map',
                            command: 'Map',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Stop',
                            command: 'Stop',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Alert Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: ()=> _speak("Alert"),
                    onLongPress: () => _sendEmergencySMS(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: Colors.blue[700],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () => _speak("Add Emergency Contact"),
              onLongPress: () {
                    _showContactDialog();
                  _speak('Add new contact');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () => _speak("Logout Button "),
              onLongPress: () {
                    _showLogoutDialog();
                  _speak("press logout to continue");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required String command}) {
    return SizedBox(
      height: 100,
      child: ElevatedButton(
        onPressed: () => _speak(label),
        onLongPress: () {
          sendMessage(command);
          if(label == 'Map'){
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => VoiceNavigationScreen())
            );
          }
          else if (label=='Quit'){
            isConnected = false;
          }
          else{
             _speak('$label command sent');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
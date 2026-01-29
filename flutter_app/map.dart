import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:visionary_guidance/dash.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      primaryColor: Colors.blueGrey[800],
      scaffoldBackgroundColor: Colors.blueGrey[900],
      colorScheme: ColorScheme.dark(
        primary: Colors.blue,
        secondary: Colors.lightBlueAccent,
      ),
    ),
    home: VoiceNavigationScreen(),
  ));
}

class VoiceNavigationScreen extends StatefulWidget {
  @override
  _VoiceNavigationScreenState createState() => _VoiceNavigationScreenState();
}

class _VoiceNavigationScreenState extends State<VoiceNavigationScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController mapController;
  stt.SpeechToText speech = stt.SpeechToText();
  FlutterTts flutterTts = FlutterTts();
  Location location = Location();
  LatLng? userLocation;
  LatLng? destination;
  Set<Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  bool _navigationStopped = false;
  bool _isListening = false;
  String lastInstruction = "";
  String googleMapsApiKey = "AIzaSyAUSRQTIwIcwBHRI9hoZgE35XzyQRRyMOg"; // Replace with your API key
  
  // Animation controller for the listen button
  late AnimationController _animationController;
  // ignore: unused_field
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
void initState() {
  super.initState();
  _getUserLocation();
  _trackUserLocation();
  
  // Initialize animation controller
  _animationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 800),
  );
  
  // Scale animation for the listen button
  _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),
  );
  
  // Pulse animation
  _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      _animationController.reverse();
    } else if (status == AnimationStatus.dismissed && _isListening) {
      _animationController.forward();
    }
  });
  
  // Initialize speech recognition
  _initSpeech();
}

Future<void> _initSpeech() async {
  try {
    speech = stt.SpeechToText();
    bool available = await speech.initialize(
      onError: (error) => print("Speech error: $error"),
      onStatus: (status) => print("Speech status: $status"),
    );
    print("Speech initialization result: $available");
    
    if (!available) {
      // Check permissions
      print("Checking speech recognition permissions...");
    }
  } catch (e) {
    print("Error initializing speech: $e");
  }
}
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData locData = await location.getLocation();
    setState(() {
      userLocation = LatLng(locData.latitude!, locData.longitude!);
    });
  }

  void _trackUserLocation() {
    location.onLocationChanged.listen((LocationData currentLocation) {
      LatLng newLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
      setState(() {
        userLocation = newLocation;
      });

      // Removed automatic camera movement
      // if (mapController != null) {
      //   mapController.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 16));
      // }

      if (destination != null) {
        _checkForTurnInstruction(newLocation);
      }
    });
  }

  Future<void> _speak(String text) async {
    await flutterTts.setSharedInstance(true);
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    if (Platform.isIOS) {
      await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
      );
    }
    if (!_navigationStopped) {
      await flutterTts.speak(text);
    }
  }

  Future<void> _startListening() async {
    
  bool available = await speech.initialize();
  if (available) {
    setState(() {
      _isListening = true;
    });
    
    // Start the animation when listening begins
    _animationController.forward();
    
    // Add debug output to check if initialize succeeded
    print("Speech recognition initialized successfully");
    
    try {
      await speech.listen(
        onResult: (result) {
          print("Speech result received: ${result.recognizedWords}");
          if (result.finalResult) {
            setState(() {
              _isListening = false;
            });
            
            // Stop the animation when speech recognition is complete
            _animationController.reset();
            
            String recognizedText = result.recognizedWords.trim().toLowerCase();
            recognizedText = recognizedText.replaceAll("navigate to", "").trim();
            if (recognizedText.isNotEmpty) {
              _getDirections(recognizedText);
            }
          }
        },
        listenFor: Duration(seconds: 6),
        pauseFor: Duration(seconds: 2),
        partialResults: true, // Change to true to see intermediate results
        onSoundLevelChange: (level) {
          // Print sound level for debugging
          print("Sound level: $level");
        },
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print("Error during speech recognition: $e");
      setState(() {
        _isListening = false;
      });
      _animationController.reset();
      // Provide user feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Speech recognition error: $e")),
      );
    }
  } else {
    print("Speech recognition not available");
    // Provide user feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Speech recognition is not available on this device")),
    );
  }
}
  
  Future<void> _getDirections(String destinationQuery) async {
    String geocodeUrl =
        "https://maps.googleapis.com/maps/api/geocode/json?address=$destinationQuery&key=$googleMapsApiKey";
    final geocodeResponse = await http.get(Uri.parse(geocodeUrl));
    final geocodeData = json.decode(geocodeResponse.body);

    if (geocodeData["status"] == "OK") {
      double lat = geocodeData["results"][0]["geometry"]["location"]["lat"];
      double lng = geocodeData["results"][0]["geometry"]["location"]["lng"];

      setState(() {
        destination = LatLng(lat, lng);
        polylineCoordinates.clear();
        polylines.clear();
        _navigationStopped = false;
        lastInstruction = "";
      });

      // Announce the destination AFTER confirming the location is valid
      _speak("Navigating to $destinationQuery");
      
      // Fetch route after confirmation
      _getRoute();
    } else {
      _speak("Sorry, I couldn't find that location. Please try again.");
    }
  }

  void _stopNavigation() {
    setState(() {
      polylines.clear();
      polylineCoordinates.clear();
      destination = null;
      _navigationStopped = true;
      lastInstruction = "";
      _isListening = false;
    });

    _animationController.reset();
    flutterTts.stop().then((_) async {
      await Future.delayed(Duration(seconds: 1)); // Short delay to reset TTS
      _speak("Navigation stopped.");
    });
  }

  Future<void> _getRoute() async {
  if (destination == null || userLocation == null) return;

  String routesUrl = "https://routes.googleapis.com/directions/v2:computeRoutes";

  final response = await http.post(
    Uri.parse(routesUrl),
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": googleMapsApiKey,  // Use the API key as a header
      "X-Goog-FieldMask": "routes.polyline.encodedPolyline"  // Get only the polyline
    },
    body: jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": userLocation!.latitude,
            "longitude": userLocation!.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination!.latitude,
            "longitude": destination!.longitude
          }
        }
      },
      "travelMode": "WALK"
    }),
  );

  final data = json.decode(response.body);

  if (response.statusCode == 200 && data["routes"] != null) {
    _drawRoute(data["routes"][0]["polyline"]["encodedPolyline"]);
  } else {
    print("Error: ${data}");
    _speak("Failed to fetch route.");
  }
}

  void _drawRoute(String encodedPolyline) {
    List<PointLatLng> points = PolylinePoints().decodePolyline(encodedPolyline);
    setState(() {
      polylineCoordinates = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      polylines.clear();
      polylines.add(
        Polyline(
          polylineId: PolylineId("route"),
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        ),
      );
    });
  }

  String _determineTurnInstruction(int index) {
    if (index < 1 || index >= polylineCoordinates.length - 1) return "";

    LatLng prevPoint = polylineCoordinates[index - 1];
    LatLng currPoint = polylineCoordinates[index];
    LatLng nextPoint = polylineCoordinates[index + 1];

    double angle = _calculateAngle(prevPoint, currPoint, nextPoint);

    if (angle > 20) {
      return "Turn right";
    } else if (angle < -20) {
      return "Turn left";
    }
    return "";
  }

  double _calculateAngle(LatLng p1, LatLng p2, LatLng p3) {
    double dx1 = p2.longitude - p1.longitude;
    double dy1 = p2.latitude - p1.latitude;
    double dx2 = p3.longitude - p2.longitude;
    double dy2 = p3.latitude - p2.latitude;

    double angle1 = atan2(dy1, dx1);
    double angle2 = atan2(dy2, dx2);
    double angle = (angle2 - angle1) * (180 / pi);

    if (angle > 180) angle -= 360;
    if (angle < -180) angle += 360;

    return angle;
  }
  
  void _checkForTurnInstruction(LatLng currentLocation) {
    if (polylineCoordinates.isEmpty) return;

    for (int i = 0; i < polylineCoordinates.length - 1; i++) {
      double distance = _calculateDistance(
        currentLocation.latitude, currentLocation.longitude,
        polylineCoordinates[i].latitude, polylineCoordinates[i].longitude
      );

      if (distance < 30) {
        String instruction = _determineTurnInstruction(i);
        if (instruction.isNotEmpty && instruction != lastInstruction) {
          lastInstruction = instruction;
          _speak(instruction);
        }
        break;
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000;
    return R * acos(cos(lat1) * cos(lat2) * cos(lon2 - lon1) + sin(lat1) * sin(lat2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Voice Navigation",
        style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          userLocation == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                    // Apply night mode style to map
                    controller.setMapStyle('''
                    [
                      {
                        "elementType": "geometry",
                        "stylers": [{"color": "#242f3e"}]
                      },
                      {
                        "elementType": "labels.text.fill",
                        "stylers": [{"color": "#746855"}]
                      },
                      {
                        "elementType": "labels.text.stroke",
                        "stylers": [{"color": "#242f3e"}]
                      },
                      {
                        "featureType": "road",
                        "elementType": "geometry",
                        "stylers": [{"color": "#38414e"}]
                      },
                      {
                        "featureType": "road",
                        "elementType": "geometry.stroke",
                        "stylers": [{"color": "#212a37"}]
                      },
                      {
                        "featureType": "water",
                        "elementType": "geometry",
                        "stylers": [{"color": "#17263c"}]
                      }
                    ]
                    ''');
                  },
                  initialCameraPosition: CameraPosition(
                    target: userLocation ?? LatLng(0, 0),
                    zoom: 14,
                  ),
                  markers: {
                    if (userLocation != null)
                      Marker(markerId: MarkerId("user"), position: userLocation!),
                    if (destination != null)
                      Marker(markerId: MarkerId("destination"), position: destination!),
                  },
                  polylines: polylines,
                ),
                Positioned(
            bottom: 190,
            left: 50,
            right: 50,
            child: FloatingActionButton(
              backgroundColor: Colors.grey,
              onPressed: () {
                  Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ControlPanel()),
                 );
              },
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            right: 50,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: FloatingActionButton(
                    onPressed: _startListening,
                    backgroundColor: _isListening ? Colors.red : Colors.blue,
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 120,
            left: 50,
            right: 50,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: _stopNavigation,
              child: Icon(Icons.stop, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
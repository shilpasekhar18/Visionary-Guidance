import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visionary_guidance/login.dart';

class EmergencyViewPage extends StatefulWidget {
  final String trackedUserId;
  
  const EmergencyViewPage({super.key, required this.trackedUserId});

  @override
  _EmergencyViewPageState createState() => _EmergencyViewPageState();
}

class _EmergencyViewPageState extends State<EmergencyViewPage> {
  List<Map<String, dynamic>> locations = [];
  String userName = "Loading...";
  bool isLoading = true;
  bool showAllLocations = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.trackedUserId)
          .get();

      setState(() {
        userName = userDoc.exists ? (userDoc["name"] ?? "Unknown User") : "User Not Found";
      });
    } catch (e) {
      print("❌ Error fetching user name: $e");
      setState(() {
        userName = "Error Loading Name";
      });
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      Query locationsQuery = FirebaseFirestore.instance
          .collection("users")
          .doc(widget.trackedUserId)
          .collection("locations")
          .orderBy("timestamp", descending: true);
          
      if (!showAllLocations) {
        locationsQuery = locationsQuery.limit(5);
      }
      
      final snapshot = await locationsQuery.get();

      setState(() {
        locations = snapshot.docs.map((doc) => {
          "id": doc.id,
          "latitude": doc["latitude"],
          "longitude": doc["longitude"],
          "timestamp": doc["timestamp"]?.toDate(),
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading locations: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleLocationDisplay() {
    setState(() {
      showAllLocations = !showAllLocations;
    });
    _loadLocations();
  }

  void _openMap(double latitude, double longitude) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(latitude: latitude, longitude: longitude),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => Login()),
      (route) => false,
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 50,
                        height: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Row(
                    children: [
                      _buildIconButton(
                        icon: showAllLocations ? Icons.filter_list : Icons.list_alt,
                        onTap: _toggleLocationDisplay,
                      ),
                      _buildIconButton(
                        icon: Icons.logout_outlined,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content area
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    showAllLocations ? "(All Locations)" : "(Recent 5)",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Locations list
                              Flexible(
                                child: locations.isEmpty
                                    ? const Center(child: Text("No locations found", style: TextStyle(color: Colors.white)))
                                    : ListView.separated(
                                        physics: const BouncingScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: locations.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          final loc = locations[index];
                                          return _buildLocationEntry(
                                            "Location ${index + 1}",
                                            _getTimeAgo(loc["timestamp"]),
                                            () => _openMap(loc["latitude"], loc["longitude"]),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            
            // Footer
            const Padding(
              padding: EdgeInsets.only(bottom: 24.0, top: 16.0),
              child: Text(
                'VISIONARY GUIDANCE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildLocationEntry(String locationName, String timeAgo, VoidCallback onMapTap) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.deepOrange[900],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onMapTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class MapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;

  const MapScreen({Key? key, required this.latitude, required this.longitude}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Location Map", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(latitude, longitude), zoom: 15),
        markers: {
          Marker(
            markerId: const MarkerId("selected_location"),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(title: "Selected Location"),
          ),
        },
      ),
    );
  }
}
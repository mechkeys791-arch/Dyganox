import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EVChargingPage extends StatelessWidget {
  const EVChargingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to EV Charging',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF706DC7),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EVChargingScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF706DC7),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Search for nearest charging provider',
                  style: GoogleFonts.outfit(
                    fontSize: 18, 
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EVProviderScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF706DC7)),
                  ),
                ),
                child: Text(
                  'Want to share charge and earn?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    color: const Color(0xFF706DC7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EVProviderScreen extends StatefulWidget {
  const EVProviderScreen({super.key});

  @override
  State<EVProviderScreen> createState() => _EVProviderScreenState();
}

class _EVProviderScreenState extends State<EVProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedChargerType;
  String? selectedAvailableHours;
  bool agreeToTerms = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    try {
      // Note: http dependency needed for this to work
      // Add to pubspec.yaml: http: ^1.1.0
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted successfully!")),
      );
      _formKey.currentState?.reset();
      setState(() {
        selectedChargerType = null;
        selectedAvailableHours = null;
        agreeToTerms = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF706DC7),
        title: Text(
          'Become a Provider',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
                color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
              _buildFormHeader(),
              const SizedBox(height: 24),
              _buildFormField('Full Name', controller: _nameController),
              const SizedBox(height: 16),
              _buildFormField(
                'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length < 10) {
                    return 'Enter valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Complete Address',
                controller: _addressController,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Charger Type',
                ['Type 1', 'Type 2', 'CCS', 'CHAdeMO', 'Tesla'],
                validator: (value) =>
                    value == null ? 'Please select charger type' : null,
                onChanged: (value) {
                  setState(() {
                    selectedChargerType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Charging Rate (₹/kWh)',
                controller: _rateController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter charging rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Available Hours',
                ['9AM-10AM', '4PM-8PM', '6PM-10PM', '24/7'],
                validator: (value) =>
                    value == null ? 'Please select available hours' : null,
                onChanged: (value) {
                  setState(() {
                    selectedAvailableHours = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildEarningInfo(),
              const SizedBox(height: 24),
              _buildAgreementCheckbox(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
                              const SizedBox(height: 8),
              Center(
                                child: Text(
                  'Applications are reviewed within 24-48 hours of submission',
                                  style: GoogleFonts.outfit(
                    color: Colors.grey, 
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 50, color: Color(0xFF706DC7)),
          const SizedBox(height: 16),
          Text(
            'Start earning with your EV charger',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share your home charger and earn money while helping the EV community',
            style: GoogleFonts.outfit(
              fontSize: 14, 
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
                        ),
                      ],
                    ),
    );
  }

  Widget _buildFormField(
    String label, {
    TextEditingController? controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> options, {
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
            )),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: options
              .map((value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildEarningInfo() {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
        color: const Color(0xFF706DC7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
            border: Border.all(
          color: const Color(0xFF706DC7).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
          const Icon(Icons.attach_money, color: Color(0xFF706DC7), size: 24),
          const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Earning Potential',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF706DC7))),
                    const SizedBox(height: 4),
                    Text(
                  'Average providers earn ₹3000 to ₹7000 per month by sharing their chargers 4-6 hours daily',
                  style: GoogleFonts.outfit(
                    fontSize: 14, 
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementCheckbox() {
    return Row(
                      children: [
        Checkbox(
          value: agreeToTerms,
          onChanged: (value) {
            setState(() {
              agreeToTerms = value ?? false;
            });
          },
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Provider Guidelines',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                          ),
                        ),
                      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
                onPressed: () {
          if (_formKey.currentState!.validate() && agreeToTerms) {
            _submitForm();
          } else if (!agreeToTerms) {
                  ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please agree to terms and conditions'),
              ),
            );
          }
                },
                style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF706DC7),
          padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
          'Submit Application',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
              fontWeight: FontWeight.bold, 
              fontSize: 16,
          ),
        ),
      ),
    );
  }
  }

class EVChargingScreen extends StatefulWidget {
  const EVChargingScreen({super.key});

  @override
  State<EVChargingScreen> createState() => _EVChargingScreenState();
}

class _EVChargingScreenState extends State<EVChargingScreen> {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(12.9716, 77.5946);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _chargingStations = [];
  bool _showMap = false;
  String _locationMessage = '';

  final List<Map<String, dynamic>> _allStations = [
    {
      "name": "Ravi's home charging",
      "rating": 4.5,
      "distance": 0.4,
      "availableTime": "Available 24/7",
      "capacity": "7KW",
      "price": "₹8/KWh",
      "latitude": 12.9716,
      "longitude": 77.5946,
    },
    {
      "name": "Green Society Hub",
      "rating": 4.2,
      "distance": 0.8,
      "availableTime": "6AM - 11PM",
      "capacity": "10KW",
      "price": "₹10/KWh",
      "latitude": 12.9756,
      "longitude": 77.5956,
    },
    {
      "name": "Express Charging Point",
      "rating": 4.7,
      "distance": 1.2,
      "availableTime": "7AM - 10PM",
      "capacity": "50KW",
      "price": "₹15/KWh",
      "latitude": 12.9686,
      "longitude": 77.5936,
    },
  ];

  @override
  void initState() {
    super.initState();
    _chargingStations = _allStations;
  }


  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = 'Location permissions are permanently denied';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _locationMessage = 'Location fetched successfully!';
        _updateDistances(position.latitude, position.longitude);
      });
    } catch (e) {
      setState(() {
        _locationMessage = 'Error getting location: $e';
      });
    }
  }

  void _updateDistances(double userLat, double userLng) {
    setState(() {
      _chargingStations = _allStations.map((station) {
        double distance = Geolocator.distanceBetween(
          userLat, userLng, station['latitude'], station['longitude']
        ) / 1000;
        return {...station, 'distance': double.parse(distance.toStringAsFixed(1))};
      }).toList();
      _chargingStations.sort((a, b) => a['distance'].compareTo(b['distance']));
    });
  }

  void _showDirections(LatLng destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine current location')));
      return;
    }

    // Directly show in-app map
    _showInAppMap(destination);
  }

  void _showInAppMap(LatLng destination) async {
    setState(() {
      _showMap = true;
      _center = destination;
      _markers.clear();
      _polylines.clear();
      
      // Add current location marker
      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
      
      // Add destination marker
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Charging Station'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
  }

  void _animateToMarkers() {
    if (mapController == null || _markers.isEmpty) return;
    
    try {
      // Calculate bounds to show all markers
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;
      
      for (Marker marker in _markers) {
        minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
        maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
        minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
        maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
      }
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      );
      
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('Error animating to markers: $e');
      // Fallback: just center on the first marker
      if (_markers.isNotEmpty) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(_markers.first.position),
        );
      }
    }
  }

  void _openGoogleMaps(LatLng destination) async {
    try {
      final String googleMapsUrl = 
          'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
      
      final Uri url = Uri.parse(googleMapsUrl);
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening Google Maps: $e')));
    }
  }

  void _searchStations(String query) {
    setState(() {
      _chargingStations = query.isEmpty 
          ? _allStations 
          : _allStations.where((station) => 
              station['name'].toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EV Charging Stations',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: const Color(0xFF706DC7),
      ),
      body: _showMap ? _buildMapView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search for charging stations...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchStations,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _getCurrentLocation,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE0DFF6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Color(0xFF706DC7)),
                    const SizedBox(width: 10),
                    Text(_locationMessage.isEmpty 
                        ? 'Use current location' 
                        : _locationMessage),
                  ],
                ),
              ),
            ),
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 10),
            Text(
              'Your location: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
              '${_currentPosition!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                'Nearby providers',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showMap = !_showMap;
                  });
                },
                icon: Icon(_showMap ? Icons.list : Icons.map),
                label: Text(_showMap ? 'List View' : 'Map View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF706DC7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sort by:'),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _chargingStations.sort((a, b) => a['distance'].compareTo(b['distance']));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text('Distance'),
                      Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              ),
              GestureDetector(
                    onTap: () {
                  setState(() {
                    _chargingStations.sort((a, b) => b['rating'].compareTo(a['rating']));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                  child: const Row(
                              children: [
                      Text('Rating'),
                      Icon(Icons.arrow_drop_down),
                    ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
          const SizedBox(height: 20),
          ..._chargingStations.map((station) => Column(
                              children: [
              _buildStationCard(station),
              const SizedBox(height: 15),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
                                  decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showDirections(LatLng(station['latitude'], station['longitude']));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
                                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                    Expanded(
                      child: Text(
                        station['name'],
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                                          Text(
                            station['rating'].toString(),
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                                      Row(
                                        children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                                          Text(
                      '${station['distance'].toStringAsFixed(1)} km away',
                                            style: GoogleFonts.outfit(
                        color: Colors.grey[600],
                        fontSize: 14,
                                            ),
                                          ),
                                        ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Available: ${station['availableTime']}',
                        style: GoogleFonts.outfit(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.flash_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Capacity: ${station['capacity']}',
                      style: GoogleFonts.outfit(
                        color: Colors.grey[600],
                        fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      station['price'],
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: const Color(0xFF706DC7),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingScreen(station: station),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF706DC7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                                  ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                child: Text(
                                  'Book Now',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                          fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Column(
      children: [
        // Map header
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showMap = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_back, color: const Color(0xFF706DC7), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.map, color: const Color(0xFF706DC7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Directions to Charging Station',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (_markers.length >= 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '2 locations',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                  // If we have markers, animate to show them
                  if (_markers.isNotEmpty) {
                    _animateToMarkers();
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: 14.0,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
                zoomControlsEnabled: true,
                compassEnabled: true,
                onTap: (LatLng position) {
                  // Handle map tap if needed
                },
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showMap = false;
                    });
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF706DC7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: const Color(0xFF706DC7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Find the destination marker and open Google Maps
                    if (_markers.isNotEmpty) {
                      for (Marker marker in _markers) {
                        if (marker.markerId.value == 'destination') {
                          _openGoogleMaps(marker.position);
                          break;
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BookingScreen extends StatelessWidget {
  final Map<String, dynamic> station;
  
  const BookingScreen({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Booking Details',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: const Color(0xFF706DC7),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station['name'],
                  style: GoogleFonts.outfit(
                fontSize: 24, 
                    fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text('Capacity: ${station['capacity']}'),
            Text('Price: ${station['price']}'),
            Text('Availability: ${station['availableTime']}'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final url = 'https://www.google.com/maps/dir/?api=1&destination=${station['latitude']},${station['longitude']}';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch maps')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF706DC7),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                'Get Directions',
                style: GoogleFonts.outfit(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
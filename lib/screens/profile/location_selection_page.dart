import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_picker_map_page.dart';
import 'addresses_page.dart';
import '../../services/user_profile_service.dart';
import '../../services/cognito_service.dart';
import '../../services/api_config.dart';

class LocationSelectionPage extends StatefulWidget {
  const LocationSelectionPage({super.key});

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _savedAddresses = [];
  List<Map<String, dynamic>> _recentSearches = [];
  String? _selectedAddressId;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _loadRecentSearches();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _loadSavedAddresses() async {
    try {
      // Get user email
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email == null) {
        print('⚠️ User not logged in, cannot load addresses');
        return;
      }

      // Load from database only
      final result = await UserProfileService.getUserAddresses(email);
      
      if (result['success'] == true && result['data'] != null) {
        final addresses = List<Map<String, dynamic>>.from(result['data']);
        // Normalize all IDs to strings to avoid type mismatches
        final normalizedAddresses = addresses.map((addr) {
          final normalized = Map<String, dynamic>.from(addr);
          if (normalized['id'] != null) {
            normalized['id'] = normalized['id'].toString();
          }
          return normalized;
        }).toList();
        
        if (!mounted) return;
        setState(() {
          _savedAddresses = normalizedAddresses;
          // Find selected address
          for (var addr in _savedAddresses) {
            if (addr['isSelected'] == true) {
              _selectedAddressId = addr['id']?.toString();
              break;
            }
          }
        });
        print('✅ Loaded ${normalizedAddresses.length} addresses from database');
      } else {
        print('⚠️ Failed to load addresses: ${result['error']}');
        if (!mounted) return;
        setState(() {
          _savedAddresses = [];
        });
      }
    } catch (e) {
      print('❌ Error loading addresses from database: $e');
      if (!mounted) return;
      setState(() {
        _savedAddresses = [];
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? recentJson = prefs.getString('recent_location_searches');
      if (recentJson != null && mounted) {
        setState(() {
          _recentSearches = List<Map<String, dynamic>>.from(json.decode(recentJson));
        });
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(Map<String, dynamic> location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> recent = List.from(_recentSearches);
      
      // Remove if already exists
      recent.removeWhere((item) => item['id'] == location['id']);
      
      // Add to beginning
      recent.insert(0, location);
      
      // Keep only last 10
      if (recent.length > 10) {
        recent = recent.sublist(0, 10);
      }
      
      await prefs.setString('recent_location_searches', json.encode(recent));
      if (!mounted) return;
      setState(() {
        _recentSearches = recent;
      });
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  // Select address without popping back to previous page
  Future<void> _selectAddressWithoutPop(String addressId) async {
    try {
      // Get user email
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Find the address - handle both int and String IDs
      Map<String, dynamic>? selectedAddr;
      try {
        selectedAddr = _savedAddresses.firstWhere((a) {
          final aId = a['id'];
          return aId?.toString() == addressId.toString();
        });
      } catch (e) {
        print('⚠️ Address not found in local list, reloading from database...');
        await _loadSavedAddresses();
        
        try {
          selectedAddr = _savedAddresses.firstWhere((a) {
            final aId = a['id'];
            return aId?.toString() == addressId.toString();
          });
        } catch (e2) {
          print('❌ Address still not found after reload: $e2');
          return;
        }
      }

      // Update selection in database (tries PersonController, fallback to UserAddressController)
      final addrId = selectedAddr['id']?.toString() ?? addressId;
      final ok = await UserProfileService.selectUserAddress(email: email, addressId: addrId);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _selectedAddressId = addressId;
          for (var addr in _savedAddresses) {
            addr['isSelected'] = (addr['id']?.toString() == addressId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedAddr['label']} selected'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select address'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error selecting address: $e');
    }
  }

  Future<void> _selectAddress(String addressId) async {
    try {
      // Get user email
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Find the address - handle both int and String IDs
      Map<String, dynamic>? selectedAddr;
      try {
        selectedAddr = _savedAddresses.firstWhere((a) {
          final aId = a['id'];
          // Compare both as strings to handle int/String mismatch
          return aId?.toString() == addressId.toString();
        });
      } catch (e) {
        print('⚠️ Address not found in local list, reloading from database...');
        // Address might not be in local list yet, reload from database
        await _loadSavedAddresses();
        
        // Try again after reload
        try {
          selectedAddr = _savedAddresses.firstWhere((a) {
            final aId = a['id'];
            return aId?.toString() == addressId.toString();
          });
        } catch (e2) {
          print('❌ Address still not found after reload: $e2');
          // Don't show error if this is a newly saved address - just return
          // The address is saved, it will show up on next page load
          return;
        }
      }

      // Update selection in database (tries PersonController, fallback to UserAddressController)
      final addrId = selectedAddr['id']?.toString() ?? addressId;
      final ok = await UserProfileService.selectUserAddress(email: email, addressId: addrId);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _selectedAddressId = addressId;
          for (var addr in _savedAddresses) {
            addr['isSelected'] = (addr['id']?.toString() == addressId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedAddr['label']} selected'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select address'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error selecting address: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to map picker with current location
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      ),
    );

    if (result != null && mounted) {
      // Always reload addresses first to get the latest from database
      await _loadSavedAddresses();
      
      // Then select the address if it has an ID
      if (result['id'] != null) {
        // Small delay to ensure state is updated after reload
        await Future.delayed(const Duration(milliseconds: 500));
        // Select the address but stay on this page
        await _selectAddressWithoutPop(result['id'].toString());
      } else {
        // If no ID, just reload and stay on page to show the new address
        // The address will appear in the list
      }
    }
  }

  Future<void> _addNewAddress() async {
    // Navigate to map picker
    LatLng? initialPos;
    if (_currentPosition != null) {
      initialPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: initialPos,
        ),
      ),
    );

    if (result != null && mounted) {
      // Always reload addresses first to get the latest from database
      await _loadSavedAddresses();
      
      // Then select the newly created address if it has an ID
      if (result['id'] != null) {
        // Small delay to ensure state is updated after reload
        await Future.delayed(const Duration(milliseconds: 500));
        // Select the address but stay on this page
        await _selectAddressWithoutPop(result['id'].toString());
      } else {
        // If no ID, just reload and stay on page to show the new address
        // The address will appear in the list
      }
    }
  }


  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Select Your Location',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search an area or address',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),

            // Three Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.my_location,
                      title: 'Use Current Location',
                      onTap: _useCurrentLocation,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.add_location_alt,
                      title: 'Add New Address',
                      onTap: _addNewAddress,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Saved Addresses Section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_savedAddresses.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'SAVED ADDRESSES',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._savedAddresses.map((address) {
                        final addressId = address['id']?.toString() ?? '';
                        return _buildAddressCard(
                          address: address,
                          isSelected: addressId == _selectedAddressId,
                          onTap: () => _selectAddressWithoutPop(addressId),
                          onDelete: () => _deleteAddress(addressId),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],

                    // Recently Searched Section
                    if (_recentSearches.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'RECENTLY SEARCHED',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._recentSearches.map((location) => _buildRecentSearchCard(location)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      // Get user email
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Address'),
          content: const Text('Are you sure you want to delete this address?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Delete from database
      final result = await UserProfileService.deleteUserAddress(
        email: email,
        addressId: addressId,
      );

      if (result['success'] == true) {
        // Reload addresses
        await _loadSavedAddresses();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete address: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAddressCard({
    required Map<String, dynamic> address,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    double? distance;
    if (_currentPosition != null && address['latitude'] != null && address['longitude'] != null) {
      distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        address['latitude'],
        address['longitude'],
      );
    }

    IconData icon;
    if (address['type'] == 'work') {
      icon = Icons.work;
    } else if (address['type'] == 'other') {
      icon = Icons.location_on;
    } else {
      icon = Icons.home;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(icon, color: const Color(0xFF6366F1), size: 24),
                    if (distance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDistance(distance),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              address['label'] ?? 'Address',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'SELECTED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address['fullAddress'] ?? address['addressLine1'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.inter()),
                        ],
                      ),
                      onTap: () => Future.delayed(
                        const Duration(milliseconds: 100),
                        onDelete,
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

  Widget _buildRecentSearchCard(Map<String, dynamic> location) {
    double? distance;
    if (_currentPosition != null && location['latitude'] != null && location['longitude'] != null) {
      distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        location['latitude'],
        location['longitude'],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAddress(location['id']?.toString() ?? ''),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFF6366F1), size: 24),
                    if (distance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDistance(distance),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location['label'] ?? 'Location',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location['fullAddress'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

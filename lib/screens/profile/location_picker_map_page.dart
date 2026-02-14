import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/user_profile_service.dart';
import '../../services/cognito_service.dart';

class LocationPickerMapPage extends StatefulWidget {
  final LatLng? initialPosition;
  /// When true, used for mechanic shop: no label dialog, no user login/save.
  /// Just returns location data (fullAddress, city, state, pincode, country, latitude, longitude).
  final bool forMechanicShop;

  const LocationPickerMapPage({
    super.key,
    this.initialPosition,
    this.forMechanicShop = false,
  });

  @override
  State<LocationPickerMapPage> createState() => _LocationPickerMapPageState();
}

class _LocationPickerMapPageState extends State<LocationPickerMapPage> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(12.9716, 77.5946); // Default to Bangalore
  LatLng? _initialPosition;
  LatLng? _originalPosition;
  String _address = 'Loading address...';
  double _distanceFromOriginal = 0.0;
  bool _isLoadingAddress = false;
  bool _mapCreated = false;
  Set<Marker> _markers = {};
  String _addressLabel = '';
  
  // Address components extracted from geocoding
  String? _city;
  String? _pincode;
  String? _state;
  String? _country;
  String? _addressLine1;
  String? _addressLine2;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition!;
      _initialPosition = widget.initialPosition;
      _originalPosition = widget.initialPosition;
      _updateMarker(); // Initialize marker immediately
    } else {
      _getCurrentLocation();
    }
    _updateAddress();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _address = 'Location services disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _address = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _address = 'Location permission denied forever';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _initialPosition = _selectedPosition;
        _originalPosition = _selectedPosition;
      });

      _updateMarker(); // Update marker with new position

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedPosition, 16),
      );

      _updateAddress();
    } catch (e) {
      setState(() {
        _address = 'Error getting location: $e';
      });
    }
  }

  Future<void> _updateAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedPosition.latitude,
        _selectedPosition.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];

        // Extract address components from Placemark
        String? city = place.locality ?? place.subAdministrativeArea;
        String? pincode = place.postalCode;
        String? state = place.administrativeArea;
        String? country = place.country;
        
        // Build address line 1 (street/name)
        String? addressLine1;
        if (place.street != null && place.street!.isNotEmpty) {
          addressLine1 = place.street;
        } else if (place.name != null && place.name!.isNotEmpty) {
          addressLine1 = place.name;
        }
        
        // Build address line 2 (sub-locality/area)
        String? addressLine2;
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressLine2 = place.subLocality;
        } else if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
          addressLine2 = place.subThoroughfare;
        }

        // Build full address string for display
        if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }
        if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        String fullAddress = addressParts.join(', ');

        // Calculate distance from original position
        double distance = 0.0;
        if (_originalPosition != null) {
          distance = Geolocator.distanceBetween(
            _originalPosition!.latitude,
            _originalPosition!.longitude,
            _selectedPosition.latitude,
            _selectedPosition.longitude,
          );
        }

        setState(() {
          _address = fullAddress;
          _city = city;
          _pincode = pincode;
          _state = state;
          _country = country;
          _addressLine1 = addressLine1;
          _addressLine2 = addressLine2;
          _distanceFromOriginal = distance;
          _isLoadingAddress = false;
        });

        // Update marker
        _updateMarker();
      } else {
        setState(() {
          _address = 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Error: $e';
        _isLoadingAddress = false;
      });
    }
  }

  void _updateMarker() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedPosition,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onDrag: (LatLng newPosition) {
            // Update position without setState during drag to prevent blinking
            _selectedPosition = newPosition;
          },
          onDragEnd: (LatLng newPosition) {
            setState(() {
              _selectedPosition = newPosition;
              // Update marker to new position
              _markers = {
                Marker(
                  markerId: const MarkerId('selected_location'),
                  position: newPosition,
                  draggable: true,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  onDrag: (LatLng pos) {
                    _selectedPosition = pos;
                  },
                  onDragEnd: (LatLng pos) {
                    setState(() {
                      _selectedPosition = pos;
                    });
                    _updateAddress();
                  },
                ),
              };
            });
            // Center camera on new position
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(newPosition),
            );
            _updateAddress();
          },
        ),
      };
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
    _updateAddress();
  }

  Future<void> _confirmLocation() async {
    // Mechanic shop mode: no label, no login, no save — just return location data
    if (widget.forMechanicShop) {
      final locationData = {
        'fullAddress': _address,
        'addressLine1': _addressLine1,
        'addressLine2': _addressLine2,
        'city': _city,
        'pincode': _pincode,
        'state': _state,
        'country': _country,
        'latitude': _selectedPosition.latitude,
        'longitude': _selectedPosition.longitude,
      };
      if (mounted) {
        Navigator.pop(context, locationData);
      }
      return;
    }

    // User address mode: show label dialog and save to user profile
    final labelResult = await showDialog<String?>(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) => _buildLabelDialog(),
    );

    // If user cancelled the dialog, don't proceed
    if (labelResult == null || labelResult.isEmpty) {
      return; // Just return, don't close the page
    }

    _addressLabel = labelResult;

    // Get user email first
    final userData = await CognitoService.getCurrentUser();
    final email = userData['email'];
    
    if (email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in. Please login again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Create address object for database with all extracted components
    final addressData = {
      'label': _addressLabel,
      'fullAddress': _address,
      'addressLine1': _addressLine1,
      'addressLine2': _addressLine2,
      'city': _city,
      'pincode': _pincode,
      'state': _state,
      'country': _country,
      'latitude': _selectedPosition.latitude,
      'longitude': _selectedPosition.longitude,
      'type': 'other',
      'isSelected': false,
    };

    // Save to database ONLY - no local storage
    try {
      final saveResult = await UserProfileService.saveUserAddress(
        email: email,
        address: addressData,
      );
      
      if (saveResult['success'] == true) {
        print('✅ Address saved to database successfully');
        final savedAddress = saveResult['data'] as Map<String, dynamic>?;
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Address "${_addressLabel}" saved successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Small delay to show success message
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Return the saved address from database
          if (savedAddress != null) {
            Navigator.pop(context, savedAddress);
          } else {
            Navigator.pop(context, addressData);
          }
        }
      } else {
        // Database save failed - show error
        String errorMsg = 'Unknown error';
        if (saveResult.containsKey('error')) {
          final error = saveResult['error'];
          if (error is String) {
            errorMsg = error;
          } else if (error is Map) {
            errorMsg = error.toString();
          } else {
            errorMsg = error.toString();
          }
        }
        print('❌ Failed to save address to database: $errorMsg');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save address: ${errorMsg.contains('404') ? 'Backend endpoint not found. Please contact support.' : errorMsg}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception saving address to database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving address: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildLabelDialog() {
    final labelController = TextEditingController();
    
    return PopScope(
      canPop: false, // Prevent back button from closing
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.label,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Save Address',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Give this location a name',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                labelText: 'Label',
                hintText: 'e.g., Home, Work, College',
                prefixIcon: const Icon(Icons.edit_location_alt),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  // Use SchedulerBinding to avoid Navigator lock issues
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, value);
                    }
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Use SchedulerBinding to avoid Navigator lock issues
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, null);
                }
              });
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isNotEmpty) {
                // Use SchedulerBinding to avoid Navigator lock issues
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context, label);
                  }
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a label'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 16,
            ),
            onMapCreated: (GoogleMapController controller) async {
              _mapController = controller;
              _mapCreated = true;
              
              // Ensure map is properly initialized
              if (_initialPosition != null) {
                _selectedPosition = _initialPosition!;
                await controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_initialPosition!, 16),
                );
              } else {
                // If no initial position, use current selected position
                await controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedPosition, 16),
                );
              }
              
              // Update marker after camera is positioned
              _updateMarker();
            },
            onTap: _onMapTap,
            onCameraMove: (CameraPosition position) {
              // Update position silently without setState to prevent blinking
              _selectedPosition = position.target;
            },
            onCameraIdle: () {
              // Update marker and address when map stops moving
              setState(() {
                _markers = {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: _selectedPosition,
                    draggable: true,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    onDrag: (LatLng newPosition) {
                      // Update position during drag without setState
                      _selectedPosition = newPosition;
                    },
                    onDragEnd: (LatLng newPosition) {
                      setState(() {
                        _selectedPosition = newPosition;
                        // Update marker to new position
                        _markers = {
                          Marker(
                            markerId: const MarkerId('selected_location'),
                            position: newPosition,
                            draggable: true,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                            onDrag: (LatLng pos) {
                              _selectedPosition = pos;
                            },
                            onDragEnd: (LatLng pos) {
                              setState(() {
                                _selectedPosition = pos;
                              });
                              _updateAddress();
                            },
                          ),
                        };
                      });
                      // Center camera on dragged marker position
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(newPosition),
                      );
                      _updateAddress();
                    },
                  ),
                };
              });
              _updateAddress();
            },
            markers: {}, // Remove markers - using fixed center pin only
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
            liteModeEnabled: false, // Ensure full map mode
          ),

          // Top Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isLoadingAddress
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _address,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Pin (Fixed) - Shows where marker will be placed
          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFEF4444),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet with Address Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Address
                        Text(
                          _address,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),

                        // Distance indicator
                        if (_distanceFromOriginal > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _distanceFromOriginal > 1000
                                  ? const Color(0xFFFF6B35).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _distanceFromOriginal > 1000
                                    ? const Color(0xFFFF6B35)
                                    : const Color(0xFF10B981),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: _distanceFromOriginal > 1000
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _distanceFromOriginal < 1000
                                      ? '${_distanceFromOriginal.toStringAsFixed(0)} m from original location'
                                      : '${(_distanceFromOriginal / 1000).toStringAsFixed(2)} km from original location',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _distanceFromOriginal > 1000
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Confirm Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Confirm Location',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

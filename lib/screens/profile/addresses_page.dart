import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import '../../services/user_profile_service.dart';
import '../../services/cognito_service.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    // Always try database first - user_addresses table
    try {
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email != null && email.isNotEmpty) {
        final result = await UserProfileService.getUserAddresses(email);
        if (result['success'] == true && result['data'] != null) {
          final List<dynamic> dbAddresses = result['data'] is List
              ? result['data'] as List
              : [];
          final List<Map<String, dynamic>> parsed = [];
          for (final raw in dbAddresses) {
            if (raw is! Map) continue;
            final addr = Map<String, dynamic>.from(raw);
            parsed.add({
              'id': addr['id']?.toString(),
              'label': addr['label']?.toString() ?? '',
              'addressLine1': addr['addressLine1']?.toString() ?? addr['fullAddress']?.toString() ?? '',
              'addressLine2': addr['addressLine2']?.toString() ?? '',
              'city': addr['city']?.toString() ?? '',
              'pincode': addr['pincode']?.toString() ?? '',
              'type': addr['type']?.toString() ?? 'other',
              'fullAddress': addr['fullAddress']?.toString() ?? '',
              'latitude': addr['latitude'],
              'longitude': addr['longitude'],
              'isSelected': addr['isSelected'] == true,
            });
          }
          setState(() => _addresses = parsed);
          // Save to local storage for offline access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('addresses', json.encode(_addresses));
          return;
        }
      }
    } catch (e) {
      print('Error loading addresses from database: $e');
    }
    
    // Fallback to local storage only when database fails
    final prefs = await SharedPreferences.getInstance();
    final String? addressesJson = prefs.getString('addresses');
    if (addressesJson != null) {
      try {
        setState(() {
          _addresses = List<Map<String, dynamic>>.from(
            json.decode(addressesJson).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      } catch (_) {}
    }
  }

  Future<void> _saveAddresses() async {
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('addresses', json.encode(_addresses));
    
    // Save to database
    try {
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];
      
      if (email != null) {
        for (var address in _addresses) {
          await UserProfileService.saveUserAddress(
            email: email,
            address: address,
          );
        }
      }
    } catch (e) {
      print('Error saving addresses to database: $e');
    }
  }

  void _showAddEditAddressDialog({Map<String, dynamic>? address, int? index}) {
    final labelController = TextEditingController(text: address?['label'] ?? '');
    final addressLine1Controller = TextEditingController(text: address?['addressLine1'] ?? '');
    final addressLine2Controller = TextEditingController(text: address?['addressLine2'] ?? '');
    final cityController = TextEditingController(text: address?['city'] ?? '');
    final pincodeController = TextEditingController(text: address?['pincode'] ?? '');
    String selectedType = address?['type'] ?? 'home';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  address == null ? Icons.add : Icons.edit,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                address == null ? 'Add Address' : 'Edit Address',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Address Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Home')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g., My Home',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressLine1Controller,
                  decoration: InputDecoration(
                    labelText: 'Address Line 1',
                    hintText: 'House No., Building Name',
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressLine2Controller,
                  decoration: InputDecoration(
                    labelText: 'Address Line 2',
                    hintText: 'Street, Area',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    hintText: 'e.g., Mumbai',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pincodeController,
                  decoration: InputDecoration(
                    labelText: 'Pincode',
                    hintText: 'e.g., 400001',
                    prefixIcon: const Icon(Icons.pin),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.isNotEmpty &&
                    addressLine1Controller.text.isNotEmpty &&
                    cityController.text.isNotEmpty &&
                    pincodeController.text.isNotEmpty) {
                  
                  Navigator.pop(context);
                  
                  // Prepare address data - include all fields for user_addresses table
                  final addressData = <String, dynamic>{
                    'label': labelController.text,
                    'addressLine1': addressLine1Controller.text,
                    'addressLine2': addressLine2Controller.text,
                    'city': cityController.text,
                    'pincode': pincodeController.text,
                    'state': address?['state'] ?? '',
                    'country': address?['country'] ?? '',
                    'type': selectedType,
                    'fullAddress': '${addressLine1Controller.text}, ${addressLine2Controller.text.isNotEmpty ? addressLine2Controller.text + ", " : ""}${cityController.text}, ${pincodeController.text}',
                    'latitude': address?['latitude'],
                    'longitude': address?['longitude'],
                    'isSelected': false,
                  };
                  
                  // If updating, preserve the ID and other fields
                  if (index != null && _addresses[index]['id'] != null) {
                    addressData['id'] = _addresses[index]['id'];
                    addressData['latitude'] = _addresses[index]['latitude'];
                    addressData['longitude'] = _addresses[index]['longitude'];
                    addressData['isSelected'] = _addresses[index]['isSelected'] ?? false;
                  }
                  
                  // Save to database
                  try {
                    final userData = await CognitoService.getCurrentUser();
                    final email = userData['email'];
                    
                    if (email != null) {
                      final result = await UserProfileService.saveUserAddress(
                        email: email,
                        address: addressData,
                      );
                      
                      if (result['success'] == true) {
                        final savedAddress = result['data'];
                        
                        // Update local state
                        setState(() {
                          if (index != null) {
                            _addresses[index] = {
                              'id': savedAddress['id']?.toString() ?? _addresses[index]['id'],
                              'label': savedAddress['label'] ?? labelController.text,
                              'addressLine1': savedAddress['addressLine1'] ?? addressLine1Controller.text,
                              'addressLine2': savedAddress['addressLine2'] ?? addressLine2Controller.text,
                              'city': savedAddress['city'] ?? cityController.text,
                              'pincode': savedAddress['pincode'] ?? pincodeController.text,
                              'type': savedAddress['type'] ?? selectedType,
                              'fullAddress': savedAddress['fullAddress'] ?? addressData['fullAddress'],
                              'latitude': savedAddress['latitude'] ?? _addresses[index]['latitude'],
                              'longitude': savedAddress['longitude'] ?? _addresses[index]['longitude'],
                              'isSelected': savedAddress['isSelected'] ?? false,
                            };
                          } else {
                            _addresses.add({
                              'id': savedAddress['id']?.toString(),
                              'label': savedAddress['label'] ?? labelController.text,
                              'addressLine1': savedAddress['addressLine1'] ?? addressLine1Controller.text,
                              'addressLine2': savedAddress['addressLine2'] ?? addressLine2Controller.text,
                              'city': savedAddress['city'] ?? cityController.text,
                              'pincode': savedAddress['pincode'] ?? pincodeController.text,
                              'type': savedAddress['type'] ?? selectedType,
                              'fullAddress': savedAddress['fullAddress'] ?? addressData['fullAddress'],
                              'latitude': savedAddress['latitude'],
                              'longitude': savedAddress['longitude'],
                              'isSelected': savedAddress['isSelected'] ?? false,
                            });
                          }
                        });
                        
                        // Update local storage
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('addresses', json.encode(_addresses));
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                index != null ? 'Address updated successfully!' : 'Address saved successfully!',
                                style: GoogleFonts.inter(color: Colors.white)),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to save address: ${result['error'] ?? 'Unknown error'}',
                                style: GoogleFonts.inter(color: Colors.white)),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('User not logged in', style: GoogleFonts.inter(color: Colors.white)),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    print('Error saving address: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving address: $e', style: GoogleFonts.inter(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all required fields',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                address == null ? 'Add' : 'Update',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAddress(int index) async {
    if (index >= _addresses.length) return;
    
    final address = _addresses[index];
    final addressId = address['id'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Address', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this address?',
          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Delete from database
              try {
                final userData = await CognitoService.getCurrentUser();
                final email = userData['email'];
                
                if (email != null && addressId != null) {
                  final result = await UserProfileService.deleteUserAddress(
                    email: email,
                    addressId: addressId,
                  );
                  
                  if (result['success'] == true) {
                    // Remove from local state
                    setState(() {
                      _addresses.removeAt(index);
                    });
                    
                    // Update local storage
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('addresses', json.encode(_addresses));
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Address deleted successfully!', style: GoogleFonts.inter(color: Colors.white)),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete address: ${result['error'] ?? 'Unknown error'}', 
                            style: GoogleFonts.inter(color: Colors.white)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('User not logged in', style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              } catch (e) {
                print('Error deleting address: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting address: $e', style: GoogleFonts.inter(color: Colors.white)),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getAddressIcon(String type) {
    switch (type) {
      case 'work':
        return Icons.work;
      case 'other':
        return Icons.location_on;
      default:
        return Icons.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
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
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Addresses',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Addresses Saved',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first address to get started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _addresses.length,
              itemBuilder: (context, index) {
                final address = _addresses[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getAddressIcon(address['type']),
                        color: const Color(0xFF6366F1),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      address['label'],
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          address['addressLine1'],
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        if ((address['addressLine2'] ?? '').toString().isNotEmpty)
                          Text(
                            address['addressLine2'],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        Text(
                          '${address['city']} - ${address['pincode']}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF6366F1)),
                          onPressed: () => _showAddEditAddressDialog(address: address, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                          onPressed: () => _deleteAddress(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditAddressDialog(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Address',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}


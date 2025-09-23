import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'homepage.dart';

class VehicleSelectionPage extends StatefulWidget {
  const VehicleSelectionPage({super.key});

  @override
  State<VehicleSelectionPage> createState() => _VehicleSelectionPageState();
}

class _VehicleSelectionPageState extends State<VehicleSelectionPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  
  String _selectedVehicleType = '';
  String _selectedFuelType = '';
  bool _isLoading = false;
  int _currentStep = 0;
  
  // Responsive design variables
  late double screenWidth;
  late double screenHeight;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {
      'name': 'Car',
      'icon': Icons.directions_car,
      'color': const Color(0xFF706DC7),
    },
    {
      'name': 'Motorcycle',
      'icon': Icons.motorcycle,
      'color': const Color(0xFF706DC7),
    },
    {
      'name': 'Scooter',
      'icon': Icons.two_wheeler,
      'color': const Color(0xFF706DC7),
    },
    {
      'name': 'Bicycle',
      'icon': Icons.pedal_bike,
      'color': const Color(0xFF706DC7),
    },
  ];

  final List<String> _fuelTypes = [
    'Petrol',
    'Diesel',
    'Electric',
    'Hybrid',
    'CNG',
    'LPG',
  ];

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedVehicleType.isNotEmpty) {
      setState(() {
        _currentStep = 1;
      });
      HapticFeedback.lightImpact();
    } else if (_currentStep == 1 && _selectedFuelType.isNotEmpty) {
      setState(() {
        _currentStep = 2;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      HapticFeedback.lightImpact();
    }
  }


  Future<void> _completeSetup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
      // Simulate setup completion
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentStep == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentStep >= index
                ? const Color(0xFF6366F1)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildVehicleTypeCard(Map<String, dynamic> vehicle) {
    final isSelected = _selectedVehicleType == vehicle['name'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicleType = vehicle['name'];
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? vehicle['color'].withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? vehicle['color'] : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? vehicle['color'].withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 15 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected 
                    ? vehicle['color'].withValues(alpha: 0.2)
                    : vehicle['color'].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                vehicle['icon'],
                color: vehicle['color'],
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              vehicle['name'],
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? vehicle['color'] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypeChip(String fuelType) {
    final isSelected = _selectedFuelType == fuelType;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFuelType = fuelType;
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          fuelType,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFF706DC7),
                    size: 20,
                  ),
                ),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Hide keyboard when tapping outside input fields
            FocusScope.of(context).unfocus();
          },
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: screenWidth * 0.2,
                            height: screenWidth * 0.2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF706DC7), Color(0xFF8B7ED8), Color(0xFF706DC7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF706DC7).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: screenWidth * 0.1,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.025),
                        Text(
                          _currentStep == 0
                              ? 'Select Vehicle Type'
                              : _currentStep == 1
                                  ? 'Choose Fuel Type'
                                  : 'Vehicle Details',
                          style: GoogleFonts.outfit(
                            fontSize: screenWidth * 0.07,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        Text(
                          _currentStep == 0
                              ? 'What type of vehicle do you own?'
                              : _currentStep == 1
                                  ? 'What fuel does your vehicle use?'
                                  : 'Tell us more about your vehicle',
                          style: GoogleFonts.inter(
                            fontSize: screenWidth * 0.04,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Step Indicator
                  _buildStepIndicator(),
                  
                  const SizedBox(height: 40),
                  
                  // Step Content
                  Expanded(
                    child: _currentStep == 0
                        ? _buildVehicleTypeSelection()
                        : _currentStep == 1
                            ? _buildFuelTypeSelection()
                            : _buildVehicleDetailsForm(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation Buttons
                  Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _previousStep,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Text(
                                    'Previous',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      if (_currentStep > 0) const SizedBox(width: 16),
                      
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _currentStep < 2 ? _nextStep : _completeSetup,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _currentStep < 2 ? 'Next' : 'Complete Setup',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
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
      ),
        ),
    );
  }

  Widget _buildVehicleTypeSelection() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _vehicleTypes.length,
      itemBuilder: (context, index) {
        return _buildVehicleTypeCard(_vehicleTypes[index]);
      },
    );
  }

  Widget _buildFuelTypeSelection() {
    return SingleChildScrollView(
      child: Column(
        children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: _fuelTypes.map((fuelType) => _buildFuelTypeChip(fuelType)).toList(),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Don\'t worry! You can always change this information later in your profile settings.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildVehicleDetailsForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Vehicle Model
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _vehicleModelController,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Vehicle Model (e.g., Honda City, BMW X5)',
                labelStyle: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.directions_car,
                  color: Color(0xFF706DC7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your vehicle model';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Vehicle Year
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _vehicleYearController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Manufacturing Year',
                labelStyle: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF706DC7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the manufacturing year';
                }
                final year = int.tryParse(value);
                if (year == null || year < 1900 || year > DateTime.now().year) {
                  return 'Please enter a valid year';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // License Plate
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _licensePlateController,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'License Plate Number (Optional)',
                labelStyle: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.credit_card,
                  color: Color(0xFF706DC7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

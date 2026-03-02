import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vehicle_service.dart';
import '../../services/api_config.dart';

class AddEditVehiclePage extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic>? existingVehicle; // when editing

  const AddEditVehiclePage({
    super.key,
    required this.userEmail,
    this.existingVehicle,
  });

  @override
  State<AddEditVehiclePage> createState() => _AddEditVehiclePageState();
}

class _AddEditVehiclePageState extends State<AddEditVehiclePage> {
  int _step = 0;
  String _type = 'CAR';
  List<Map<String, dynamic>> _makes = [];
  List<Map<String, dynamic>> _models = [];
  bool _loadingMakes = false;
  bool _loadingModels = false;
  Map<String, dynamic>? _selectedMake;
  Map<String, dynamic>? _selectedModel;
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  String? _fuelType;
  bool _isDefault = false;
  bool _saving = false;

  static const List<String> _fuelTypesCar = ['Petrol', 'Diesel', 'Electric', 'CNG', 'Hybrid'];
  static const List<String> _fuelTypesBike = ['Petrol', 'Electric'];

  /// Indian plate: 2 letters (state) + 2 digits (district) + 1–3 letters + 1–4 digits. Spaces optional.
  static bool _isValidPlate(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length < 8) return false;
    return RegExp(r'^[A-Za-z]{2}\s*\d{1,2}\s*[A-Za-z]{1,3}\s*\d{1,4}$').hasMatch(t);
  }

  bool get _isEdit => widget.existingVehicle != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final v = widget.existingVehicle!;
      _type = (v['type'] ?? 'CAR').toString().toUpperCase();
      _plateController.text = (v['plateNumber'] ?? '').toString();
      _yearController.text = (v['year'] ?? '').toString();
      _fuelType = v['fuelType']?.toString();
      _isDefault = v['isDefault'] == true;
      _selectedMake = v['makeId'] != null
          ? {'id': v['makeId'], 'name': v['makeName'] ?? '', 'imageUrl': v['modelImageUrl']}
          : null;
      _selectedModel = v['modelId'] != null
          ? {'id': v['modelId'], 'name': v['modelName'] ?? '', 'imageUrl': v['modelImageUrl']}
          : null;
      _step = 2; // jump to details step when editing (make/model already set)
    } else {
      _loadMakes();
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadMakes() async {
    setState(() {
      _loadingMakes = true;
      _makes = [];
      _selectedMake = null;
      _models = [];
      _selectedModel = null;
    });
    final list = await VehicleService.getMakes(_type);
    if (mounted) setState(() { _makes = list; _loadingMakes = false; });
  }

  Future<void> _loadModels() async {
    if (_selectedMake == null) return;
    final makeId = _selectedMake!['id'];
    if (makeId is! int && makeId is! num) return;
    setState(() {
      _loadingModels = true;
      _models = [];
      _selectedModel = null;
    });
    final list = await VehicleService.getModels(makeId is int ? makeId : (makeId as num).toInt());
    if (mounted) setState(() { _models = list; _loadingModels = false; });
  }

  void _onTypeChange(String type) {
    setState(() {
      _type = type;
      _loadMakes();
    });
  }

  String _imageUrl(dynamic url) {
    if (url == null || url.toString().isEmpty) return '';
    final s = url.toString();
    if (s.startsWith('http')) return s;
    return '${ApiConfig.baseUrl}$s';
  }

  Future<void> _save() async {
    if (_isEdit) {
      final id = widget.existingVehicle!['id'];
      if (id == null) return;
      setState(() => _saving = true);
      final plate = _plateController.text.trim();
      if (plate.isEmpty || !_isValidPlate(plate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid plate number (e.g. MH 12 AB 1234)'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (_fuelType == null || _fuelType!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select fuel type'), backgroundColor: Colors.orange),
        );
        return;
      }
      final updated = await VehicleService.updateVehicle(
        id is int ? id : (id as num).toInt(),
        plateNumber: plate,
        year: _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
        fuelType: _fuelType,
        isDefault: _isDefault,
      );
      setState(() => _saving = false);
      if (updated != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
      return;
    }
    if (_selectedMake == null || _selectedModel == null) return;
    final plate = _plateController.text.trim();
    if (plate.isEmpty || !_isValidPlate(plate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plate number is required (e.g. MH 12 AB 1234)'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_fuelType == null || _fuelType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select fuel type'), backgroundColor: Colors.orange),
      );
      return;
    }
    final makeId = _selectedMake!['id'];
    final modelId = _selectedModel!['id'];
    if (makeId == null || modelId == null) return;
    setState(() => _saving = true);
    final created = await VehicleService.createVehicle(
      userEmail: widget.userEmail,
      type: _type,
      makeId: makeId is int ? makeId : (makeId as num).toInt(),
      modelId: modelId is int ? modelId : (modelId as num).toInt(),
      makeName: _selectedMake!['name']?.toString() ?? '',
      modelName: _selectedModel!['name']?.toString() ?? '',
      modelImageUrl: _selectedModel!['imageUrl']?.toString(),
      plateNumber: plate,
      year: _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
      fuelType: _fuelType,
      isDefault: _isDefault,
    );
    setState(() => _saving = false);
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (!_isEdit && _step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isEdit ? 'Edit Vehicle' : _stepTitle(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isEdit ? _buildDetailsStep() : _buildStepContent(),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return _buildTypeStep();
    }
    if (_step == 1) {
      return _buildMakeStep();
    }
    if (_step == 2) {
      return _buildModelStep();
    }
    return _buildDetailsStep();
  }

  String _stepTitle() {
    if (_step == 0) return 'Choose vehicle type';
    if (_step == 1) return _type == 'CAR' ? 'Car brands' : 'Bike brands';
    if (_step == 2) return 'Select model';
    return 'Vehicle details';
  }

  Widget _buildTypeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose vehicle type', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text('Cars and bikes are listed separately.', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _typeChip('CAR', Icons.directions_car)),
              const SizedBox(width: 16),
              Expanded(child: _typeChip('BIKE', Icons.two_wheeler)),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _typeChip(String type, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _onTypeChange(type);
          setState(() => _step = 1);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF6366F1) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: selected ? const Color(0xFF6366F1) : Colors.grey),
              const SizedBox(height: 6),
              Text(
                type,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF6366F1) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMakeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text('Choose manufacturer', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey)),
        ),
        Expanded(
          child: _loadingMakes
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _makes.length,
                  itemBuilder: (context, i) {
                    final m = _makes[i];
                    final id = m['id'];
                    final name = m['name']?.toString() ?? '';
                    final imageUrl = _imageUrl(m['imageUrl']);
                    final selected = _selectedMake != null && _selectedMake!['id'] == id;
                    return GestureDetector(
                      onTap: () async {
                        setState(() => _selectedMake = m);
                        await _loadModels();
                        if (mounted) setState(() => _step = 2);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF6366F1).withOpacity(0.08) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(_type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car, color: Colors.grey[400], size: 40),
                                      ),
                                    )
                                  : Icon(_type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car, color: Colors.grey[400], size: 40),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected ? const Color(0xFF6366F1) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModelStep() {
    final makeName = _selectedMake?['name']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            makeName.isEmpty ? 'Choose your vehicle model' : 'Models for $makeName — select your exact model',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
          ),
        ),
        Expanded(
          child: _loadingModels
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _models.length,
                  itemBuilder: (context, i) {
                    final m = _models[i];
                    final id = m['id'];
                    final name = m['name']?.toString() ?? '';
                    final imageUrl = _imageUrl(m['imageUrl']);
                    final selected = _selectedModel != null && _selectedModel!['id'] == id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedModel = m;
                          _step = 3;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF6366F1).withOpacity(0.08) : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 112,
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(_type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car, color: Colors.grey[400], size: 48),
                                    )
                                  : Icon(_type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car, color: Colors.grey[400], size: 48),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected ? const Color(0xFF6366F1) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isEdit && _selectedModel != null) ...[
            Text(
              '${_selectedMake?['name']} ${_selectedModel!['name']}',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _plateController,
            decoration: InputDecoration(
              labelText: 'Plate number (required)',
              hintText: 'e.g. MH 12 AB 1234',
              helperText: 'Format: State code + 2 digits + 2 letters + up to 4 digits',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.confirmation_number),
              errorText: _plateController.text.isNotEmpty && !_isValidPlate(_plateController.text)
                  ? 'Use format: MH 12 AB 1234'
                  : null,
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _fuelType,
            decoration: InputDecoration(
              labelText: 'Fuel type (required)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.local_gas_station),
            ),
            items: (_type == 'BIKE' ? _fuelTypesBike : _fuelTypesCar)
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _fuelType = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _yearController,
            decoration: InputDecoration(
              labelText: 'Year (optional)',
              hintText: 'e.g. 2022',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.calendar_today),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          if (!_isEdit) ...[
            Row(
              children: [
                Checkbox(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v ?? false),
                  activeColor: const Color(0xFF6366F1),
                ),
                Text('Set as default vehicle', style: GoogleFonts.outfit(fontSize: 14)),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Checkbox(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v ?? false),
                  activeColor: const Color(0xFF6366F1),
                ),
                Text('Default vehicle', style: GoogleFonts.outfit(fontSize: 14)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEdit ? 'Update' : 'Add vehicle',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

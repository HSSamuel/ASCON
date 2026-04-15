import 'package:flutter/material.dart';
import '../services/data_service.dart';

class ProgrammeRegistrationScreen extends StatefulWidget {
  final String programmeId;
  final String programmeTitle;
  final String? userId;
  final String? programmeImage;

  const ProgrammeRegistrationScreen({
    super.key,
    required this.programmeId,
    required this.programmeTitle,
    this.userId,
    this.programmeImage,
  });

  @override
  State<ProgrammeRegistrationScreen> createState() => _ProgrammeRegistrationScreenState();
}

class _ProgrammeRegistrationScreenState extends State<ProgrammeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService();
  bool _isLoading = false;

  // --- CONTROLLERS ---
  // ✅ CHANGED: Split Name Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _sex = "Male"; 

  // Address
  final _addressStreetController = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  
  // Country Logic
  String? _country; 
  final _otherCountryController = TextEditingController(); 

  // Employment
  final _orgController = TextEditingController();
  final _deptController = TextEditingController();
  final _jobController = TextEditingController();

  final List<String> _countries = ["Nigeria", "Ghana", "Kenya", "South Africa", "United Kingdom", "United States", "Canada", "Other"];

  @override
  void dispose() {
    // ✅ Dispose new controllers
    _firstNameController.dispose(); 
    _lastNameController.dispose();
    _emailController.dispose(); _phoneController.dispose();
    _addressStreetController.dispose(); _addressLine2Controller.dispose(); 
    _cityController.dispose(); _stateController.dispose();
    _otherCountryController.dispose();
    _orgController.dispose(); _deptController.dispose(); _jobController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
       return;
    }
    if (_country == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a country")));
       return;
    }

    String finalCountry = _country!;
    if (_country == "Other") {
      if (_otherCountryController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please specify your country")));
        return;
      }
      finalCountry = _otherCountryController.text.trim();
    }

    setState(() => _isLoading = true);

    // ✅ LOGIC: Combine First and Last Name
    final fullNameCombined = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

    final result = await _dataService.registerProgrammeInterest(
      programmeId: widget.programmeId,
      fullName: fullNameCombined, // Sending combined name
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      sex: _sex,
      addressStreet: _addressStreetController.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      country: finalCountry,
      sponsoringOrganisation: _orgController.text.trim(),
      department: _deptController.text.trim(),
      jobTitle: _jobController.text.trim(),
      userId: widget.userId,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );
      if (result['success']) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildHeaderWidget(Color primaryColor, bool isDark) {
    final Widget asconLogo = Image.asset(
      'assets/images/logo.png', 
      height: 60,
      fit: BoxFit.contain,
    );

    if (widget.programmeImage != null && widget.programmeImage!.isNotEmpty) {
      return Container(
        height: 200, 
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? Colors.grey[800] : Colors.grey[200],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.programmeImage!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Icon(Icons.image_not_supported, color: Colors.grey[400]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.85)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9), 
                        shape: BoxShape.circle,
                      ),
                      child: asconLogo,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      widget.programmeTitle, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 24.0,              
                        height: 1.2,
                      )
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            asconLogo,
            const SizedBox(height: 15),
            Text(
              widget.programmeTitle, 
              textAlign: TextAlign.center, 
              style: TextStyle(
                color: primaryColor, 
                fontWeight: FontWeight.w900, 
                fontSize: 24.0, 
              )
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Registration Form"),
        elevation: 0,
        // ✅ FIXED: Force Green Background & White Text
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white, 
          fontSize: 20, 
          fontWeight: FontWeight.bold
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderWidget(primaryColor, isDark),
              const SizedBox(height: 25),

              _buildSectionTitle("Personal Information", isDark),
              
              // ✅ FIXED: Split Full Name into Two Side-by-Side Boxes
              Row(
                children: [
                  Expanded(
                    child: _buildTextField("First Name", _firstNameController, Icons.person, isDark),
                  ),
                  const SizedBox(width: 15), // Gap between boxes
                  Expanded(
                    child: _buildTextField("Last Name", _lastNameController, Icons.person_outline, isDark),
                  ),
                ],
              ),

              _buildTextField("Email", _emailController, Icons.email, isDark, type: TextInputType.emailAddress),
              _buildTextField("Phone", _phoneController, Icons.phone, isDark, type: TextInputType.phone),
              
              const SizedBox(height: 15),
              Text("Sex", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: Text("Male", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      value: "Male",
                      groupValue: _sex,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _sex = val.toString()),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: Text("Female", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      value: "Female",
                      groupValue: _sex,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _sex = val.toString()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildSectionTitle("Address", isDark),
              _buildTextField("Street Address", _addressStreetController, Icons.location_on, isDark),
              _buildTextField("Address Line 2", _addressLine2Controller, Icons.location_on_outlined, isDark, isRequired: false),
              Row(
                children: [
                  Expanded(child: _buildTextField("City", _cityController, Icons.location_city, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("State / Region", _stateController, Icons.map, isDark)),
                ],
              ),
              const SizedBox(height: 15),
              
              // Dropdown
              DropdownButtonFormField<String>(
                value: _country,
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                   setState(() {
                     _country = val;
                     if (val != "Other") _otherCountryController.clear();
                   });
                },
                dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: "Country",
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: const Icon(Icons.public, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                  // ✅ FIXED: Explicit Border for Dropdown
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  ),
                ),
              ),

              if (_country == "Other") ...[
                const SizedBox(height: 15),
                // This uses _buildTextField which now has explicit borders
                _buildTextField("Please Specify Country", _otherCountryController, Icons.flag, isDark),
              ],

              const SizedBox(height: 25),

              _buildSectionTitle("Employment Info", isDark),
              _buildTextField("Sponsoring Organisation", _orgController, Icons.business, isDark),
              _buildTextField("Department", _deptController, Icons.meeting_room, isDark),
              _buildTextField("Current Job Title", _jobController, Icons.work, isDark),

              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT REGISTRATION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(), 
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.grey[300] : Colors.black54 
            )
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, {TextInputType type = TextInputType.text, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: isRequired ? (v) => v!.isEmpty ? "Required" : null : null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black), 
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]), 
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[50], 
          
          // ✅ FIXED: Explicit Borders to ensure visibility
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
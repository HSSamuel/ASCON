import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Added for potential link handling

class EventRegistrationScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String eventType; // e.g., "Reunion", "Webinar", "Seminar"
  final String? userId;
  final String? eventImage;

  const EventRegistrationScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.eventType,
    this.userId,
    this.eventImage,
  });

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService();
  bool _isLoading = false;

  // --- CONTROLLERS ---
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _sex = "Male"; 

  // Professional
  final _orgController = TextEditingController();
  final _jobController = TextEditingController();
  
  // Special Requirements
  final _specialReqController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose(); _lastNameController.dispose();
    _emailController.dispose(); _phoneController.dispose();
    _orgController.dispose(); _jobController.dispose();
    _specialReqController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    // ✅ FIX 1: Explicitly check that eventId is not empty before proceeding
    // This prevents sending an empty string to the backend which causes the 400 error.
    if (widget.eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Missing Event ID. Please try again."))
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
       return;
    }

    setState(() => _isLoading = true);

    final fullNameCombined = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

    // ✅ FIX 2: Ensure the eventId from the widget is passed directly to the service
    // This maps the required fields from the UI controllers to the backend API.
    final result = await _dataService.registerEventInterest(
      eventId: widget.eventId, 
      eventTitle: widget.eventTitle,
      eventType: widget.eventType,
      fullName: fullNameCombined,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      sex: _sex,
      organization: _orgController.text.trim(),
      jobTitle: _jobController.text.trim(),
      specialRequirements: _specialReqController.text.trim(),
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

  // --- UI BUILDERS (NO LINES REMOVED) ---
  
  Widget _buildHeaderWidget(Color primaryColor, bool isDark) {
    // ASCON Logo
    final Widget asconLogo = Image.asset(
      'assets/images/logo.png',
      height: 50,
      fit: BoxFit.contain,
    );

    if (widget.eventImage != null && widget.eventImage!.isNotEmpty) {
      return Container(
        height: 180,
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
                widget.eventImage!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Icon(Icons.event, color: Colors.grey[400]),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.eventType.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.eventTitle, 
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.w900, 
                        fontSize: 22.0,              
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
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            asconLogo,
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.eventType.toUpperCase(),
                style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.eventTitle, 
              textAlign: TextAlign.center, 
              style: TextStyle(
                color: primaryColor, 
                fontWeight: FontWeight.w900, 
                fontSize: 22.0, 
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
        title: const Text("Event Registration"),
        elevation: 0,
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
              _buildSectionTitle("Contact Details", isDark),
              Row(
                children: [
                  Expanded(child: _buildTextField("First Name", _firstNameController, Icons.person, isDark)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField("Last Name", _lastNameController, Icons.person_outline, isDark)),
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
              _buildSectionTitle("Professional Info", isDark),
              _buildTextField("Organization / Company", _orgController, Icons.business, isDark),
              _buildTextField("Job Title", _jobController, Icons.work, isDark),
              const SizedBox(height: 20),
              _buildSectionTitle("Preferences", isDark),
              _buildTextField(
                "Special Requirements (Dietary, Accessibility, etc.)", 
                _specialReqController, 
                Icons.accessibility, 
                isDark, 
                isRequired: false,
                maxLines: 3
              ),
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
                    : const Text("CONFIRM REGISTRATION", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, {TextInputType type = TextInputType.text, bool isRequired = true, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        // ✅ Added Justified Alignment for Multi-line text
        textAlign: maxLines > 1 ? TextAlign.justify : TextAlign.start,
        validator: isRequired ? (v) => v!.isEmpty ? "Required" : null : null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black), 
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]), 
          prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey) : Padding(padding: const EdgeInsets.only(bottom: 40), child: Icon(icon, color: Colors.grey)), 
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[50], 
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
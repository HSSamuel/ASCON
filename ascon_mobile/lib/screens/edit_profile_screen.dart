import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:hive/hive.dart';
import '../services/data_service.dart'; 
import '../viewmodels/profile_view_model.dart'; 
import '../viewmodels/dashboard_view_model.dart'; 

class EditProfileScreen extends ConsumerStatefulWidget { 
  final Map<String, dynamic> userData;
  final bool isFirstTime;

  const EditProfileScreen({
    super.key, 
    required this.userData,
    this.isFirstTime = false, 
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService(); 
  bool _isLoading = false;
  bool _isSuccess = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _jobController;
  late TextEditingController _orgController;
  late TextEditingController _yearController;
  late TextEditingController _otherProgrammeController;

  String? _selectedProgramme;
  
  Uint8List? _selectedImageBytes; 
  XFile? _pickedFile; 
  String? _currentUrl;

  final List<String> _programmeOptions = [
    "Management Programme",
    "Computer Programme",
    "Financial Management",
    "Leadership Development Programme",
    "Public Administration and Management",
    "Public Administration and Policy (Advanced)",
    "Public Sector Management Course",
    "Performance Improvement Course",
    "Creativity and Innovation Course",
    "Mandatory & Executive Programmes",
    "Postgraduate Diploma in Public Administration and Management",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['fullName'] ?? '');
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _jobController = TextEditingController(text: widget.userData['jobTitle'] ?? '');
    _orgController = TextEditingController(text: widget.userData['organization'] ?? '');
    _yearController = TextEditingController(text: widget.userData['yearOfAttendance']?.toString() ?? '');
    _otherProgrammeController = TextEditingController(text: widget.userData['customProgramme'] ?? '');

    String existingProg = widget.userData['programmeTitle'] ?? '';
    if (_programmeOptions.contains(existingProg)) {
      _selectedProgramme = existingProg;
    } else {
      _selectedProgramme = null;
    }

    if (existingProg == "Other" || (widget.userData['customProgramme'] != null && widget.userData['customProgramme'].toString().isNotEmpty)) {
      _selectedProgramme = "Other";
    }

    _currentUrl = widget.userData['profilePicture'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _orgController.dispose();
    _yearController.dispose();
    _otherProgrammeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedFile = pickedFile;
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _updateLocalCache(Map<String, String> fields) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (fields['fullName'] != null) {
        await prefs.setString('user_name', fields['fullName']!);
      }
      
      final cacheBox = Hive.box('ascon_cache');
      String? userJson = cacheBox.get('user_profile_cache');
      
      Map<String, dynamic> userMap = {};
      
      if (userJson != null) {
        userMap = jsonDecode(userJson);
      } else {
        userMap = Map<String, dynamic>.from(widget.userData);
      }

      fields.forEach((key, value) {
        if (key == 'yearOfAttendance') {
          userMap[key] = int.tryParse(value) ?? value;
        } else {
          userMap[key] = value;
        }
      });

      await cacheBox.put('user_profile_cache', jsonEncode(userMap));
      debugPrint("✅ Local Cache successfully updated in Hive");
    } catch (e) {
      debugPrint("❌ Cache Update Failed: $e");
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_yearController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Year of Attendance is required."), backgroundColor: Colors.red),
        );
        return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, String> fields = {
        'fullName': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'jobTitle': _jobController.text.trim(),
        'organization': _orgController.text.trim(),
        'yearOfAttendance': _yearController.text.trim(),
      };

      if (_selectedProgramme == "Other") {
        fields['programmeTitle'] = "Other";
        fields['customProgramme'] = _otherProgrammeController.text.trim();
      } else if (_selectedProgramme != null) {
        fields['programmeTitle'] = _selectedProgramme!;
        fields['customProgramme'] = "";
      }

      final bool success = await _dataService.updateProfile(fields, _pickedFile);

      if (!mounted) return;

      if (success) {
        await _updateLocalCache(fields);
        ref.invalidate(profileProvider);
        ref.invalidate(dashboardProvider);
        ref.read(dashboardProvider.notifier).loadData(isRefresh: true);

        if (!mounted) return;

        setState(() {
          _isSuccess = true; 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          if (widget.isFirstTime) {
            context.go('/home');         
            Navigator.of(context).pop(); 
          } else {
            Navigator.pop(context, true);
          }
        });
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update profile. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage(double radius) {
    if (_selectedImageBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_selectedImageBytes!),
        backgroundColor: Colors.grey[200],
      );
    }

    if (_currentUrl != null && _currentUrl!.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            _currentUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).primaryColor,
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: (value) {
        if (label == "Full Name" && (value == null || value.isEmpty)) {
          return "Name cannot be empty";
        }
        if (label == "Specify Programme Name" && _selectedProgramme == "Other" && (value == null || value.isEmpty)) {
          return "Please specify";
        }
        if (label == "Class Year" && (value == null || value.isEmpty)) {
          return "Required";
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;

    return PopScope(
      canPop: !widget.isFirstTime || _isSuccess, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please complete your profile to continue.")),
        );
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(widget.isFirstTime ? "Complete Profile" : "Edit Profile"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !widget.isFirstTime,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (widget.isFirstTime)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.brown),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Please review your details and set your Class Year to join the community.",
                            style: TextStyle(color: Colors.brown, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                Center(
                  child: Stack(
                    children: [
                      _buildProfileImage(50),
                      
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4AF37),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField("Full Name", _nameController, Icons.person),
                const SizedBox(height: 12),

                _buildTextField("Job Title", _jobController, Icons.work),
                const SizedBox(height: 12),
                _buildTextField("Organization", _orgController, Icons.business),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedProgramme,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: cardColor,
                  decoration: InputDecoration(
                    labelText: "Programme Attended",
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    prefixIcon: Icon(Icons.school, color: primaryColor, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  items: _programmeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 13, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedProgramme = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a programme' : null,
                ),

                if (_selectedProgramme == "Other") ...[
                  const SizedBox(height: 12),
                  _buildTextField(
                    "Specify Programme Name",
                    _otherProgrammeController,
                    Icons.edit_note,
                  ),
                ],

                const SizedBox(height: 12),

                _buildTextField("Class Year", _yearController, Icons.calendar_today, isNumber: true),
                
                const SizedBox(height: 12),
                _buildTextField("Short Bio", _bioController, Icons.person, maxLines: 3),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("SAVE CHANGES"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
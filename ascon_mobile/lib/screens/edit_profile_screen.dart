import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart'; 
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
  late TextEditingController _linkedinController;
  late TextEditingController _yearController;
  late TextEditingController _otherProgrammeController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDate;

  String _completePhoneNumber = "";
  String? _selectedProgramme;
  
  bool _isOpenToMentorship = false; 
  bool _isLocationVisible = false; 
  bool _isBirthdayVisible = true; 

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
    _linkedinController = TextEditingController(text: widget.userData['linkedin'] ?? '');
    _yearController = TextEditingController(text: widget.userData['yearOfAttendance']?.toString() ?? '');
    _otherProgrammeController = TextEditingController(text: widget.userData['customProgramme'] ?? '');
    _cityController = TextEditingController(text: widget.userData['city'] ?? '');
    _stateController = TextEditingController(text: widget.userData['state'] ?? '');

    _completePhoneNumber = widget.userData['phoneNumber'] ?? '';
    _isOpenToMentorship = widget.userData['isOpenToMentorship'] == true;
    _isLocationVisible = widget.userData['isLocationVisible'] == true; 
    _isBirthdayVisible = widget.userData['isBirthdayVisible'] ?? true; 

    if (widget.userData['dateOfBirth'] != null) {
      try {
        _selectedDate = DateTime.parse(widget.userData['dateOfBirth']);
        _dobController.text = DateFormat('MMM d, y').format(_selectedDate!);
      } catch (e) { }
    }

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
    _linkedinController.dispose();
    _yearController.dispose();
    _otherProgrammeController.dispose();
    _cityController.dispose(); 
    _stateController.dispose(); 
    _dobController.dispose();
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

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990),
      firstDate: DateTime(1900), // ✅ Expanded range
      lastDate: today,           // ✅ Strictly today
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM d, y').format(picked);
      });
    }
  }

  Future<void> _updateLocalCache(Map<String, String> fields) async {
    try {
      // 1. Keep SharedPreferences for basic name access if used elsewhere
      final prefs = await SharedPreferences.getInstance();
      if (fields['fullName'] != null) {
        await prefs.setString('user_name', fields['fullName']!);
      }
      
      // ✅ 2. FIX: Synchronize perfectly with ProfileNotifier's Hive Cache
      final cacheBox = Hive.box('ascon_cache');
      String? userJson = cacheBox.get('user_profile_cache');
      
      Map<String, dynamic> userMap = {};
      
      if (userJson != null) {
        userMap = jsonDecode(userJson);
      } else {
        userMap = Map<String, dynamic>.from(widget.userData);
      }

      // 3. Inject all newly submitted fields into the map safely
      fields.forEach((key, value) {
        if (key == 'isBirthdayVisible' || key == 'isLocationVisible' || key == 'isOpenToMentorship') {
          userMap[key] = value == 'true';
        } else if (key == 'yearOfAttendance') {
          userMap[key] = int.tryParse(value) ?? value;
        } else {
          userMap[key] = value;
        }
      });

      // 4. Save it back to Hive so ProfileNotifier reads the fresh data instantly
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
        'linkedin': _linkedinController.text.trim(),
        'phoneNumber': _completePhoneNumber, 
        'yearOfAttendance': _yearController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'isLocationVisible': _isLocationVisible.toString(),
        'isOpenToMentorship': _isOpenToMentorship.toString(), 
        'isBirthdayVisible': _isBirthdayVisible.toString(),
      };

      if (_selectedDate != null) {
        fields['dateOfBirth'] = _selectedDate!.toIso8601String();
      }

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

        // ✅ 1. Unlock the PopScope
        setState(() {
          _isSuccess = true; 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
        
        // ✅ 2. Wait exactly one frame for the UI to unlock, then clear the screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          if (widget.isFirstTime) {
            context.go('/home');         // 1. Sets the underlying router to Home
            Navigator.of(context).pop(); // 2. Removes this EditProfile screen sitting on top!
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

  // ✅ UI HELPER: Constructs the image widget safely
  Widget _buildProfileImage(double radius) {
    if (_selectedImageBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_selectedImageBytes!),
        backgroundColor: Colors.grey[200],
      );
    }

    if (_currentUrl != null && _currentUrl!.startsWith('http')) {
      // ✅ We use Image.network inside ClipOval instead of backgroundImage
      // This allows 'errorBuilder' to catch the 429 error and show the Icon fallback
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            _currentUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // If Google link fails (429), this runs and shows the default person icon
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

    // Default if no image exists at all
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

    String initialPhoneNumber = widget.userData['phoneNumber'] ?? '';
    String initialCountryCode = 'NG'; 
    
    if (initialPhoneNumber.startsWith('+')) {
      if (initialPhoneNumber.startsWith('+234')) {
        initialCountryCode = 'NG';
        initialPhoneNumber = initialPhoneNumber.substring(4); 
      } else if (initialPhoneNumber.startsWith('+1')) {
        initialCountryCode = 'US';
        initialPhoneNumber = initialPhoneNumber.substring(2);
      } else if (initialPhoneNumber.startsWith('+44')) {
        initialCountryCode = 'GB';
        initialPhoneNumber = initialPhoneNumber.substring(3);
      }
    } else if (initialPhoneNumber.startsWith('0')) {
      initialPhoneNumber = initialPhoneNumber.substring(1); 
    }

    return PopScope(
      // ✅ UPDATE THIS LINE: Allow popping if it's NOT their first time, OR if the save was successful
      canPop: !widget.isFirstTime || _isSuccess, 
      onPopInvoked: (didPop) {
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
                      // ✅ UPDATED: Using helper method for robust image handling
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

                _buildTextField(
                  "Date of Birth",
                  _dobController,
                  Icons.cake,
                  readOnly: true,
                  onTap: _pickDate,
                ),
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

                IntlPhoneField(
                  initialValue: initialPhoneNumber,
                  initialCountryCode: initialCountryCode,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  ),
                  style: TextStyle(fontSize: 14, color: textColor),
                  dropdownTextStyle: TextStyle(fontSize: 14, color: textColor),
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber; 
                  },
                ),

                const SizedBox(height: 12),
                _buildTextField("LinkedIn URL", _linkedinController, Icons.link),
                const SizedBox(height: 12),
                
                _buildTextField("Short Bio", _bioController, Icons.person, maxLines: 3),

                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField("City", _cityController, Icons.location_city),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField("State", _stateController, Icons.map_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    title: const Text("Make Location Visible", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Allow nearby alumni to find you on the map.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    value: _isLocationVisible,
                    activeColor: Colors.blue,
                    inactiveThumbColor: Colors.grey, 
                    inactiveTrackColor: Colors.grey.withOpacity(0.2),
                    onChanged: (bool value) {
                      setState(() {
                        _isLocationVisible = value;
                      });
                    },
                    secondary: Icon(Icons.location_on, color: _isLocationVisible ? Colors.blue : Colors.grey),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    title: const Text("Open to Mentorship", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Allow other alumni to contact you for guidance.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    value: _isOpenToMentorship,
                    activeColor: const Color(0xFFD4AF37), 
                    inactiveThumbColor: Colors.grey, 
                    inactiveTrackColor: Colors.grey.withOpacity(0.2),

                    onChanged: (bool value) {
                      setState(() {
                        _isOpenToMentorship = value;
                      });
                    },
                    secondary: Icon(Icons.stars, color: _isOpenToMentorship ? const Color(0xFFD4AF37) : Colors.grey),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SwitchListTile(
                    title: const Text("Show Birthday", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Announce my birthday to alumni on the dashboard.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    value: _isBirthdayVisible,
                    activeColor: Colors.pinkAccent,
                    inactiveThumbColor: Colors.grey, 
                    inactiveTrackColor: Colors.grey.withOpacity(0.2),
                    onChanged: (bool value) {
                      setState(() => _isBirthdayVisible = value);
                    },
                    secondary: Icon(Icons.cake, color: _isBirthdayVisible ? Colors.pinkAccent : Colors.grey),
                  ),
                ),

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
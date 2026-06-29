import 'dart:io';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/events_view_model.dart';
import '../../viewmodels/dashboard_view_model.dart';

class AddContentScreen extends ConsumerStatefulWidget {
  final String type; // 'Event' or 'Programme'

  const AddContentScreen({super.key, required this.type});

  @override
  ConsumerState<AddContentScreen> createState() => _AddContentScreenState();
}

class _AddContentScreenState extends ConsumerState<AddContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // Event Specific
  final TextEditingController _timeController = TextEditingController();
  DateTime? _selectedDate;
  String _eventType = "News";
  
  // Programme Specific
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();

  // ✅ UPDATED: List to hold multiple images
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // ✅ UPDATED: Use pickMultiImage for multiple selections
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      // Optional: limit to 5 images
      setState(() {
        _selectedImages = images.length > 5 ? images.sublist(0, 5) : images;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // ✅ Check against the new list
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one image")));
      return;
    }

    setState(() => _isSubmitting = true);

    String? error;
    
    if (widget.type == 'Event') {
      // ✅ Create Event (Pass images list)
      error = await ref.read(eventsProvider.notifier).createEvent(
        title: _titleController.text,
        description: _descController.text,
        location: _locationController.text,
        time: _timeController.text,
        type: _eventType,
        date: _selectedDate ?? DateTime.now(),
        images: _selectedImages, // Updated parameter
      );
    } else {
      // ✅ Create Programme (Pass images list)
      error = await ref.read(eventsProvider.notifier).createProgramme(
        title: _titleController.text,
        description: _descController.text,
        location: _locationController.text,
        duration: _durationController.text,
        fee: _feeController.text,
        images: _selectedImages, // Updated parameter
      );
      
      // Refresh Dashboard to show new programme
      if (error == null) {
        ref.read(dashboardProvider.notifier).loadData(isRefresh: true);
      }
    }

    setState(() => _isSubmitting = false);

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${widget.type} Created Successfully!")));
        Navigator.pop(context);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add ${widget.type}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Multiple Image Picker UI
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _selectedImages.isEmpty 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey), 
                            SizedBox(height: 8), 
                            Text("Tap to select image(s)", style: TextStyle(color: Colors.grey))
                          ],
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    kIsWeb 
                                      ? Image.network(_selectedImages[index].path, height: 160, width: 140, fit: BoxFit.cover)
                                      : Image.file(File(_selectedImages[index].path), height: 160, width: 140, fit: BoxFit.cover),
                                    // Remove individual image button
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedImages.removeAt(index));
                                        },
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (_selectedImages.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text("Tap inside the box to add/change images. (Max 5)", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                 ),
              const SizedBox(height: 20),

              // 2. Common Fields
              _buildTextField(_titleController, "Title", icon: Icons.title),
              const SizedBox(height: 12),
              _buildTextField(_locationController, "Location", icon: Icons.location_on),
              const SizedBox(height: 12),
              _buildTextField(_descController, "Description", icon: Icons.description, maxLines: 4),
              const SizedBox(height: 12),

              // 3. Conditional Fields
              if (widget.type == 'Event') ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final fiveYearsFromNow = DateTime(now.year + 5, now.month, now.day);

                          final date = await showDatePicker(
                            context: context, 
                            initialDate: _selectedDate ?? today, 
                            firstDate: today, 
                            lastDate: fiveYearsFromNow
                          );
                          
                          if (date != null) setState(() => _selectedDate = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: "Date", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                          child: Text(_selectedDate == null ? "Select Date" : DateFormat('MMM d, yyyy').format(_selectedDate!)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_timeController, "Time (e.g. 10 AM)", icon: Icons.access_time)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _eventType,
                  decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                  items: ["News", "Event", "Reunion", "Webinar", "Workshop"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _eventType = v!),
                )
              ] else ...[
                // Programme Fields
                Row(
                  children: [
                    Expanded(child: _buildTextField(_durationController, "Duration (e.g. 2 Weeks)", icon: Icons.timer)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_feeController, "Fee (e.g. ₦50,000)", icon: Icons.attach_money)),
                  ],
                )
              ],

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  child: _isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Post ${widget.type}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {IconData? icon, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
import 'dart:convert'; // ✅ Import this
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> facility;

  const FacilityDetailScreen({super.key, required this.facility});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  DateTime? _selectedDate;
  final TextEditingController _guestsController = TextEditingController();

  @override
  void dispose() {
    _guestsController.dispose();
    super.dispose();
  }

  // ✅ ACTION: Launch Payment URL
  Future<void> _launchPaymentUrl() async {
    final String? paymentUrl = widget.facility['paymentUrl'];
    if (paymentUrl != null && paymentUrl.isNotEmpty) {
      final Uri url = Uri.parse(paymentUrl);
      try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch $url';
        }
      } catch (e) {
        _showErrorSnackBar("Could not open payment page.");
      }
    }
  }

  // ✅ ACTION: Send Email Request
  Future<void> _sendEmailRequest() async {
    final String facilityName = widget.facility['name'];
    final String dateStr = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : "Not Specified";
    final String guests =
        _guestsController.text.isNotEmpty ? _guestsController.text : "Unknown";

    final String subject = "Booking Enquiry: $facilityName";
    final String body =
        "Hello ASCON Team,\n\nI am interested in booking the $facilityName.\n\n"
        "--- Enquiry Details ---\n"
        "📅 Proposed Date: $dateStr\n"
        "👥 Expected Guests: $guests\n"
        "\nPlease provide more information.";

    final String query =
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    final Uri emailLaunchUri = Uri.parse('mailto:info@ascon.gov.ng?$query');

    try {
      if (!await launchUrl(emailLaunchUri)) {
        throw 'Could not launch email';
      }
    } catch (e) {
      _showErrorSnackBar("Could not open email app.");
    }
  }

  // ✅ NEW: Safe Image Widget Helper
  Widget _buildSafeImage(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey);
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (c, e, s) => Container(color: Colors.grey),
      );
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: fit,
        errorBuilder: (c, e, s) => Container(color: Colors.grey),
      );
    } catch (e) {
      return Container(color: Colors.grey);
    }
  }

  // ✅ NEW: View Photo Full Screen
  void _openFullScreenImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              // ✅ USE SAFE IMAGE HERE TOO
              child: _buildSafeImage(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E3A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final String? imageUrl = widget.facility['image'];
    final bool isActive = widget.facility['isActive'] == true;
    final List<dynamic> rates = widget.facility['rates'] ?? [];
    final String description = widget.facility['description'] ??
        "No detailed description available.";
    
    final bool hasPaymentLink = widget.facility['paymentUrl'] != null &&
        widget.facility['paymentUrl'].toString().isNotEmpty;

    final List<String> amenities = [
      "Air Conditioning", "Security", "Parking", "Sound System", "Generator", "24Hour Solar Power"
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- HERO IMAGE ---
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: primaryColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: Colors.black26, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. The Image (Clickable)
                  GestureDetector(
                    onTap: () => _openFullScreenImage(context, imageUrl),
                    child: Hero(
                      tag: 'facility_img_${widget.facility['_id']}',
                      // ✅ USE SAFE IMAGE HERE
                      child: _buildSafeImage(imageUrl),
                    ),
                  ),
                  // 2. Gradient Overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                  // 3. ✅ NEW: "View Photo" Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: ElevatedButton.icon(
                      onPressed: () => _openFullScreenImage(context, imageUrl),
                      icon: const Icon(Icons.fullscreen, size: 18, color: Colors.white),
                      label: const Text("View Photo", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.facility['name'] ?? "Facility",
                          style: GoogleFonts.lato(
                              fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _buildStatusChip(isActive),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Text(
                    description,
                    style: GoogleFonts.lato(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 25),

                  Text("Key Amenities",
                      style: GoogleFonts.lato(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: amenities
                        .map((a) => Chip(
                              label:
                                  Text(a, style: const TextStyle(fontSize: 12)),
                              backgroundColor:
                                  isDark ? Colors.grey[800] : Colors.green[50],
                              labelStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white : Colors.green[900]),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 25),

                  // Booking Details Form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Booking Details",
                            style: GoogleFonts.lato(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 15),

                        // Date Picker
                        InkWell(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 18, color: Colors.grey),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedDate == null
                                      ? "Select Date"
                                      : DateFormat('EEE, MMM d, yyyy')
                                          .format(_selectedDate!),
                                  style: TextStyle(
                                    color: _selectedDate == null
                                        ? Colors.grey
                                        : (isDark ? Colors.white : Colors.black),
                                    fontWeight: _selectedDate == null
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Guest Count
                        TextField(
                          controller: _guestsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Number of Guests",
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            prefixIcon: const Icon(Icons.people_outline),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  if (rates.isNotEmpty) ...[
                    Text("Official Rates",
                        style: GoogleFonts.lato(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...rates.map((rate) => _buildRateCard(rate, isDark)),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Bar
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: SafeArea(
          child: hasPaymentLink
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isActive
                            ? () {
                                if (_selectedDate == null) {
                                  _showErrorSnackBar("Please select a date.");
                                  return;
                                }
                                _sendEmailRequest();
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF1B5E3A)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Enquire",
                            style: TextStyle(
                                color: Color(0xFF1B5E3A),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isActive
                            ? () {
                                if (_selectedDate == null) {
                                  _showErrorSnackBar("Please select a date.");
                                  return;
                                }
                                _launchPaymentUrl();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E3A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Pay Now",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Interested?",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600])),
                          const Text("Check Availability",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isActive
                          ? () {
                              if (_selectedDate == null) {
                                _showErrorSnackBar("Please select a date.");
                                return;
                              }
                              _sendEmailRequest();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E3A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Request Info",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? Colors.green : Colors.red),
      ),
      child: Text(
        isActive ? "AVAILABLE" : "BOOKED",
        style: TextStyle(
            color: isActive ? Colors.green : Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRateCard(dynamic rate, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rate['type'] ?? 'Rate',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            "₦${rate['naira']} / \$${rate['dollar']}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A)),
          ),
        ],
      ),
    );
  }
}
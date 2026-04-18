import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/data_service.dart'; // Assuming this handles your API calls

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (_isProcessing) return; // Prevent multiple scans at once

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String rawData = barcodes.first.rawValue ?? "";
    if (rawData.isEmpty) return;

    setState(() => _isProcessing = true);
    
    // Pause the camera while verifying
    controller.stop();

    // Parse the ID from the URL (e.g., https://.../verify/ID-123)
    String? alumniId;
    if (rawData.contains('/verify/')) {
       alumniId = rawData.split('/verify/').last.replaceAll('-', '/'); // Reverse your replacement
    } else {
       // Fallback if it's just the raw ID
       alumniId = rawData; 
    }

    if (alumniId.isNotEmpty) {
      await _verifyAlumni(alumniId);
    } else {
       _showErrorDialog("Invalid QR Code format.");
    }
  }

  Future<void> _verifyAlumni(String alumniId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator())
      );

      // Call your backend API (You will need to implement this in DataService)
      final verificationResult = await DataService().verifyAlumniNative(alumniId);
      
      // Close loading dialog
      if(mounted) Navigator.pop(context); 

      if (verificationResult != null && verificationResult['success'] == true) {
         _showSuccessDialog(verificationResult['data']);
      } else {
         _showErrorDialog("Verification failed or Alumni not found.");
      }
    } catch (e) {
       if(mounted) Navigator.pop(context);
       _showErrorDialog("Network error during verification.");
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text("Verified Alumni"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${data['fullName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Programme: ${data['programmeTitle']}"),
            const SizedBox(height: 8),
            Text("Class of: ${data['yearOfAttendance']}"),
            const SizedBox(height: 8),
            Text("ID: ${data['alumniId']}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close scanner screen
            }, 
            child: const Text("Done")
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
              controller.start(); // Resume scanning
            }, 
            child: const Text("Scan Another")
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
           children: [
             Icon(Icons.error_outline, color: Colors.red),
             SizedBox(width: 8),
             Text("Verification Failed"),
           ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
              controller.start();
            }, 
            child: const Text("Try Again")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Digital ID")),
      body: MobileScanner(
        controller: controller,
        onDetect: _handleDetection,
      ),
    );
  }
}
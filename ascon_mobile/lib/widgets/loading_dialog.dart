import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  final String message;

  const LoadingDialog({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents closing by back button while loading
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. The Spinner (Brand Color)
              const SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5E3A)), // ASCON Green
                ),
              ),
              
              const SizedBox(width: 20),
              
              // 2. The Text
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
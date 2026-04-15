import 'dart:convert'; // ✅ Required for Base64
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/dashboard_view_model.dart';

class CelebrationWidget extends ConsumerWidget {
  const CelebrationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final birthdays = dashboardState.birthdays;
    final isLoading = dashboardState.isLoading;

    if (!isLoading && birthdays.isEmpty) return const SizedBox.shrink();
    if (isLoading && birthdays.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_rounded, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                "Celebrating Today! 🎂", 
                style: GoogleFonts.lato(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.deepOrange[900]
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBirthdayList(birthdays),
        ],
      ),
    );
  }

  Widget _buildBirthdayList(List<dynamic> birthdays) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: birthdays.length,
        itemBuilder: (context, index) {
            final item = birthdays[index];
            final String name = (item['fullName'] ?? "User").split(" ")[0]; 
            final String? img = item['profilePicture'];

            return Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    // ✅ Use the robust image builder
                    child: _buildSafeAvatar(img),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name, 
                    style: GoogleFonts.lato(
                      fontSize: 11, 
                      fontWeight: FontWeight.w600, 
                      color: Colors.brown[800]
                    )
                  ),
                  const Text(
                    "Birthday",
                    style: TextStyle(fontSize: 10, color: Colors.deepOrange)
                  ),
                ],
              ),
            );
        },
      ),
    );
  }

  // ✅ CRITICAL FIX: Robust Image Handling (Base64 + URL support)
  Widget _buildSafeAvatar(String? imageUrl) {
    const double radius = 24;

    // 1. Handle HTTP URLs
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.white,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.grey, size: 20),
        ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(),
      );
    }

    // 2. Handle Base64 Data
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        String cleanBase64 = imageUrl;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(cleanBase64)),
          backgroundColor: Colors.white,
        );
      } catch (e) {
        return _buildFallbackAvatar();
      }
    }

    // 3. Fallback
    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return const CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, color: Colors.orangeAccent),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class DigitalIDCard extends StatelessWidget {
  final String userName;
  final String programme;
  final String year;
  final String alumniID; 
  final String imageUrl;

  const DigitalIDCard({
    super.key,
    required this.userName,
    required this.programme,
    required this.year,
    required this.alumniID,
    required this.imageUrl,
  });

  Widget _buildAvatarImage(String url, double size) {
    if (url.isEmpty || 
        url.contains('profile/picture/1') || 
        url.contains('googleusercontent.com/profile/picture')) {
      return Icon(Icons.person, color: Colors.grey, size: size * 0.5);
    }

    if (url.startsWith('data:')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (c, e, s) => Icon(Icons.person, color: Colors.grey, size: size * 0.5),
        );
      } catch (e) {
        return Icon(Icons.person, color: Colors.grey, size: size * 0.5);
      }
    }

    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, color: Colors.grey, size: size * 0.5);
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: size,
      height: size,
      placeholder: (context, url) => Container(color: Colors.grey[200]),
      errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.grey, size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cardGreen = Color(0xFF1B5E3A);
    // ✅ URL FIXED: Redirects to alumni site
    final String verificationLink = "https://asconalumni.netlify.app/verify/${alumniID.replaceAll('/', '-')}";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width > 600; 
        final double avatarSize = isDesktop ? 100 : 60;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: cardGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: -20,
                  right: -20,
                  child: Icon(
                    Icons.school, 
                    size: width * 0.25, 
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center, 
                              child: Text(
                                "ADMINISTRATIVE STAFF COLLEGE OF NIGERIA",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: isDesktop ? 45 : 30,
                            width: isDesktop ? 45 : 30,
                            child: Image.asset(
                              'assets/logo.png',
                              errorBuilder: (c, e, s) => const Icon(Icons.verified, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      
                      Divider(color: Colors.white24, height: isDesktop ? 30 : 20),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: ClipOval(
                                  child: _buildAvatarImage(imageUrl, avatarSize),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 16 : 10),
                              
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: QrImageView(
                                  data: verificationLink,
                                  version: QrVersions.auto,
                                  size: isDesktop ? 80.0 : 45.0,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(width: isDesktop ? 24 : 16),
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "ASCON ALUMNI",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 6 : 4),
                                
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    userName.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isDesktop ? 32 : 20, 
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: isDesktop ? 8 : 6),
                                
                                Text(
                                  programme,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isDesktop ? 16 : 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                SizedBox(height: isDesktop ? 12 : 8),

                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text(
                                    "ID: $alumniID", 
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isDesktop ? 14 : 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      fontFamily: "monospace"
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: isDesktop ? 16 : 10),
                                
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 16 : 10, 
                                    vertical: isDesktop ? 6 : 4
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "CLASS OF $year",
                                    style: TextStyle(
                                      color: cardGreen,
                                      fontSize: isDesktop ? 12 : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
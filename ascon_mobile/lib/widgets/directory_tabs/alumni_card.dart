import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/alumni_detail_screen.dart';

class AlumniCard extends StatelessWidget {
  final dynamic user;
  final String? badgeText;

  const AlumniCard({super.key, required this.user, this.badgeText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;

    final bool isMentor = user['isOpenToMentorship'] == true;
    final bool isOnline = user['isOnline'] == true;

    String subtitle = "Alumnus";
    if (user['jobTitle'] != null && user['jobTitle'].toString().isNotEmpty) {
      subtitle = "${user['jobTitle']} ${user['organization'] != null ? '• ${user['organization']}' : ''}";
    } else if (user['programmeTitle'] != null && user['programmeTitle'].toString().isNotEmpty) {
      subtitle = user['programmeTitle'];
    }

    String yearDisplay = "";
    if (user['yearOfAttendance'] != null) {
      String yStr = user['yearOfAttendance'].toString();
      yearDisplay = yStr.length >= 2 ? "'${yStr.substring(2)}" : yStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (context) => AlumniDetailScreen(alumniData: user))
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1)),
                      child: _buildAvatar(user['profilePicture'], isDark),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user['fullName'] ?? 'Unknown',
                                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMentor)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.stars_rounded, color: Colors.amber[700], size: 16),
                                  ),
                              ],
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(badgeText!, style: GoogleFonts.lato(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                            )
                          else if (yearDisplay.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(yearDisplay, style: GoogleFonts.lato(color: isDark ? const Color(0xFF81C784) : primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: GoogleFonts.lato(color: subTextColor, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("View Profile", style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF81C784) : primaryColor)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 10, color: isDark ? const Color(0xFF81C784) : primaryColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imagePath, bool isDark) {
    if (imagePath == null || imagePath.isEmpty || imagePath.contains('profile/picture/0')) {
      return _buildPlaceholder(isDark);
    }
    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        imageBuilder: (context, imageProvider) => CircleAvatar(radius: 24, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], backgroundImage: imageProvider),
        placeholder: (context, url) => _buildPlaceholder(isDark),
        errorWidget: (context, url, error) => _buildPlaceholder(isDark),
      );
    }
    try {
      return CircleAvatar(radius: 24, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], backgroundImage: MemoryImage(base64Decode(imagePath)));
    } catch (e) {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return CircleAvatar(
      radius: 24, backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
      child: const Icon(Icons.person, color: Colors.grey, size: 26),
    );
  }
}
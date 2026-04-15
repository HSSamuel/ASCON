import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final Widget child;
  
  const SkeletonLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: child,
    );
  }
}

// ✅ Reusable Image Placeholder
class SkeletonImage extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonImage({
    super.key, 
    this.width, 
    this.height, 
    this.borderRadius = 0
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// 1. EVENT CARD SKELETON
class EventSkeletonList extends StatelessWidget {
  const EventSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: 6, 
      itemBuilder: (context, index) => const SkeletonLoader(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: SizedBox(height: 200, width: double.infinity),
        ),
      ),
    );
  }
}

// 2. JOB CARD SKELETON
class JobSkeletonList extends StatelessWidget {
  const JobSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SkeletonLoader(
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 80, height: 12, color: Colors.white),
                      ],
                    )
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(width: 8),
                    Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ 3. DIRECTORY SKELETON (FIXED CRASH)
class DirectorySkeletonList extends StatelessWidget {
  const DirectorySkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true, // ✅ CRITICAL FIX: Allows nesting in ScrollView
      physics: const NeverScrollableScrollPhysics(), // ✅ CRITICAL FIX: Prevents scrolling conflicts
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SkeletonLoader(
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 150, height: 14, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 100, height: 12, color: Colors.white),
                    ],
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
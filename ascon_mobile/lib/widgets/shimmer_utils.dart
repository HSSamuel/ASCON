import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerHelper extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerHelper.rectangular({
    super.key, 
    this.width = double.infinity, 
    required this.height
  }) : shapeBorder = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));

  const ShimmerHelper.circular({
    super.key, 
    this.width = 64, 
    this.height = 64,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(seconds: 2), 
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: baseColor, 
          shape: shapeBorder,
        ),
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD SKELETON
// ==========================================
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID Card
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerHelper.rectangular(height: 200),
          ),
          const SizedBox(height: 16),
          // Profile Alert
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerHelper.rectangular(height: 60),
          ),
          const SizedBox(height: 16),
          // Horizontal Alumni List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerHelper.rectangular(width: 120, height: 20),
                ShimmerHelper.rectangular(width: 30, height: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ✅ FIXED: Replaced ListView with SingleChildScrollView + Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(5, (index) => const Padding(
                padding: EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    ShimmerHelper.circular(width: 56, height: 56),
                    SizedBox(height: 8),
                    ShimmerHelper.rectangular(width: 40, height: 10),
                  ],
                ),
              )),
            ),
          ),
          const SizedBox(height: 25),
          // Events List
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ShimmerHelper.rectangular(width: 180, height: 24),
          ),
          // ✅ FIXED: Replaced ListView with Column
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(2, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerHelper.rectangular(height: 95),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. FEED / UPDATES SKELETON
// ==========================================
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Using ListView safely as the root
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const ShimmerHelper.circular(width: 48, height: 48),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerHelper.rectangular(width: 140, height: 14),
                      SizedBox(height: 6),
                      ShimmerHelper.rectangular(width: 80, height: 12),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Text Lines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerHelper.rectangular(height: 14),
                  const SizedBox(height: 6),
                  const ShimmerHelper.rectangular(height: 14),
                  const SizedBox(height: 6),
                  ShimmerHelper.rectangular(width: MediaQuery.of(context).size.width * 0.6, height: 14),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Large Media Block
            const ShimmerHelper.rectangular(height: 250), 
            const SizedBox(height: 12),
            // Action Buttons
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerHelper.rectangular(width: 60, height: 20),
                  ShimmerHelper.rectangular(width: 60, height: 20),
                  ShimmerHelper.rectangular(width: 60, height: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[200]),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. EVENT LIST SKELETON (Pro Grid Fix)
// ==========================================
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Header
          const ShimmerHelper.rectangular(width: 100, height: 20),
          const SizedBox(height: 16),
          
          // Featured Carousel
          const ShimmerHelper.rectangular(width: double.infinity, height: 180),
          const SizedBox(height: 24),

          // Category Chips Row
          Row(
            children: List.generate(4, (index) => 
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ShimmerHelper.rectangular(width: 80, height: 32),
              )
            ),
          ),
          const SizedBox(height: 24),

          // ✅ FIXED: Grid Skeleton (Using Row + Column instead of GridView to avoid crash)
          Column(
            children: List.generate(3, (rowIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _buildGridItem()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGridItem()),
                ],
              ),
            )),
          )
        ],
      ),
    );
  }

  Widget _buildGridItem() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerHelper.rectangular(height: 100), // Image
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerHelper.rectangular(width: 60, height: 10),
                SizedBox(height: 6),
                ShimmerHelper.rectangular(width: double.infinity, height: 14),
                SizedBox(height: 10),
                ShimmerHelper.rectangular(width: 100, height: 12),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 4. DIRECTORY SKELETON
// ==========================================
class DirectorySkeleton extends StatelessWidget {
  const DirectorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Safe List Builder
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            const ShimmerHelper.circular(width: 60, height: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerHelper.rectangular(width: 140, height: 16),
                  SizedBox(height: 8),
                  ShimmerHelper.rectangular(width: 100, height: 12),
                  SizedBox(height: 8),
                  ShimmerHelper.rectangular(width: 80, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const ShimmerHelper.rectangular(width: 40, height: 40),
          ],
        ),
      ),
    );
  }
}

// ... existing code ...

// ==========================================
// 5. PROFILE SKELETON (New)
// ==========================================
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Center(child: ShimmerHelper.circular(width: 100, height: 100)),
          const SizedBox(height: 16),
          const ShimmerHelper.rectangular(width: 150, height: 20),
          const SizedBox(height: 8),
          const ShimmerHelper.rectangular(width: 200, height: 14),
          const SizedBox(height: 30),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              ShimmerHelper.rectangular(width: 60, height: 40),
              ShimmerHelper.rectangular(width: 60, height: 40),
              ShimmerHelper.rectangular(width: 60, height: 40),
            ],
          ),
          const SizedBox(height: 30),
          
          // Sections
          const Align(alignment: Alignment.centerLeft, child: ShimmerHelper.rectangular(width: 100, height: 18)),
          const SizedBox(height: 10),
          const ShimmerHelper.rectangular(height: 100),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: ShimmerHelper.rectangular(width: 100, height: 18)),
          const SizedBox(height: 10),
          const ShimmerHelper.rectangular(height: 150),
        ],
      ),
    );
  }
}

// ==========================================
// 6. CHAT LIST SKELETON (New)
// ==========================================
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => Row(
        children: [
          const ShimmerHelper.circular(width: 56, height: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerHelper.rectangular(width: 120, height: 16),
                SizedBox(height: 8),
                ShimmerHelper.rectangular(width: 200, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const ShimmerHelper.rectangular(width: 40, height: 12), // Time
        ],
      ),
    );
  }
}
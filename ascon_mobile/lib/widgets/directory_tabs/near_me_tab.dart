import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/directory_view_model.dart';
import 'alumni_card.dart';

class NearMeTab extends StatefulWidget {
  final DirectoryViewModel viewModel;

  const NearMeTab({super.key, required this.viewModel});

  @override
  State<NearMeTab> createState() => _NearMeTabState();
}

class _NearMeTabState extends State<NearMeTab> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredList = vm.filteredNearbyAlumni;

    String locationText = "Finding alumni near you...";
    if (vm.currentNearMeLocation != null && vm.currentNearMeLocation!.isNotEmpty) {
      locationText = "Showing alumni in ${vm.currentNearMeLocation!}";
    } else if (vm.nearbyAlumni.isNotEmpty) {
      final firstUserCity = vm.nearbyAlumni[0]['city'] ?? vm.nearbyAlumni[0]['state'] ?? "your area";
      locationText = "Found alumni in $firstUserCity";
    }

    return Column(
      children: [
        // 1. City Input
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _cityController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: "Travel Mode: Enter City",
                  hintText: "e.g. Abuja, Lagos, London",
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  prefixIcon: Icon(Icons.flight_takeoff, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => vm.loadNearMe(city: _cityController.text.trim()),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                onSubmitted: (val) => vm.loadNearMe(city: val),
              ),
              if (vm.nearbyAlumni.isNotEmpty || vm.currentNearMeLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Text(
                    locationText,
                    style: GoogleFonts.lato(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        // 2. Local Filter
        if (vm.nearbyAlumni.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _filterController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: "Filter by Name or Job",
                prefixIcon: Icon(Icons.person_search, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              onChanged: vm.setNearMeFilter,
            ),
          ),

        // 3. List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => vm.loadNearMe(city: _cityController.text),
            color: primaryColor,
            child: vm.isLoadingNearMe
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? Center(
                        child: Text("No alumni found nearby.\nTry entering a major city.",
                            textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) => AlumniCard(user: filteredList[index]),
                      ),
          ),
        ),
      ],
    );
  }
}
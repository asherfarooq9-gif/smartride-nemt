import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

class _SavedPlace {
  final String label;
  final String address;
  final IconData icon;

  const _SavedPlace({
    required this.label,
    required this.address,
    required this.icon,
  });
}

const _places = [
  _SavedPlace(
    label: 'Home',
    address: 'H-13, Street 4, Islamabad',
    icon: Icons.home_outlined,
  ),
  _SavedPlace(
    label: 'Work',
    address: 'Blue Area, Jinnah Avenue, Islamabad',
    icon: Icons.work_outline,
  ),
  _SavedPlace(
    label: 'Favourite Hospital',
    address: 'Pakistan Institute of Medical Sciences, G-8, Islamabad',
    icon: Icons.local_hospital_outlined,
  ),
];

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Places'),
        leading: const BackButton(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTeal600,
        foregroundColor: Colors.white,
        onPressed: () => _showComingSoon(context),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceLG),
        child: Column(
          children: [
            ..._places.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: kSpaceMD),
                child: _PlaceCard(place: place),
              ),
            ),
            const SizedBox(height: kSpaceSM),
            _AddPlaceButton(onTap: () => _showComingSoon(context)),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final _SavedPlace place;

  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceSM,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kTeal600.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(kRadiusMD),
          ),
          child: Icon(place.icon, color: kTeal600, size: 22),
        ),
        title: Text(
          place.label,
          style: const TextStyle(
            fontSize: kFontBody,
            fontWeight: FontWeight.w700,
            color: kText900,
          ),
        ),
        subtitle: Text(
          place.address,
          style: const TextStyle(
            fontSize: kFontSmall,
            color: kText600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: kText400),
          onPressed: () {},
        ),
        minVerticalPadding: 0,
      ),
    );
  }
}

class _AddPlaceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlaceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: kMinTapTarget,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusLG),
          border: Border.all(color: kBorder),
        ),
        child: const Center(
          child: Text(
            '＋  Add a place',
            style: TextStyle(
              fontSize: kFontSmall,
              fontWeight: FontWeight.w600,
              color: kTeal600,
            ),
          ),
        ),
      ),
    );
  }
}

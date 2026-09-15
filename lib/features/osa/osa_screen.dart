import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/supabase_client.dart';

/// On Shelf Availability: log product placement photos for a store visit
/// (main shelf, checkout/COC cashier display, secondary display). Matches
/// the placement_type enum in the product_placements table.
///
/// Not run on a real device -- no Flutter SDK available in this
/// environment. Needs verification on actual hardware before shipping.
class OsaScreen extends StatefulWidget {
  const OsaScreen({super.key, required this.storeVisitId});

  final String storeVisitId;

  @override
  State<OsaScreen> createState() => _OsaScreenState();
}

class _OsaScreenState extends State<OsaScreen> {
  static const _placementLabels = {
    'main_shelf': 'Homeshelf',
    'checkout_display': 'COC Cashier',
    'secondary_display': 'Secondary Display',
  };

  final Map<String, bool> _saving = {};
  final Map<String, bool> _saved = {};
  String? _error;

  Future<void> _logPlacement(String placementType) async {
    setState(() {
      _saving[placementType] = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      final userId = supabase.auth.currentUser!.id;
      final bytes = await photo.readAsBytes();
      final path = '$userId/${widget.storeVisitId}_${placementType}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('osa-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      await supabase.from('product_placements').insert({
        'store_visit_id': widget.storeVisitId,
        'placement_type': placementType,
        'photo_url': path,
      });

      setState(() => _saved[placementType] = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _saving[placementType] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On Shelf Availability')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Log a photo for each shelf location that applies.'),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            for (final entry in _placementLabels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: Icon(_saved[entry.key] == true ? Icons.check_circle : Icons.camera_alt),
                  label: Text(_saving[entry.key] == true
                      ? 'Uploading...'
                      : (_saved[entry.key] == true ? '${entry.value} (saved)' : entry.value)),
                  onPressed: _saving[entry.key] == true
                      ? null
                      : () => _logPlacement(entry.key),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

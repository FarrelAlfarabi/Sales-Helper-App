import 'package:flutter/material.dart';

import 'supabase_client.dart';

/// Shows a photo from a private Storage bucket via a short-lived signed URL.
class SignedPhoto extends StatelessWidget {
  const SignedPhoto({super.key, required this.bucket, required this.path, this.height = 180});

  final String bucket;
  final String? path;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) {
      return _box(context, const Text('Tidak ada foto'));
    }
    return FutureBuilder<String>(
      future: supabase.storage.from(bucket).createSignedUrl(p, 300),
      builder: (context, snap) {
        if (snap.hasError) return _box(context, const Text('Foto tidak tersedia'));
        if (!snap.hasData) return _box(context, const CircularProgressIndicator(strokeWidth: 2));
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(snap.data!, height: height, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _box(context, const Text('Foto tidak tersedia'))),
        );
      },
    );
  }

  Widget _box(BuildContext context, Widget child) => Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

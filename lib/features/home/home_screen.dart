import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../attendance/clock_in_screen.dart';
import '../store_visit/store_visit_screen.dart';

/// Home menu, mirroring the reference deck's layout: Attendance, Pricing,
/// Store Visit, On Shelf Availability, Summary Activity. Pricing and
/// Summary Activity are placeholders -- out of scope for this pass, which
/// covers only the schema/flows the project brief asked for (attendance,
/// store visits, product placement). See PROJECT_NOTES.md.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonein'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signed in as $email', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _MenuTile(
                      icon: Icons.calendar_today,
                      label: 'Attendance',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ClockInScreen()),
                      ),
                    ),
                    const _MenuTile(icon: Icons.sell, label: 'Pricing (not built yet)'),
                    _MenuTile(
                      icon: Icons.storefront,
                      label: 'Store Visit',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StoreVisitScreen()),
                      ),
                    ),
                    const _MenuTile(
                      icon: Icons.shelves,
                      label: 'On Shelf Availability (via Store Visit)',
                    ),
                    const _MenuTile(
                      icon: Icons.summarize,
                      label: 'Summary Activity (not built yet)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: onTap == null ? Colors.grey : null),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: onTap == null ? Colors.grey : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Manager/admin: assign an employee to a store, and see/deactivate
/// existing assignments.
///
/// Not run on a real device.
class StoreAssignmentScreen extends StatefulWidget {
  const StoreAssignmentScreen({super.key});

  @override
  State<StoreAssignmentScreen> createState() => _StoreAssignmentScreenState();
}

class _StoreAssignmentScreenState extends State<StoreAssignmentScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _assignments = [];
  String? _selectedEmployeeId;
  String? _selectedStoreId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final employees = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'field_rep')
          .order('full_name');
      final stores = await supabase.from('stores').select('id, name, code').order('name');
      final assignments = await supabase
          .from('store_assignments')
          .select('id, is_active, profiles(full_name), stores(name, code)')
          .eq('is_active', true);

      setState(() {
        _employees = List<Map<String, dynamic>>.from(employees);
        _stores = List<Map<String, dynamic>>.from(stores);
        _assignments = List<Map<String, dynamic>>.from(assignments);
      });
    } catch (e) {
      setState(() => _error = 'Failed to load: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    if (_selectedEmployeeId == null || _selectedStoreId == null) {
      setState(() => _error = 'Pick both an employee and a store.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await supabase.from('store_assignments').upsert({
        'employee_id': _selectedEmployeeId,
        'store_id': _selectedStoreId,
        'is_active': true,
        'assigned_by': supabase.auth.currentUser!.id,
      }, onConflict: 'employee_id,store_id');
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _deactivate(String id) async {
    try {
      await supabase.from('store_assignments').update({'is_active': false}).eq('id', id);
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Assignments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: _employees
                      .map((e) => DropdownMenuItem(
                            value: e['id'] as String,
                            child: Text(e['full_name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEmployeeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStoreId,
                  decoration: const InputDecoration(labelText: 'Store'),
                  items: _stores
                      .map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text('${s['name']} (${s['code']})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStoreId = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _assign,
                  child: Text(_submitting ? 'Assigning...' : 'Assign'),
                ),
                const Divider(height: 32),
                const Text('Current assignments', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final a in _assignments)
                  ListTile(
                    title: Text('${(a['profiles'] as Map?)?['full_name'] ?? '?'} '
                        '-> ${(a['stores'] as Map?)?['name'] ?? '?'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _deactivate(a['id'] as String),
                    ),
                  ),
              ],
            ),
    );
  }
}

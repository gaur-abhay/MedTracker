import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ManageGuardiansScreen extends StatefulWidget {
  const ManageGuardiansScreen({super.key});

  @override
  State<ManageGuardiansScreen> createState() => _ManageGuardiansScreenState();
}

class _ManageGuardiansScreenState extends State<ManageGuardiansScreen> {
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pending = await SupabaseService.instance.getPendingGuardianRequests();
      final approved = await SupabaseService.instance.getApprovedGuardians();
      setState(() {
        _pending = pending;
        _approved = approved;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String relationshipId, String guardianUsername) async {
    await SupabaseService.instance.respondToGuardianRequest(relationshipId, approve: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@$guardianUsername approved as guardian')),
      );
    }
    await _load();
  }

  Future<void> _reject(String relationshipId, String guardianUsername) async {
    await SupabaseService.instance.respondToGuardianRequest(relationshipId, approve: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@$guardianUsername request rejected')),
      );
    }
    await _load();
  }

  Future<void> _remove(String relationshipId, String guardianUsername) async {
    await SupabaseService.instance.respondToGuardianRequest(relationshipId, approve: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@$guardianUsername removed')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Guardians'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_pending.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Pending Requests',
                      icon: Icons.pending_outlined,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    ..._pending.map((r) => _PendingTile(
                          request: r,
                          onApprove: () => _approve(
                              r['id'] as String, r['guardian_username'] as String),
                          onReject: () => _reject(
                              r['id'] as String, r['guardian_username'] as String),
                        )),
                    const SizedBox(height: 16),
                  ],
                  const _SectionHeader(
                    title: 'Approved Guardians',
                    icon: Icons.shield_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 8),
                  if (_approved.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No guardians yet.\nApprove a request above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._approved.map((r) => _ApprovedTile(
                          guardian: r,
                          onRemove: () => _remove(
                              r['id'] as String, r['guardian_username'] as String),
                        )),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingTile(
      {required this.request,
      required this.onApprove,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(Icons.person_outline, color: Colors.orange),
        ),
        title: Text('@${request['guardian_username']}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Wants to be your guardian'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onReject,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF2E7D32)),
              onPressed: onApprove,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovedTile extends StatelessWidget {
  final Map<String, dynamic> guardian;
  final VoidCallback onRemove;

  const _ApprovedTile({required this.guardian, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.shield, color: Color(0xFF2E7D32)),
        ),
        title: Text('@${guardian['guardian_username']}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Can see your logs and trigger alarms'),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
          tooltip: 'Remove guardian',
          onPressed: onRemove,
        ),
      ),
    );
  }
}

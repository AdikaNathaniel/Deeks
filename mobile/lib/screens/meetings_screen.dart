import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models/meeting.dart';
import '../api/repositories/meetings_repository.dart';
import '../notifications/notification_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _repo = MeetingsRepository();
  late Future<List<Meeting>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  void _reload() => setState(() => _future = _repo.list());

  Future<void> _openForm({Meeting? existing}) async {
    final saved = await showModalBottomSheet<Meeting>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MeetingForm(existing: existing),
    );
    if (saved == null) return;
    try {
      final m = existing == null
          ? await _repo.create(saved)
          : await _repo.update(existing.id, saved);
      await NotificationService.instance.scheduleTenMinutesBefore(
        meetingId: m.id,
        title: m.title,
        platformLabel: meetingPlatformLabel(m.platform),
        scheduledAt: m.scheduledAt,
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _delete(Meeting m) async {
    await _repo.delete(m.id);
    await NotificationService.instance.cancelForMeeting(m.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Meeting>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No meetings yet. Tap + to add one.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final m = items[i];
                return Dismissible(
                  key: ValueKey(m.id),
                  background: Container(color: Colors.red),
                  confirmDismiss: (_) async {
                    await _delete(m);
                    return true;
                  },
                  child: ListTile(
                    title: Text(m.title),
                    subtitle: Text(
                      '${meetingPlatformLabel(m.platform)} · '
                      '${DateFormat('EEE, MMM d · HH:mm').format(m.scheduledAt)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(Uri.parse(m.link)),
                    ),
                    onTap: () => _openForm(existing: m),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MeetingForm extends StatefulWidget {
  final Meeting? existing;
  const _MeetingForm({this.existing});

  @override
  State<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends State<_MeetingForm> {
  final _title = TextEditingController();
  final _link = TextEditingController();
  final _meetingId = TextEditingController();
  final _passcode = TextEditingController();
  final _notes = TextEditingController();
  MeetingPlatform _platform = MeetingPlatform.zoom;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _link.text = e.link;
      _meetingId.text = e.meetingId ?? '';
      _passcode.text = e.passcode ?? '';
      _notes.text = e.notes ?? '';
      _platform = e.platform;
      _scheduledAt = e.scheduledAt;
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty || _link.text.trim().isEmpty) return;
    final m = Meeting(
      id: widget.existing?.id ?? '',
      title: _title.text.trim(),
      platform: _platform,
      link: _link.text.trim(),
      meetingId: _meetingId.text.trim().isEmpty ? null : _meetingId.text.trim(),
      passcode: _passcode.text.trim().isEmpty ? null : _passcode.text.trim(),
      scheduledAt: _scheduledAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    Navigator.pop(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'New meeting' : 'Edit meeting',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MeetingPlatform>(
              initialValue: _platform,
              decoration: const InputDecoration(labelText: 'Platform'),
              items: MeetingPlatform.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(meetingPlatformLabel(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              decoration: const InputDecoration(labelText: 'Meeting link'),
            ),
            if (_platform == MeetingPlatform.zoom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _meetingId,
                decoration: const InputDecoration(labelText: 'Zoom meeting ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passcode,
                decoration: const InputDecoration(labelText: 'Passcode'),
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scheduled for'),
              subtitle: Text(
                DateFormat('EEE, MMM d yyyy · HH:mm').format(_scheduledAt),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

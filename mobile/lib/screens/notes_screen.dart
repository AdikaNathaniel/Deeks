import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';

import '../api/models/note.dart';
import '../api/repositories/notes_repository.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = NotesRepository();
  final _picker = ImagePicker();
  late Future<List<Note>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  void _reload() => setState(() {
        _future = _repo.list();
      });

  Future<void> _confirmAndDelete(Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${n.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(n.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _openForm({Note? existing, String? prefillBody}) async {
    final saved = await showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteForm(existing: existing, prefillBody: prefillBody),
    );
    if (saved == null) return;
    try {
      if (existing == null) {
        await _repo.create(saved);
      } else {
        await _repo.update(existing.id, saved);
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _onAddTapped() async {
    final action = await showModalBottomSheet<_AddAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Blank note'),
              onTap: () => Navigator.pop(ctx, _AddAction.blank),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo (OCR)'),
              onTap: () => Navigator.pop(ctx, _AddAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery (OCR)'),
              onTap: () => Navigator.pop(ctx, _AddAction.gallery),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == _AddAction.blank) {
      await _openForm();
      return;
    }
    await _scanImage(
      action == _AddAction.camera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _scanImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;
    try {
      final text = await FlutterTesseractOcr.extractText(
        picked.path,
        language: 'eng',
      );
      if (!mounted) return;
      await _openForm(prefillBody: text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Note>>(
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
              child: Text('No notes yet. Tap + or scan an image.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final n = items[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  background: Container(color: Colors.red),
                  confirmDismiss: (_) async {
                    await _repo.delete(n.id);
                    _reload();
                    return true;
                  },
                  child: ListTile(
                    title: Text(n.title),
                    subtitle: Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete note',
                      onPressed: () => _confirmAndDelete(n),
                    ),
                    onTap: () => _openForm(existing: n),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddTapped,
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _AddAction { blank, camera, gallery }

class _NoteForm extends StatefulWidget {
  final Note? existing;
  final String? prefillBody;
  const _NoteForm({this.existing, this.prefillBody});

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _body.text = e.body;
      _tags.text = e.tags.join(', ');
    } else if (widget.prefillBody != null) {
      _body.text = widget.prefillBody!;
      _title.text = 'Scanned ${DateTime.now().toLocal().toString().substring(0, 16)}';
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      Note(
        id: widget.existing?.id ?? '',
        title: _title.text.trim(),
        body: _body.text,
        tags: tags,
      ),
    );
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
              widget.existing == null ? 'New note' : 'Edit note',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models/link_entry.dart';
import '../api/repositories/links_repository.dart';

class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  final _repo = LinksRepository();
  late Future<List<LinkEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  void _reload() => setState(() => _future = _repo.list());

  Future<void> _openForm({LinkEntry? existing}) async {
    final saved = await showModalBottomSheet<LinkEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinkForm(existing: existing),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<LinkEntry>>(
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
            return const Center(child: Text('No links yet. Tap + to add one.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final l = items[i];
                return Dismissible(
                  key: ValueKey(l.id),
                  background: Container(color: Colors.red),
                  confirmDismiss: (_) async {
                    await _repo.delete(l.id);
                    _reload();
                    return true;
                  },
                  child: ListTile(
                    title: Text(l.title),
                    subtitle: Text(l.url),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(Uri.parse(l.url)),
                    ),
                    onTap: () => _openForm(existing: l),
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

class _LinkForm extends StatefulWidget {
  final LinkEntry? existing;
  const _LinkForm({this.existing});

  @override
  State<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends State<_LinkForm> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _url.text = e.url;
      _category.text = e.category ?? '';
      _description.text = e.description ?? '';
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      LinkEntry(
        id: widget.existing?.id ?? '',
        title: _title.text.trim(),
        url: _url.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
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
              widget.existing == null ? 'New link' : 'Edit link',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

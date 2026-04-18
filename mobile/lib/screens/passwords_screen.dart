import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/models/password_entry.dart';
import '../api/repositories/passwords_repository.dart';
import '../crypto/vault_crypto.dart';

const _pinKey = 'master_pin';

class PasswordsScreen extends StatefulWidget {
  const PasswordsScreen({super.key});

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  final _repo = PasswordsRepository();
  final _vault = VaultCrypto();
  final _storage = const FlutterSecureStorage();

  Future<List<PasswordEntry>>? _future;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final pin = await _storage.read(key: _pinKey);
    if (pin == null) {
      // PIN not yet set — show setup dialog after first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _setupPin());
      return;
    }
    await _vault.unlockWithPin(pin);
    setState(() {
      _ready = true;
      _future = _repo.list();
    });
  }

  Future<void> _setupPin() async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinSetupDialog(),
    );
    if (pin == null) return;
    await _storage.write(key: _pinKey, value: pin);
    await _vault.unlockWithPin(pin);
    setState(() {
      _ready = true;
      _future = _repo.list();
    });
  }

  void _reload() => setState(() => _future = _repo.list());

  Future<void> _openForm({PasswordEntry? existing, String? currentPlain}) async {
    final saved = await showModalBottomSheet<_PasswordFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PasswordForm(existing: existing, currentPlain: currentPlain),
    );
    if (saved == null) return;
    final encrypted = _vault.encrypt(saved.plaintext);
    final entry = PasswordEntry(
      id: existing?.id ?? '',
      platform: saved.platform,
      label: saved.label,
      ciphertext: encrypted.ciphertext,
      iv: encrypted.iv,
      algorithm: encrypted.algorithm,
    );
    try {
      if (existing == null) {
        await _repo.create(entry);
      } else {
        await _repo.update(existing.id, entry);
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
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: FutureBuilder<List<PasswordEntry>>(
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
              child: Text('Vault is empty. Tap + to add a credential.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                return Dismissible(
                  key: ValueKey(p.id),
                  background: Container(color: Colors.red),
                  confirmDismiss: (_) async {
                    await _repo.delete(p.id);
                    _reload();
                    return true;
                  },
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: Text(p.label),
                    subtitle: Text(p.platform),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy password',
                      onPressed: () {
                        final plain =
                            _vault.decrypt(ciphertext: p.ciphertext, iv: p.iv);
                        Clipboard.setData(ClipboardData(text: plain));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        }
                      },
                    ),
                    onTap: () {
                      final plain =
                          _vault.decrypt(ciphertext: p.ciphertext, iv: p.iv);
                      _openForm(existing: p, currentPlain: plain);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  void _submit() {
    final a = _pin1.text;
    final b = _pin2.text;
    if (a.length < 6) {
      setState(() => _error = 'PIN must be at least 6 characters');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set master PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Used to encrypt your vault. Cannot be recovered if forgotten.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin1,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _PasswordFormResult {
  final String platform;
  final String label;
  final String plaintext;
  _PasswordFormResult(this.platform, this.label, this.plaintext);
}

class _PasswordForm extends StatefulWidget {
  final PasswordEntry? existing;
  final String? currentPlain;
  const _PasswordForm({this.existing, this.currentPlain});

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _platform = TextEditingController();
  final _label = TextEditingController();
  final _secret = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _platform.text = e.platform;
      _label.text = e.label;
      _secret.text = widget.currentPlain ?? '';
    }
  }

  void _save() {
    if (_platform.text.trim().isEmpty ||
        _label.text.trim().isEmpty ||
        _secret.text.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _PasswordFormResult(
        _platform.text.trim(),
        _label.text.trim(),
        _secret.text,
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
              widget.existing == null ? 'New credential' : 'Edit credential',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _platform,
              decoration: const InputDecoration(
                labelText: 'Platform (e.g. Google, GitHub)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label / username',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pinput/pinput.dart';

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

  void _reload() => setState(() {
        _future = _repo.list();
      });

  Future<void> _confirmAndDelete(PasswordEntry p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete credential?'),
        content: Text('"${p.label}" (${p.platform}) will be permanently removed.'),
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
      await _repo.delete(p.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy password',
                          onPressed: () {
                            final plain = _vault.decrypt(
                                ciphertext: p.ciphertext, iv: p.iv);
                            Clipboard.setData(ClipboardData(text: plain));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete credential',
                          onPressed: () => _confirmAndDelete(p),
                        ),
                      ],
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
  static const _pinLength = 4;
  String? _firstPin;
  String? _error;
  final _controller = TextEditingController();

  void _onCompleted(String value) {
    if (_firstPin == null) {
      setState(() {
        _firstPin = value;
        _error = null;
        _controller.clear();
      });
    } else {
      if (value == _firstPin) {
        Navigator.pop(context, value);
      } else {
        setState(() {
          _error = 'PINs do not match. Start again.';
          _firstPin = null;
          _controller.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00BCD4), width: 1.5),
      ),
    );
    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFF00BCD4), width: 2.5),
        color: const Color(0xFFE0F7FA),
      ),
    );
    final submittedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
        color: const Color(0xFFE0F7FA),
      ),
    );

    final prompt = _firstPin == null
        ? 'Choose a 4-digit master PIN'
        : 'Re-enter your PIN to confirm';

    return AlertDialog(
      title: const Text('Set master PIN', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Pinput(
            controller: _controller,
            length: _pinLength,
            obscureText: true,
            obscuringCharacter: '•',
            defaultPinTheme: defaultTheme,
            focusedPinTheme: focusedTheme,
            submittedPinTheme: submittedTheme,
            keyboardType: TextInputType.number,
            autofocus: true,
            onCompleted: _onCompleted,
          ),
          const SizedBox(height: 14),
          Text(
            'Encrypts your vault on this device.\nCannot be recovered if forgotten.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

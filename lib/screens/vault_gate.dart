import 'package:flutter/material.dart';
import '../services/vault_service.dart';
import 'vault_home.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({super.key, this.isFirstSetup = false});
  final bool isFirstSetup;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  final _code = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showCode = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.isFirstSetup) {
        if (_code.text.length < 8) throw Exception('Use at least 8 characters.');
        if (_code.text != _confirm.text) throw Exception('The codes do not match.');
        await VaultService.instance.createVault(_code.text);
      } else {
        final ok = await VaultService.instance.unlock(_code.text);
        if (!ok) throw Exception('Incorrect secret code. Please try again.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VaultHome()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('Invalid argument(s): ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.isFirstSetup;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10294A),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF168BFF), width: 1.5),
                    ),
                    child: const Icon(Icons.sd_storage_rounded, color: Color(0xFFBFC9D8), size: 58),
                  ),
                  const SizedBox(height: 24),
                  Text('CodeVanta Vault', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(first ? 'Create your private vault' : 'Your files. Your privacy.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 34),
                  _field(_code, first ? 'Create secret code' : 'Enter secret code'),
                  if (first) ...[
                    const SizedBox(height: 14),
                    _field(_confirm, 'Confirm secret code'),
                    const SizedBox(height: 12),
                    const Text('Use at least 8 characters. There is no password recovery. Keep your code safe.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(first ? 'CREATE MY VAULT' : 'UNLOCK VAULT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        obscureText: !_showCode,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.key_rounded),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showCode = !_showCode),
            icon: Icon(_showCode ? Icons.visibility_off : Icons.visibility),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}

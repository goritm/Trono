import 'package:material_ui/material_ui.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/app_strings.dart';
import '../state/trono_controller.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.controller,
    required this.onUnlocked,
  });

  final TronoController controller;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _localAuth = LocalAuthentication();
  String _enteredPin = '';
  bool _error = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    if (!widget.controller.biometricEnabled) return;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!mounted) return;
      setState(() => _biometricAvailable = supported);
      if (supported) {
        await _authenticateBiometrics();
      }
    } catch (_) {}
  }

  Future<void> _authenticateBiometrics() async {
    try {
      final s = AppStrings.of(context);
      final ok = await _localAuth.authenticate(
        localizedReason: s.biometricReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) {
        widget.onUnlocked();
      }
    } catch (_) {}
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _error = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      if (widget.controller.verifyPin(_enteredPin)) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = true;
          _enteredPin = '';
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasPin = widget.controller.hasPin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🔒', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 16),
              Text(
                s.lockTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.lockSubtitle,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              if (hasPin) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _enteredPin.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: _error ? scheme.error : scheme.primary,
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
                if (_error) ...[
                  const SizedBox(height: 10),
                  Text(
                    s.wrongPin,
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: 260,
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.25,
                    children: [
                      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                        _PinButton(label: d, onTap: () => _onDigit(d)),
                      if (_biometricAvailable)
                        IconButton.filledTonal(
                          onPressed: _authenticateBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded, size: 28),
                        )
                      else
                        const SizedBox.shrink(),
                      _PinButton(label: '0', onTap: () => _onDigit('0')),
                      IconButton(
                        onPressed: _onBackspace,
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                ),
              ] else if (_biometricAvailable) ...[
                FilledButton.icon(
                  onPressed: _authenticateBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(s.unlockBiometric),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

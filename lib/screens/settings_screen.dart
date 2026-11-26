import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/bathroom_log.dart';
import '../services/backup_service.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final TronoController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localAuth = LocalAuthentication();
  bool _biometricsSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (mounted) setState(() => _biometricsSupported = supported);
    } catch (_) {}
  }

  Future<void> _showSetPinDialog() async {
    final s = AppStrings.of(context);
    final pinCtrl = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.enterNewPin),
        content: TextField(
          controller: pinCtrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '••••',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancelTimer),
          ),
          FilledButton(
            onPressed: () {
              if (pinCtrl.text.length == 4) {
                Navigator.of(ctx).pop(pinCtrl.text);
              }
            },
            child: Text(s.saveButton),
          ),
        ],
      ),
    );
    pinCtrl.dispose();

    if (saved != null && saved.length == 4) {
      await widget.controller.setPin(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.pinSavedToast)),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    final s = AppStrings.of(context);
    try {
      final logs = await BackupService.pickAndParseBackup();
      if (logs == null) return;
      final count = await widget.controller.importLogs(logs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.importedCountToast(count))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.importFailedToast)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final ctrl = widget.controller;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(s.settingsTitle),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          sliver: SliverList.list(
            children: [
              _SectionTitle(s.appearanceSection),
              ChunkyCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.languageLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'es', label: Text('Español')),
                          ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {ctrl.locale.languageCode},
                        onSelectionChanged: (set) =>
                            ctrl.setLocale(Locale(set.first)),
                        showSelectedIcon: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.themeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(s.themeSystem),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(s.themeLight),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(s.themeDark),
                          ),
                        ],
                        selected: {ctrl.themeMode},
                        onSelectionChanged: (set) =>
                            ctrl.setThemeMode(set.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.securitySection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        s.appLockLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.appLockSubtitle),
                      value: ctrl.lockEnabled,
                      onChanged: (enabled) async {
                        if (enabled && !ctrl.hasPin && !_biometricsSupported) {
                          await _showSetPinDialog();
                          if (!ctrl.hasPin) return;
                        }
                        await ctrl.setLockEnabled(enabled);
                      },
                    ),
                    if (ctrl.lockEnabled) ...[
                      const Divider(height: 1),
                      if (_biometricsSupported)
                        SwitchListTile(
                          title: Text(s.biometricLabel),
                          value: ctrl.biometricEnabled,
                          onChanged: ctrl.setBiometricEnabled,
                        ),
                      ListTile(
                        leading: _ColorIcon(
                          Icons.pin_rounded,
                          TronoColors.terracotta,
                        ),
                        title: Text(
                          s.setPinLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: ctrl.hasPin
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: TronoColors.sage,
                                size: 22,
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _showSetPinDialog,
                      ),
                      if (ctrl.hasPin && _biometricsSupported)
                        ListTile(
                          leading: _ColorIcon(
                            Icons.lock_open_rounded,
                            TronoColors.coral,
                          ),
                          title: Text(
                            s.removePinLabel,
                            style: const TextStyle(
                              color: TronoColors.coral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: ctrl.clearPin,
                        ),
                    ],
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.defaultPrivacyLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ShareLevel.values.map((lvl) {
                              return ChoiceChip(
                                label: Text(s.shareLevelName(lvl)),
                                selected: ctrl.defaultShareLevel == lvl,
                                onSelected: (_) =>
                                    ctrl.setDefaultShareLevel(lvl),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.backupSection),
              ChunkyCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: _ColorIcon(
                        Icons.data_object_rounded,
                        TronoColors.terracotta,
                      ),
                      title: Text(
                        s.exportJsonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.exportJsonSub),
                      trailing: const Icon(Icons.ios_share_rounded, size: 20),
                      onTap: () => BackupService.exportJson(ctrl.logs),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.table_chart_rounded,
                        TronoColors.gold,
                      ),
                      title: Text(
                        s.exportCsvLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.exportCsvSub),
                      trailing: const Icon(Icons.ios_share_rounded, size: 20),
                      onTap: () => BackupService.exportCsv(ctrl.logs),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: _ColorIcon(
                        Icons.file_upload_rounded,
                        TronoColors.obsidian,
                      ),
                      title: Text(
                        s.importBackupLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(s.importBackupSub),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _handleImport,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _SectionTitle(s.widgetSection),
              ChunkyCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ColorIcon(Icons.widgets_rounded, TronoColors.terracotta),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.widgetGuideBody,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: TronoColors.muted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              ChunkyCard(
                color: TronoColors.obsidian,
                borderColor: const Color(0xFF343B4D),
                lipColor: TronoColors.obsidianLip,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ColorIcon(Icons.groups_rounded, TronoColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.multiplayerTeaserTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.multiplayerTeaserBody,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorIcon extends StatelessWidget {
  const _ColorIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = (color == TronoColors.obsidian && isDark)
        ? TronoColors.darkInk
        : color;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 21),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: TronoColors.muted(context),
        ),
      ),
    );
  }
}

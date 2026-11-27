import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/app_update.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

/// Displays formatted GitHub Release notes in a tactile bottom sheet.
/// When [onDownload] is provided, displays a primary Download CTA alongside Close;
/// when omitted (e.g., viewing the installed version's changelog), shows a single Close CTA.
Future<void> showReleaseNotesSheet(
  BuildContext context, {
  required AppReleaseInfo release,
  VoidCallback? onDownload,
}) {
  final s = AppStrings.of(context);
  final lines = ReleaseNotesFormatter.extractLines(release.releaseNotes);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: TronoColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TronoColors.gold.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: TronoColors.terracotta,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.releaseNotesTitle(release.tagName),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: TronoColors.ink(sheetCtx),
                          ),
                        ),
                        if (onDownload != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.updateAvailableSub,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: TronoColors.muted(sheetCtx),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: TronoColors.terracotta,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                      color: TronoColors.ink(sheetCtx),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (onDownload != null)
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: Text(
                        s.releaseNotesCloseBtn,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TronoColors.muted(sheetCtx),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChunkyButton(
                        key: const ValueKey('release_notes_download_btn'),
                        color: TronoColors.terracotta,
                        lipColor: TronoColors.terracottaLip,
                        lipHeight: 4,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          onDownload();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.updateDownloadBtn,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                ChunkyButton(
                  width: double.infinity,
                  color: TronoColors.terracotta,
                  lipColor: TronoColors.terracottaLip,
                  lipHeight: 4,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  child: Center(
                    child: Text(
                      s.releaseNotesCloseBtn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class UpdateBannerCard extends StatelessWidget {
  const UpdateBannerCard({
    super.key,
    required this.release,
    required this.onDownload,
    required this.onDismiss,
  });

  final AppReleaseInfo release;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNotes =
        ReleaseNotesFormatter.extractLines(release.releaseNotes).isNotEmpty;

    return ChunkyCard(
      color: isDark ? const Color(0xFF2B2618) : const Color(0xFFFFF8E6),
      borderColor: TronoColors.gold,
      lipColor: TronoColors.goldLip,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: TronoColors.gold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.system_update_rounded,
              color: TronoColors.terracotta,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.updateAvailableTitle(release.tagName),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: TronoColors.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.updateAvailableSub,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                    color: TronoColors.muted(context),
                  ),
                ),
                if (hasNotes) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    key: const ValueKey('update_banner_notes_btn'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => showReleaseNotesSheet(
                      context,
                      release: release,
                      onDownload: onDownload,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.updateWhatsNewBtn,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: TronoColors.terracotta,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: TronoColors.terracotta,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('update_banner_download_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: TronoColors.terracotta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onDownload,
            child: Text(
              s.updateDownloadBtn,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('update_banner_dismiss_btn'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: TronoColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

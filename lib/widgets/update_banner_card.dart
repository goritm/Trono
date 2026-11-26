import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/app_update.dart';
import '../theme/app_theme.dart';
import 'chunky_widgets.dart';

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

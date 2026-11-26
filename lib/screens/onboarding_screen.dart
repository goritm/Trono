import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../state/social_controller.dart';
import '../state/trono_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky_widgets.dart';
import '../widgets/trono_toast.dart';
import 'social_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.social,
  });

  final TronoController controller;
  final SocialController social;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  int _pageIndex = 0;
  bool _capturingHome = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    final target = index.clamp(0, _pageCount - 1);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleCaptureHome() async {
    final s = AppStrings.of(context);
    setState(() => _capturingHome = true);
    final ok = await widget.controller.captureCurrentAsHome();
    if (!mounted) return;
    setState(() => _capturingHome = false);
    showTronoToast(
      context,
      ok ? s.homeSavedToast : s.gpsUnavailableToast,
    );
  }

  Future<void> _handleAuthAndComplete() async {
    await showAuthSheet(context, widget.social, initialSignUp: true);
    if (!mounted) return;
    if (widget.social.isSignedIn) {
      await widget.controller.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.social]),
      builder: (context, _) {
        final s = AppStrings.of(context);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      if (_pageIndex > 0)
                        TextButton.icon(
                          onPressed: () => _goToPage(_pageIndex - 1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                          label: Text(
                            s.onboardingBackBtn,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👑', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                s.appName.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.1,
                                  color: TronoColors.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.controller.completeOnboarding,
                        child: Text(
                          s.skipButton,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TronoColors.muted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    children: [
                      _buildWelcomePage(context, s),
                      _buildHomeTerritoryPage(context, s),
                      _buildSoloOrFriendsPage(context, s),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pageCount, (i) {
                          final active = i == _pageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 10,
                            width: active ? 28 : 10,
                            decoration: BoxDecoration(
                              color: active
                                  ? TronoColors.terracotta
                                  : TronoColors.border(context),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      if (_pageIndex < _pageCount - 1) ...[
                        const SizedBox(height: 16),
                        ChunkyButton(
                          width: double.infinity,
                          color: TronoColors.terracotta,
                          lipColor: TronoColors.terracottaLip,
                          onPressed: () => _goToPage(_pageIndex + 1),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                s.onboardingNextBtn.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomePage(BuildContext context, AppStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChunkyCard(
            color: TronoColors.obsidian,
            borderColor: const Color(0xFF343B4D),
            lipColor: TronoColors.obsidianLip,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TronoColors.gold,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: TronoColors.goldLip,
                          width: 2.5,
                        ),
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.onboardingWelcomeBadge.toUpperCase(),
                            style: const TextStyle(
                              color: TronoColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.onboardingWelcomeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  s.onboardingWelcomePitch,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                _HeroPerkRow(
                  icon: Icons.bolt_rounded,
                  color: TronoColors.terracotta,
                  text: s.onboardingPerkOneTap,
                ),
                const SizedBox(height: 8),
                _HeroPerkRow(
                  icon: Icons.shield_rounded,
                  color: TronoColors.sage,
                  text: s.onboardingPerkPrivate,
                ),
                const SizedBox(height: 8),
                _HeroPerkRow(
                  icon: Icons.emoji_events_rounded,
                  color: TronoColors.gold,
                  text: s.onboardingPerkStats,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ChunkyCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      color: TronoColors.terracotta,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.onboardingChooseLang,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'es', label: Text('Español')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {widget.controller.locale.languageCode},
                    onSelectionChanged: (set) =>
                        widget.controller.setLocale(Locale(set.first)),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTerritoryPage(BuildContext context, AppStrings s) {
    final ctrl = widget.controller;
    final hasHome = ctrl.hasHomeLocation;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChunkyCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TronoColors.gold.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: TronoColors.gold,
                          width: 2,
                        ),
                      ),
                      child: const Text('🏠', style: TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.onboardingHomeBadge.toUpperCase(),
                            style: const TextStyle(
                              color: TronoColors.terracotta,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.onboardingHomeTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  s.onboardingHomeBody,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TronoColors.muted(context),
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChunkyCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: Text(
                  s.autoGpsLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(s.autoGpsSub),
                value: ctrl.autoGpsEnabled,
                onChanged: ctrl.setAutoGpsEnabled,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ChunkyButton(
            width: double.infinity,
            color: hasHome ? TronoColors.sage : TronoColors.gold,
            lipColor: hasHome ? TronoColors.sageLip : TronoColors.goldLip,
            onPressed: _capturingHome ? null : _handleCaptureHome,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_capturingHome)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: hasHome ? Colors.white : TronoColors.obsidian,
                    ),
                  )
                else
                  Icon(
                    hasHome
                        ? Icons.check_circle_rounded
                        : Icons.my_location_rounded,
                    color: hasHome ? Colors.white : TronoColors.obsidian,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    hasHome ? s.onboardingHomeSavedBtn : s.setHomeLocationLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: hasHome ? Colors.white : TronoColors.obsidian,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ChunkyCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: TronoColors.sage.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: TronoColors.sage,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.onboardingGpsPrivacyNote,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: TronoColors.muted(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloOrFriendsPage(BuildContext context, AppStrings s) {
    final signedIn = widget.social.isSignedIn;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChunkyCard(
            color: TronoColors.obsidian,
            borderColor: const Color(0xFF343B4D),
            lipColor: TronoColors.obsidianLip,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TronoColors.terracotta,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: TronoColors.terracottaLip,
                      width: 2.5,
                    ),
                  ),
                  child: const Text('👥', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 16),
                Text(
                  s.onboardingSocialBadge.toUpperCase(),
                  style: const TextStyle(
                    color: TronoColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.onboardingSocialTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.onboardingSocialBody,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (signedIn) ...[
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.terracotta,
              lipColor: TronoColors.terracottaLip,
              onPressed: widget.controller.completeOnboarding,
              child: Center(
                child: Text(
                  s.onboardingAlreadySignedInBtn.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.surface(context),
              lipColor: TronoColors.lip(context),
              borderColor: TronoColors.border(context),
              lipHeight: 4,
              onPressed: () async {
                await widget.social.signOut();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: TronoColors.coral,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.signOutBtn,
                    style: const TextStyle(
                      color: TronoColors.coral,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.terracotta,
              lipColor: TronoColors.terracottaLip,
              onPressed: _handleAuthAndComplete,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.group_add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      s.onboardingCreateOrJoinBtn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ChunkyButton(
              width: double.infinity,
              color: TronoColors.surface(context),
              lipColor: TronoColors.lip(context),
              borderColor: TronoColors.border(context),
              onPressed: widget.controller.completeOnboarding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: TronoColors.ink(context),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      s.onboardingStartLocalBtn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TronoColors.ink(context),
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            s.onboardingSocialNote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: TronoColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPerkRow extends StatelessWidget {
  const _HeroPerkRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Tactile 3D push-down button (Duolingo / Opal style).
/// Physically sinks into its bottom lip on press with crisp haptic feedback.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.color,
    required this.lipColor,
    this.borderColor,
    this.lipHeight = 5,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    this.width,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final Color lipColor;
  final Color? borderColor;
  final double lipHeight;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final currentLip = _pressed ? 1.0 : widget.lipHeight;
    final topOffset = _pressed ? (widget.lipHeight - 1.0) : 0.0;

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              HapticFeedback.lightImpact();
              _setPressed(true);
            }
          : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 65),
        curve: Curves.easeOut,
        width: widget.width,
        margin: EdgeInsets.only(top: topOffset),
        padding: EdgeInsets.only(bottom: currentLip),
        decoration: BoxDecoration(
          color: widget.lipColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 2)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Chunky rounded surface card with crisp 2px border and subtle 3D bottom edge.
class ChunkyCard extends StatelessWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.lipColor,
    this.borderRadius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Color? lipColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? TronoColors.surface(context);
    final border = borderColor ?? TronoColors.border(context);
    final lip = lipColor ?? TronoColors.lip(context);

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 2),
      ),
      child: child,
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: lip,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: inner,
              ),
            ),
    );
  }
}

/// Compact HUD pill used in the top bar (streak, XP, etc.).
class ChunkyHudPill extends StatelessWidget {
  const ChunkyHudPill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: TronoColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TronoColors.border(context), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: TronoColors.ink(context),
            ),
          ),
        ],
      ),
    );
  }
}

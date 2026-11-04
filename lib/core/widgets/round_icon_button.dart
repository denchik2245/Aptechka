import 'package:aptechka/core/theme/app_colors.dart';
import 'package:aptechka/core/widgets/glass_surface.dart';
import 'package:flutter/material.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    super.key,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Center(child: icon),
        style: IconButton.styleFrom(
          backgroundColor: primary ? AppColors.primary : Colors.transparent,
          foregroundColor: primary
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          shape: const CircleBorder(),
          side: primary
              ? BorderSide(color: Colors.white.withValues(alpha: 0.2))
              : BorderSide.none,
        ),
      ),
    );
    return primary ? button : GlassSurface(child: button);
  }
}

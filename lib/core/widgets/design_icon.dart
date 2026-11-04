import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original icons exported from the app's Figma file.
class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.name, {
    this.size = 24,
    this.width,
    this.height,
    this.color,
    super.key,
  });

  final String name;
  final double size;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/figma/$name.svg',
    width: width ?? size,
    height: height ?? size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

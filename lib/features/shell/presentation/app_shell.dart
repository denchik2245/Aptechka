import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final branch = navigationShell.currentIndex;
    final selected = branch < 2 ? 0 : branch - 1;
    void select(int index) => navigationShell.goBranch(
      index == 0 ? 0 : index + 1,
      initialLocation: index == selected,
    );
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: selected,
        onSelect: select,
        onSearch: () => context.push('/search'),
      ),
    );
  }
}

/// The three tabs and the separate search button from the Figma tab bar.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.selectedIndex,
    this.onSelect,
    this.onSearch,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final foreground = theme.colorScheme.onSurface;
    void select(int index) {
      if (onSelect != null) {
        onSelect!(index);
      } else {
        context.go(const ['/', '/reminders', '/settings'][index]);
      }
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GlassSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final (index, label, icon) in const [
                          (0, 'Аптечка', 'pharmacy'),
                          (1, 'Лечение', 'treatment'),
                          (2, 'Настройки', 'settings'),
                        ])
                          Expanded(
                            child: Semantics(
                              selected: index == selectedIndex,
                              button: true,
                              label: label,
                              excludeSemantics: true,
                              child: Tooltip(
                                message: label,
                                child: Material(
                                  color: index == selectedIndex
                                      ? (dark
                                            ? const Color(0xFF393A49)
                                            : const Color(0xFFDADCE4)
                                                  .withValues(alpha: 0.9))
                                      : Colors.transparent,
                                  shape: const StadiumBorder(),
                                  child: InkWell(
                                    customBorder: const StadiumBorder(),
                                    onTap: () => select(index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 2,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DesignIcon(
                                            icon,
                                            size: 28,
                                            color: index == selectedIndex
                                                ? primary
                                                : foreground,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            label,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 10,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700,
                                              color: index == selectedIndex
                                                  ? primary
                                                  : foreground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassSurface(
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: IconButton(
                    padding: const EdgeInsets.all(4),
                    onPressed: onSearch ?? () => context.push('/search'),
                    tooltip: 'Поиск',
                    icon: DesignIcon(
                      'search-control',
                      size: 54,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

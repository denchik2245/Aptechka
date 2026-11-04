import 'dart:math' as math;

import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/medicine_group.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_list_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum InventoryFilter { all, expired, expiring, okay, empty }

class PharmacyInventoryScreen extends ConsumerStatefulWidget {
  const PharmacyInventoryScreen({super.key});
  @override
  ConsumerState<PharmacyInventoryScreen> createState() =>
      _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState
    extends ConsumerState<PharmacyInventoryScreen> {
  InventoryFilter _filter = InventoryFilter.all;
  String? _location;
  String? _lastInventoryScope;

  void _clearFilters() => setState(() {
    _filter = InventoryFilter.all;
    _location = null;
  });

  Future<void> _choosePharmacy(AppState state) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Выберите аптечку',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final pharmacy in state.pharmacies)
              ListTile(
                minTileHeight: 56,
                leading: DesignIcon(
                  pharmacy.isShared ? 'forest' : 'home',
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(pharmacy.name),
                trailing: pharmacy.id == state.selectedPharmacyId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, pharmacy.id),
              ),
          ],
        ),
      ),
    );
    if (id == null || !mounted) return;
    await ref.read(appControllerProvider.notifier).selectPharmacy(id);
  }

  Future<void> _chooseLocation(List<String> locations, String? selected) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Место хранения',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              title: const Text('Все места'),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final location in locations)
              ListTile(
                title: Text(location),
                trailing: selected == location ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, location),
              ),
          ],
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _location = value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final loaded = appState.asData?.value;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    RoundIconButton(
                      tooltip: 'Назад к аптечкам',
                      onPressed: () => context.go('/'),
                      icon: DesignIcon(
                        'back',
                        width: 11,
                        height: 19,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: loaded == null
                            ? null
                            : () => _choosePharmacy(loaded),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          loaded?.selectedPharmacy.name ?? 'Аптечка',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 22 / 17,
                            letterSpacing: -0.43,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (loaded?.selectedPharmacy.canEdit == true)
                      RoundIconButton(
                        primary: true,
                        tooltip: 'Добавить упаковку',
                        onPressed: () => context.push('/medicine/select'),
                        icon: const DesignIcon('add'),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final scope = '${state.profileScopeId}:${state.selectedPharmacyId}';
            if (_lastInventoryScope != scope) {
              _lastInventoryScope = scope;
              _filter = InventoryFilter.all;
              _location = null;
            }
            final pharmacy = state.selectedPharmacy;
            final packages = state.medicinesIn(pharmacy.id);
            final locations =
                packages
                    .map((m) => m.location)
                    .where((s) => s.trim().isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final location = locations.contains(_location) ? _location : null;
            final filtered = packages.where((m) {
              if (location != null && m.location != location) return false;
              final status = m.statusAt(
                DateTime.now(),
                warningDays: state.settings.expiryWarningDays,
              );
              return switch (_filter) {
                InventoryFilter.all => true,
                InventoryFilter.expired => status == MedicineStatus.expired,
                InventoryFilter.expiring =>
                  status == MedicineStatus.expiringSoon,
                InventoryFilter.okay => status == MedicineStatus.okay,
                InventoryFilter.empty => m.quantity == 0,
              };
            }).toList();
            final groups = groupMedicines(filtered);
            if (state.settings.inventorySort == InventorySort.expiry) {
              DateTime? nearest(MedicineGroup group) => group.packages
                  .map((m) => m.effectiveExpiryDate)
                  .whereType<DateTime>()
                  .fold<DateTime?>(
                    null,
                    (date, next) =>
                        date == null || next.isBefore(date) ? next : date,
                  );
              groups.sort((a, b) {
                final aDate = nearest(a);
                final bDate = nearest(b);
                if (aDate == null && bDate == null) {
                  return a.name.compareTo(b.name);
                }
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                final byDate = aDate.compareTo(bDate);
                return byDate != 0 ? byDate : a.name.compareTo(b.name);
              });
            }
            final hasFilters =
                _filter != InventoryFilter.all || location != null;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Material(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    _chooseLocation(locations, location),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  child: Row(
                                    children: [
                                      DesignIcon(
                                        'location',
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          location ?? 'Все места',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                height: 22 / 16,
                                                letterSpacing: 0,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Center(
                                          child: Transform.rotate(
                                            angle: math.pi / 2,
                                            child: DesignIcon(
                                              'location-chevron',
                                              width: 7,
                                              height: 12,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _filterChip('Все', InventoryFilter.all),
                                const SizedBox(width: 8),
                                _filterChip(
                                  'Срок истек',
                                  InventoryFilter.expired,
                                  icon: 'status-expired',
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  'Срок истекает',
                                  InventoryFilter.expiring,
                                  icon: 'status-warning',
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  'В норме',
                                  InventoryFilter.okay,
                                  icon: 'status-okay',
                                ),
                                const SizedBox(width: 8),
                                _filterChip(
                                  'Нет в наличии',
                                  InventoryFilter.empty,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),
                        ],
                      ),
                    ),
                    if (groups.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          hasFilters: hasFilters,
                          pharmacyName: pharmacy.name,
                          canEdit: pharmacy.canEdit,
                          onReset: _clearFilters,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        sliver: SliverList.separated(
                          itemCount: groups.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return MedicineListCard(
                              group: group,
                              warningDays: state.settings.expiryWarningDays,
                              onTap: () => context.push(
                                group.packages.length == 1
                                    ? '/medicine/${group.representative.id}'
                                    : '/medicine/group/${group.representative.id}',
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, InventoryFilter filter, {String? icon}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _filter == filter;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DesignIcon(icon, size: 18),
            const SizedBox(width: 5),
          ],
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        height: 19 / 14,
        letterSpacing: 0,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      showCheckmark: false,
      selected: selected,
      side: selected
          ? BorderSide.none
          : BorderSide(color: scheme.outlineVariant),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.pharmacyName,
    required this.canEdit,
    required this.onReset,
  });
  final bool hasFilters;
  final String pharmacyName;
  final bool canEdit;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.inventory_2_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'В этой аптечке ничего не найдено'
                : 'Аптечка «$pharmacyName» пока пуста',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Проверьте фильтры. Возможно, упаковка записана в другой аптечке.'
                : 'Добавьте первую упаковку, чтобы быстро находить её в будущем.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (hasFilters)
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Сбросить фильтры'),
            )
          else if (canEdit)
            FilledButton.icon(
              onPressed: () => context.push('/medicine/select'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить упаковку'),
            ),
        ],
      ),
    ),
  );
}

import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/inventory/domain/medicine_group.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum InventoryFilter { all, expiring, expired, empty }

class PharmacyInventoryScreen extends ConsumerStatefulWidget {
  const PharmacyInventoryScreen({super.key});

  @override
  ConsumerState<PharmacyInventoryScreen> createState() =>
      _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState
    extends ConsumerState<PharmacyInventoryScreen> {
  final _searchController = TextEditingController();
  InventoryFilter _filter = InventoryFilter.all;
  String? _location;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            ...state.pharmacies.map(
              (pharmacy) => ListTile(
                minTileHeight: 56,
                leading: Icon(
                  pharmacy.isShared
                      ? Icons.group_outlined
                      : Icons.home_outlined,
                ),
                title: Text(pharmacy.name),
                subtitle: Text(
                  pharmacy.isShared ? 'Пример общей аптечки' : 'Личная аптечка',
                ),
                trailing: pharmacy.id == state.selectedPharmacyId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, pharmacy.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (id == null || !mounted) return;
    await ref.read(appControllerProvider.notifier).selectPharmacy(id);
    setState(() {
      _searchController.clear();
      _filter = InventoryFilter.all;
      _location = null;
    });
  }

  void _clearFilters() => setState(() {
    _searchController.clear();
    _filter = InventoryFilter.all;
    _location = null;
  });

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final pharmacy = state.selectedPharmacy;
            final allPackages = state.medicinesIn(pharmacy.id);
            final locations =
                allPackages.map((item) => item.location).toSet().toList()
                  ..sort();
            final query = _searchController.text.trim().toLowerCase();
            final filtered = allPackages.where((item) {
              final matchesQuery =
                  query.isEmpty ||
                  item.name.toLowerCase().contains(query) ||
                  (item.activeIngredient?.toLowerCase().contains(query) ??
                      false);
              final matchesLocation =
                  _location == null || item.location == _location;
              final status = item.statusAt(DateTime.now());
              final matchesFilter = switch (_filter) {
                InventoryFilter.all => true,
                InventoryFilter.expiring =>
                  status == MedicineStatus.expiringSoon,
                InventoryFilter.expired => status == MedicineStatus.expired,
                InventoryFilter.empty => item.quantity == 0,
              };
              return matchesQuery && matchesLocation && matchesFilter;
            }).toList();
            final groups = groupMedicines(filtered);
            final hasFilters =
                query.isNotEmpty ||
                _filter != InventoryFilter.all ||
                _location != null;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => _choosePharmacy(state),
                            icon: Icon(
                              pharmacy.isShared
                                  ? Icons.group_outlined
                                  : Icons.home_outlined,
                            ),
                            label: Text(pharmacy.name),
                            iconAlignment: IconAlignment.end,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Содержимое аптечки',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${russianCount(allPackages.length, 'упаковка', 'упаковки', 'упаковок')} · ${russianCount(groupMedicines(allPackages).length, 'препарат', 'препарата', 'препаратов')}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Прототип · данные только на этом устройстве',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: 'Поиск лекарства',
                              hintText: 'Название или вещество',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Очистить поиск',
                                      onPressed: () =>
                                          setState(_searchController.clear),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _filterChip('Все', InventoryFilter.all),
                          _filterChip(
                            'Срок истекает',
                            InventoryFilter.expiring,
                          ),
                          _filterChip('Срок истёк', InventoryFilter.expired),
                          _filterChip('Нет в наличии', InventoryFilter.empty),
                        ],
                      ),
                    ),
                    if (locations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey(state.selectedPharmacyId),
                          initialValue: locations.contains(_location)
                              ? _location
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Место хранения',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Все места'),
                            ),
                            ...locations.map(
                              (place) => DropdownMenuItem<String?>(
                                value: place,
                                child: Text(place),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _location = value),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: groups.isEmpty
                          ? _EmptyState(
                              hasFilters: hasFilters,
                              pharmacyName: pharmacy.name,
                              canEdit: pharmacy.canEdit,
                              onReset: _clearFilters,
                            )
                          : ListView.separated(
                              key: ValueKey(pharmacy.id),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                120,
                              ),
                              itemCount: groups.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return _MedicineGroupCard(
                                  group: group,
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
      floatingActionButton:
          appState.asData?.value.selectedPharmacy.canEdit == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/medicine/new'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить упаковку'),
            )
          : null,
    );
  }

  Widget _filterChip(String label, InventoryFilter filter) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    ),
  );
}

class _MedicineGroupCard extends StatelessWidget {
  const _MedicineGroupCard({required this.group, required this.onTap});

  final MedicineGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = group.packages.length;
    final attention = group.packagesNeedingAttention;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medication_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text('${group.dosage} · ${group.form}'),
                    const SizedBox(height: 10),
                    Text(
                      count == 1
                          ? '${group.representative.quantity} ${group.representative.unit} · ${group.locationSummary}'
                          : '${russianCount(count, 'упаковка', 'упаковки', 'упаковок')} · ${group.locationSummary}',
                    ),
                    if (attention > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${russianCount(attention, 'упаковка', 'упаковки', 'упаковок')} ${attention == 1 ? 'требует' : 'требуют'} проверки срока',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(32),
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
                ? 'Проверьте поиск и фильтры. Возможно, упаковка записана в другой аптечке.'
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
              onPressed: () => context.push('/medicine/new'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить упаковку'),
            ),
        ],
      ),
    ),
  );
}

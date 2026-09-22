import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_card.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum InventoryFilter { all, expiring, expired }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  InventoryFilter _filter = InventoryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Моя аптечка')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medicine/new'),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: SafeArea(
        top: false,
        child: AsyncValueView(
          value: appState,
          data: (state) {
            final query = _searchController.text.trim().toLowerCase();
            final now = DateTime.now();
            final medicines = state.medicines.where((medicine) {
              final matchesQuery =
                  query.isEmpty ||
                  medicine.name.toLowerCase().contains(query) ||
                  (medicine.activeIngredient?.toLowerCase().contains(query) ??
                      false);
              final status = medicine.statusAt(now);
              final matchesFilter = switch (_filter) {
                InventoryFilter.all => true,
                InventoryFilter.expiring =>
                  status == MedicineStatus.expiringSoon,
                InventoryFilter.expired => status == MedicineStatus.expired,
              };
              return matchesQuery && matchesFilter;
            }).toList()..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'Поиск по названию или веществу',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Все',
                            selected: _filter == InventoryFilter.all,
                            onTap: () =>
                                setState(() => _filter = InventoryFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Скоро истекут',
                            selected: _filter == InventoryFilter.expiring,
                            onTap: () => setState(
                              () => _filter = InventoryFilter.expiring,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Просрочены',
                            selected: _filter == InventoryFilter.expired,
                            onTap: () => setState(
                              () => _filter = InventoryFilter.expired,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: medicines.isEmpty
                          ? _EmptyInventory(
                              hasQuery:
                                  query.isNotEmpty ||
                                  _filter != InventoryFilter.all,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                104,
                              ),
                              itemCount: medicines.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final medicine = medicines[index];
                                return MedicineCard(
                                  medicine: medicine,
                                  onTap: () =>
                                      context.push('/medicine/${medicine.id}'),
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.medication_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'Ничего не найдено' : 'Аптечка пока пуста',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Измените запрос или фильтр.'
                  : 'Добавьте первый препарат вручную или по коду на упаковке.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

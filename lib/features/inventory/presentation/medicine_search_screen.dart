import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/medicine_group.dart';
import 'package:aptechka/features/inventory/presentation/widgets/medicine_list_card.dart';
import 'package:aptechka/features/shell/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MedicineSearchScreen extends ConsumerStatefulWidget {
  const MedicineSearchScreen({super.key});
  @override
  ConsumerState<MedicineSearchScreen> createState() =>
      _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends ConsumerState<MedicineSearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Поиск')),
    bottomNavigationBar: AppNavigationBar(
      selectedIndex: 0,
      onSearch: _focus.requestFocus,
    ),
    body: SafeArea(
      top: false,
      child: AsyncValueView(
        value: ref.watch(appControllerProvider),
        data: (state) {
          final query = _query.text.trim().toLowerCase();
          final results = <({MedicineGroup group, String pharmacy})>[
            for (final pharmacy in state.pharmacies)
              for (final group in groupMedicines(
                state
                    .medicinesIn(pharmacy.id)
                    .where(
                      (m) =>
                          query.isEmpty ||
                          '${m.name} ${m.activeIngredient ?? ''} ${m.manufacturer ?? ''}'
                              .toLowerCase()
                              .contains(query),
                    )
                    .toList(),
              ))
                (group: group, pharmacy: pharmacy.name),
          ];
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _query,
                      focusNode: _focus,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Поиск по вашим аптечкам',
                        hintText: 'Название, вещество или производитель',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(16),
                          child: DesignIcon('search-small', size: 20),
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Очистить поиск',
                                onPressed: () => setState(_query.clear),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text('Ничего не найдено'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return MedicineListCard(
                                group: item.group,
                                pharmacyName: item.pharmacy,
                                warningDays: state.settings.expiryWarningDays,
                                onTap: () => context.push(
                                  item.group.packages.length == 1
                                      ? '/medicine/${item.group.representative.id}'
                                      : '/medicine/group/${item.group.representative.id}',
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

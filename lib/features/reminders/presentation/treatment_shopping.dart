import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'treatment_widgets.dart';

Future<void> showTreatmentShopping(
  BuildContext context,
  WidgetRef ref,
  Iterable<String> ids,
) async {
  final controller = ref.read(appControllerProvider.notifier);
  final current = ref.read(appControllerProvider).requireValue;
  await treatmentAction(
    context,
    () => controller.setTreatmentShopping({
      ...current.treatmentShoppingIds,
      ...ids,
    }),
  );
  if (!context.mounted) return;
  await treatmentSheet(
    context,
    'Список покупок',
    Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(appControllerProvider).requireValue;
        final medicines = state.medicines
            .where((m) => state.treatmentShoppingIds.contains(m.id))
            .toList();
        if (medicines.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Все покупки отмечены'),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: medicines
              .map(
                (m) => CheckboxListTile(
                  value: false,
                  title: Text(medicineTitle(m)),
                  subtitle: Text('В аптечке: ${m.quantity} ${m.unit}'),
                  onChanged: (_) => treatmentAction(
                    context,
                    () => controller.setTreatmentShopping(
                      state.treatmentShoppingIds
                          .where((id) => id != m.id)
                          .toSet(),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

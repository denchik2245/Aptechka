import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'treatment_widgets.dart';

Future<void> showIntakeAction(
  BuildContext context,
  WidgetRef ref,
  TreatmentIntake intake, {
  String mode = 'edit',
}) async {
  var choice = mode == 'defer'
      ? 'На 15 минут'
      : mode == 'skip'
      ? 'Нет лекарства под рукой'
      : 'Принял по плану, в ${intake.reminder.timeLabel}';
  var time = TimeOfDay.fromDateTime(
    intake.record?.occurredAt ?? intake.plannedAt,
  );
  final title = mode == 'defer'
      ? 'Отложить приём'
      : mode == 'skip'
      ? 'Пропустить приём?'
      : 'Приём в ${intake.reminder.timeLabel}';
  var saving = false;
  await treatmentSheet(
    context,
    title,
    StatefulBuilder(
      builder: (sheetContext, setState) {
        final choices = mode == 'defer'
            ? [
                'На 15 минут',
                'На 30 минут',
                'На 1 час',
                'На 2 часа',
                'Своё время',
              ]
            : mode == 'skip'
            ? [
                'Нет лекарства под рукой',
                'Плохое самочувствие',
                'Врач отменил или изменил схему',
                'Другая причина',
              ]
            : [
                'Принял по плану, в ${intake.reminder.timeLabel}',
                'Принял в другое время',
                'Не принимал',
              ];
        Future<void> save() async {
          setState(() => saving = true);
          try {
            final now = DateTime.now();
            final actual = DateTime(
              intake.date.year,
              intake.date.month,
              intake.date.day,
              time.hour,
              time.minute,
            );
            if (mode != 'defer' &&
                mode != 'skip' &&
                choice != 'Не принимал' &&
                actual.isAfter(now)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Время приёма ещё не наступило')),
              );
              setState(() => saving = false);
              return;
            }
            DateTime? until;
            if (mode == 'defer') {
              final minutes = {
                'На 15 минут': 15,
                'На 30 минут': 30,
                'На 1 час': 60,
                'На 2 часа': 120,
              }[choice];
              until = minutes != null
                  ? now.add(Duration(minutes: minutes))
                  : DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
              if (!until.isAfter(now)) {
                until = until.add(const Duration(days: 1));
              }
            }
            await ref
                .read(appControllerProvider.notifier)
                .recordIntake(
                  intake.reminder.id,
                  mode == 'defer'
                      ? IntakeStatus.deferred
                      : mode == 'skip' || choice == 'Не принимал'
                      ? IntakeStatus.skipped
                      : IntakeStatus.taken,
                  scheduledDate: intake.date,
                  occurredAt: mode == 'edit' ? actual : now,
                  reason: mode == 'skip' ? choice : '',
                  deferredUntil: until,
                );
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (sheetContext.mounted) {
              setState(() => saving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Не удалось сохранить отметку')),
              );
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...choices.map(
              (label) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(label, style: const TextStyle(fontSize: 16)),
                trailing: Icon(
                  choice == label ? Icons.check_circle : Icons.circle_outlined,
                  color: choice == label
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                onTap: () async {
                  setState(() => choice = label);
                  if (label == 'Своё время') {
                    final result = await showTimePicker(
                      context: sheetContext,
                      initialTime: time,
                    );
                    if (result != null && sheetContext.mounted) {
                      setState(() => time = result);
                    }
                  }
                },
              ),
            ),
            if (choice == 'Принял в другое время' || choice == 'Своё время')
              TreatmentSelect(
                'Время приёма',
                time.format(context),
                onTap: () async {
                  final result = await showTimePicker(
                    context: sheetContext,
                    initialTime: time,
                  );
                  if (result != null && sheetContext.mounted) {
                    setState(() => time = result);
                  }
                },
              ),
            const SizedBox(height: 12),
            Text(
              mode == 'skip'
                  ? 'Пропуск сохранится в истории курса, остаток в аптечке не изменится'
                  : mode == 'defer'
                  ? 'Приём останется в расписании с новым временем'
                  : 'Отметка сохранится в истории. Остаток уменьшится, если единицы дозы и упаковки совпадают.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TreatmentButton(
              mode == 'defer'
                  ? 'Отложить'
                  : mode == 'skip'
                  ? 'Пропустить'
                  : 'Сохранить',
              onPressed: saving ? null : save,
            ),
            if (mode == 'skip')
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Отмена'),
              ),
          ],
        );
      },
    ),
    subtitle: '${medicineTitle(intake.medicine)} · ${intake.reminder.dose}',
  );
}

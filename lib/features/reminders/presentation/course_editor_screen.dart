import 'dart:convert';

import 'package:aptechka/core/utils/russian_count.dart';

import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:aptechka/features/reminders/domain/medication_reminder.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'treatment_widgets.dart';
import 'course_detail_screen.dart';
import 'treatment_shopping.dart';

class CourseEditorScreen extends ConsumerStatefulWidget {
  const CourseEditorScreen({this.editId, this.repeatId, super.key});
  final String? editId, repeatId;
  @override
  ConsumerState<CourseEditorScreen> createState() => _CourseEditorState();
}

class _CourseEditorState extends ConsumerState<CourseEditorScreen> {
  final name = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final uuid = const Uuid();
  late String id;
  int step = 0;
  String person = 'Я';
  DateTime start = treatmentDay(DateTime.now());
  int? duration = 7;
  String? prescription;
  bool notifications = true,
      stockAlert = true,
      notifyFamily = false,
      saving = false,
      initialized = false;
  int repeatMinutes = 10;
  String visibility = 'Только я';
  List<MedicationReminder> reminders = [];
  final people = <String>{'Я', 'Мама', 'Миша'};
  TreatmentCourse? original;
  @override
  void initState() {
    super.initState();
    id = widget.editId ?? uuid.v4();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  TreatmentCourse get draft => TreatmentCourse(
    id: id,
    name: name.text.trim(),
    person: person,
    startsAt: start,
    durationDays: duration,
    notifications: notifications,
    repeatMinutes: repeatMinutes,
    stockAlert: stockAlert,
    notifyFamily: notifyFamily,
    visibility: visibility,
    prescription: prescription,
    status: original?.status ?? CourseStatus.active,
    completedAt: original?.completedAt,
  );
  void initialize(AppState state) {
    if (initialized) return;
    initialized = true;
    people.addAll(state.courses.map((c) => c.person));
    final source = state.courses
        .where((c) => c.id == (widget.editId ?? widget.repeatId))
        .firstOrNull;
    if (source == null) return;
    original = widget.editId != null ? source : null;
    name.text = source.name;
    person = source.person;
    start = widget.editId != null
        ? source.startsAt
        : treatmentDay(DateTime.now());
    duration = source.durationDays;
    prescription = source.prescription;
    notifications = source.notifications;
    repeatMinutes = source.repeatMinutes;
    stockAlert = source.stockAlert;
    notifyFamily = source.notifyFamily;
    visibility = source.visibility;
    reminders = TreatmentSchedule.courseReminders(state, source.id)
        .map(
          (r) => r.copyWith(
            id: widget.repeatId != null ? uuid.v4() : r.id,
            courseId: id,
          ),
        )
        .toList();
  }

  Future<void> leave() async {
    if (step > 0) {
      setState(() => step--);
      return;
    }
    if (name.text.isEmpty && reminders.isEmpty && prescription == null ||
        await treatmentConfirm(
          context,
          'Выйти без сохранения?',
          'Изменения курса не сохранятся.',
          'Выйти',
        )) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/reminders');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).asData?.value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    initialize(state);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: TreatmentPage(
        title: widget.editId == null ? 'Новый курс' : 'Изменить курс',
        onBack: leave,
        children: [
          Text(
            'Шаг ${step + 1} из 3 · ${const ['Основное', 'Препараты', 'Напоминания'][step]}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 4,
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
          if (step == 0) ...basic(),
          if (step == 1) ...medicines(state),
          if (step == 2) ...settings(state),
          const SizedBox(height: 24),
          TreatmentButton(
            step == 2
                ? widget.editId == null
                      ? 'Создать курс'
                      : 'Сохранить курс'
                : 'Далее',
            onPressed: saving ? null : () => next(state),
          ),
        ],
      ),
    );
  }

  List<Widget> basic() => [
    const TreatmentSection('Для кого'),
    TreatmentChips(
      values: [...people, '+ Добавить'],
      selected: {person},
      onSelected: (v) async {
        if (v == '+ Добавить') {
          final controller = TextEditingController();
          final result = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Имя близкого'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, controller.text.trim()),
                  child: const Text('Добавить'),
                ),
              ],
            ),
          );
          // The dialog route owns the field until its reverse animation ends.
          if (result != null && result.isNotEmpty && mounted) {
            setState(() {
              people.add(result);
              person = result;
            });
          }
        } else {
          setState(() => person = v);
        }
      },
    ),
    const TreatmentSection('Название'),
    Form(
      key: formKey,
      child: TextFormField(
        controller: name,
        decoration: const InputDecoration(hintText: 'Например, «Простуда» *'),
        textCapitalization: TextCapitalization.sentences,
        maxLength: 80,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Введите название курса' : null,
      ),
    ),
    const TreatmentSection('Сроки'),
    TreatmentSelect(
      'Начало *',
      treatmentDate(start),
      onTap: () async {
        final result = await showDatePicker(
          context: context,
          initialDate: start,
          firstDate: DateTime(2020),
          lastDate: DateTime(DateTime.now().year + 10),
        );
        if (result != null && mounted) setState(() => start = result);
      },
    ),
    TreatmentChips(
      values: const [
        '5 дней',
        '7 дней',
        '10 дней',
        '14 дней',
        'Свой срок',
        'Постоянно',
      ],
      selected: {
        duration == null
            ? 'Постоянно'
            : [5, 7, 10, 14].contains(duration)
            ? '$duration дней'
            : 'Свой срок',
      },
      onSelected: (v) async {
        if (v == 'Постоянно') {
          setState(() => duration = null);
        } else if (v == 'Свой срок') {
          final value = await chooseNumber(
            context,
            'Длительность курса, дней',
            duration ?? 7,
            1,
            3650,
          );
          if (value != null && mounted) setState(() => duration = value);
        } else {
          setState(() => duration = int.parse(v.split(' ').first));
        }
      },
    ),
    const SizedBox(height: 12),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        duration == null
            ? 'Без даты окончания'
            : 'Курс закончится ${treatmentDate(DateTime(start.year, start.month, start.day + duration! - 1))}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
    const TreatmentSection('Назначение врача'),
    const Text('Необязательно. Сохраним фото, чтобы назначение не потерялось'),
    const SizedBox(height: 12),
    Material(
      color: secondaryFill(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: attach,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (prescription == null)
                const DesignIcon('treatment-photo-32', size: 36)
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(prescription!.split(',').last),
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                prescription == null
                    ? 'Прикрепить фото назначения'
                    : 'Заменить фото назначения',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    if (prescription != null)
      TextButton(
        onPressed: () => setState(() => prescription = null),
        child: const Text('Удалить фото'),
      ),
  ];
  Future<void> attach() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Фотографии',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
            uniformTypeIdentifiers: [
              'public.jpeg',
              'public.png',
              'org.webmproject.webp',
            ],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите фото размером до 4 МБ')),
          );
        }
        return;
      }
      final codec = await decodeImageFromList(bytes);
      codec.dispose();
      final extension = file.name.split('.').last.toLowerCase();
      final mime = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
          ? 'image/webp'
          : 'image/jpeg';
      if (mounted) {
        setState(
          () => prescription = 'data:$mime;base64,${base64Encode(bytes)}',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть фото. Выберите JPG или PNG.'),
          ),
        );
      }
    }
  }

  List<Widget> medicines(AppState state) => [
    TreatmentSection(
      'Препараты в курсе · ${reminders.map((r) => r.medicineId).toSet().length}',
    ),
    for (final mid in reminders.map((r) => r.medicineId).toSet()) ...[
      CourseDrugCard(
        state: state,
        reminders: reminders.where((r) => r.medicineId == mid).toList(),
        onEdit: () => editDrug(state, mid),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () =>
              setState(() => reminders.removeWhere((r) => r.medicineId == mid)),
          child: const Text('Убрать из курса'),
        ),
      ),
    ],
    TreatmentButton(
      '+ Добавить препарат',
      secondary: true,
      onPressed: () => addDrug(state),
    ),
    if (stockWarning(
          state.copyWith(
            reminders: [
              ...state.reminders.where((r) => r.courseId != id),
              ...reminders,
            ],
          ),
          draft,
        )
        case final String warning) ...[
      const SizedBox(height: 16),
      TreatmentBanner(
        'Не хватит на курс',
        warning,
        action: 'В список покупок',
        onAction: () => showTreatmentShopping(
          context,
          ref,
          reminders.map((r) => r.medicineId),
        ),
      ),
    ],
    const SizedBox(height: 16),
    if (reminders.isEmpty)
      const Text('Выберите препарат из своей аптечки и задайте схему приёма.'),
  ];
  Future<Medicine?> pickMedicine(AppState state) async {
    var query = '';
    return treatmentSheet<Medicine>(
      context,
      'Препарат из аптечки',
      StatefulBuilder(
        builder: (sheetContext, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по аптечке',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setSheet(() => query = v.toLowerCase().trim()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .4,
              child: ListView(
                children: [
                  for (final m in state.medicines.where(
                    (m) => m.name.toLowerCase().contains(query),
                  ))
                    ListTile(
                      leading: TreatmentDrugIcon(m),
                      title: Text(medicineTitle(m)),
                      subtitle: Text(
                        '${m.quantity} ${m.unit} · ${state.pharmacies.where((p) => p.id == m.pharmacyId).firstOrNull?.name ?? ''}',
                      ),
                      onTap: () => Navigator.pop(sheetContext, m),
                    ),
                  if (state.medicines
                      .where((m) => m.name.toLowerCase().contains(query))
                      .isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Препараты не найдены'),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/medicine/select');
              },
              child: const Text('+ Нет в аптечке — добавить новое'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addDrug(AppState state) async {
    final m = await pickMedicine(state);
    if (m == null || !mounted) return;
    if (reminders.any((r) => r.medicineId == m.id)) {
      await editDrug(state, m.id);
      return;
    }
    final result = await Navigator.of(context).push<List<MedicationReminder>>(
      MaterialPageRoute(
        builder: (_) =>
            RegimenEditorScreen(medicine: m, course: draft, existing: const []),
      ),
    );
    if (result != null && mounted) setState(() => reminders.addAll(result));
  }

  Future<void> editDrug(AppState state, String mid) async {
    final m = state.medicines.where((m) => m.id == mid).firstOrNull;
    if (m == null) return;
    final result = await Navigator.of(context).push<List<MedicationReminder>>(
      MaterialPageRoute(
        builder: (_) => RegimenEditorScreen(
          medicine: m,
          course: draft,
          existing: reminders.where((r) => r.medicineId == mid).toList(),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => reminders = [
          ...reminders.where((r) => r.medicineId != mid),
          ...result,
        ],
      );
    }
  }

  List<Widget> settings(AppState state) => [
    const SizedBox(height: 24),
    TreatmentCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('${coursePerson(draft)} · ${courseDates(draft)}'),
            const SizedBox(height: 16),
            for (final mid in reminders.map((r) => r.medicineId).toSet())
              Builder(
                builder: (context) {
                  final rs = reminders
                      .where((r) => r.medicineId == mid)
                      .toList();
                  final m = state.medicines
                      .where((m) => m.id == mid)
                      .firstOrNull;
                  return m == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              TreatmentDrugIcon(m),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicineTitle(m),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${rs.first.dose} · ${rs.map((r) => r.timeLabel).join(', ')} · ${frequencyLabel(rs.first)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                },
              ),
          ],
        ),
      ),
    ),
    const TreatmentSection('Напоминания'),
    TreatmentSwitch(
      'Напоминать о приёме',
      notifications,
      onChanged: (v) => setState(() => notifications = v),
    ),
    TreatmentSelect(
      'Повтор',
      repeatMinutes == 0 ? 'Без повтора' : 'Через $repeatMinutes минут',
      onTap: () async {
        final v = await treatmentChoice(context, 'Повтор', const [
          'Без повтора',
          'Через 5 минут',
          'Через 10 минут',
          'Через 15 минут',
          'Через 30 минут',
        ], 'Через $repeatMinutes минут');
        if (v != null && mounted) {
          setState(
            () => repeatMinutes =
                int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
          );
        }
      },
    ),
    TreatmentSwitch(
      'Предупредить, когда запас на 3 дня',
      stockAlert,
      onChanged: (v) => setState(() => stockAlert = v),
    ),
    const TreatmentSection('Близкие'),
    TreatmentSwitch(
      'Сообщать о пропуске приёма',
      notifyFamily,
      onChanged: (v) => setState(() => notifyFamily = v),
    ),
    const Text('Например, чтобы вы знали, если мама пропустит приём'),
    const SizedBox(height: 8),
    TreatmentSelect(
      'Кто видит курс',
      visibility,
      onTap: () async {
        final v = await treatmentChoice(context, 'Кто видит курс', [
          'Только я',
          ...people.where((p) => p != 'Я'),
        ], visibility);
        if (v != null && mounted) setState(() => visibility = v);
      },
    ),
    const Text(
      'Общая аптечка остаётся общей, а курсы и назначения видите только вы и те, кого вы добавите',
    ),
    const SizedBox(height: 12),
    Text(
      'В прототипе настройки сохраняются локально. Системные уведомления и отправка близким пока не подключены.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ];
  Future<void> next(AppState state) async {
    if (step == 0) {
      if (!formKey.currentState!.validate()) return;
      setState(() => step = 1);
      return;
    }
    if (step == 1) {
      if (reminders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавьте хотя бы один препарат')),
        );
        return;
      }
      setState(() => step = 2);
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .saveCourse(draft, reminders);
      if (mounted) context.go('/treatment/course/$id');
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось сохранить курс. Проверьте препараты и повторите.',
            ),
          ),
        );
      }
    }
  }
}

Future<int?> chooseNumber(
  BuildContext context,
  String title,
  int value,
  int min,
  int max,
) async {
  final controller = TextEditingController(text: '$value');
  String? error;
  return showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(errorText: error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n == null || n < min || n > max) {
                setState(() => error = 'Введите число от $min до $max');
                return;
              }
              Navigator.pop(c, n);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    ),
  );
}

class RegimenEditorScreen extends StatefulWidget {
  const RegimenEditorScreen({
    required this.medicine,
    required this.course,
    required this.existing,
    super.key,
  });
  final Medicine medicine;
  final TreatmentCourse course;
  final List<MedicationReminder> existing;
  @override
  State<RegimenEditorScreen> createState() => _RegimenEditorState();
}

class _RegimenEditorState extends State<RegimenEditorScreen> {
  late Medicine medicine;
  int amount = 1, cycleDays = 60, breakDays = 30;
  String unit = 'таблетка', condition = 'После еды';
  final hint = TextEditingController();
  IntakeFrequency frequency = IntakeFrequency.daily;
  Set<int> weekdays = {1, 3, 5};
  List<TimeOfDay> times = [const TimeOfDay(hour: 8, minute: 0)];
  int? duration;
  @override
  void initState() {
    super.initState();
    medicine = widget.medicine;
    final r = widget.existing.firstOrNull;
    if (r != null) {
      amount = r.amount;
      unit = r.unit;
      condition = r.condition.isEmpty
          ? 'Независимо от еды'
          : '${r.condition[0].toUpperCase()}${r.condition.substring(1)}';
      hint.text = r.hint;
      frequency = r.frequency;
      weekdays = r.weekdays.toSet();
      cycleDays = r.cycleDays;
      breakDays = r.breakDays;
      duration = r.durationDays;
      times = widget.existing
          .map((r) => TimeOfDay(hour: r.hour, minute: r.minute))
          .toList();
    } else {
      unit = medicine.unit.startsWith('капсул')
          ? 'капсула'
          : medicine.form.toLowerCase().contains('капл')
          ? 'капля'
          : const {
                  'таблеток': 'таблетка',
                  'таблетки': 'таблетка',
                  'капсул': 'капсула',
                  'флаконов': 'флакон',
                  'флакона': 'флакон',
                }[medicine.unit] ??
                medicine.unit;
    }
  }

  @override
  void dispose() {
    hint.dispose();
    super.dispose();
  }

  List<MedicationReminder> get result => times.map((t) {
    final old = widget.existing
        .where((r) => r.hour == t.hour && r.minute == t.minute)
        .firstOrNull;
    return MedicationReminder(
      id: old?.id ?? const Uuid().v4(),
      medicineId: medicine.id,
      courseId: widget.course.id,
      hour: t.hour,
      minute: t.minute,
      dose: doseLabel(amount, unit),
      amount: amount,
      unit: unit,
      condition: condition.toLowerCase(),
      hint: hint.text.trim(),
      enabled: true,
      frequency: frequency,
      weekdays: weekdays.toList()..sort(),
      cycleDays: cycleDays,
      breakDays: breakDays,
      durationDays: duration,
    );
  }).toList();
  @override
  Widget build(BuildContext context) {
    final end = duration == null
        ? widget.course.endsAt
        : DateTime(
            widget.course.startsAt.year,
            widget.course.startsAt.month,
            widget.course.startsAt.day + duration! - 1,
          );
    final needed = end == null
        ? null
        : TreatmentSchedule.requiredStock(
            result,
            widget.course.startsAt,
            end,
            widget.course.startsAt,
          );
    final comparable = unit.toLowerCase().startsWith(
      medicine.unit.toLowerCase().substring(
        0,
        medicine.unit.length < 3 ? medicine.unit.length : 3,
      ),
    );
    return TreatmentPage(
      title: 'Схема приёма',
      children: [
        TreatmentCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TreatmentDrugIcon(medicine),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineTitle(medicine),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'В аптечке: ${medicine.quantity} ${medicine.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final chosen = await treatmentSheet<Medicine>(
                      context,
                      'Заменить препарат',
                      Consumer(
                        builder: (c, ref, _) {
                          final ms =
                              ref
                                  .watch(appControllerProvider)
                                  .asData
                                  ?.value
                                  .medicines ??
                              [];
                          return SizedBox(
                            height: 300,
                            child: ListView(
                              children: ms
                                  .map(
                                    (m) => ListTile(
                                      title: Text(medicineTitle(m)),
                                      onTap: () => Navigator.pop(c, m),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                    );
                    if (chosen != null && mounted) {
                      setState(() => medicine = chosen);
                    }
                  },
                  child: const Text('Заменить'),
                ),
              ],
            ),
          ),
        ),
        const TreatmentSection('Доза'),
        _counter('Доза:', amount, 1, 100, (v) => setState(() => amount = v)),
        TreatmentSelect(
          'Единица',
          unit,
          onTap: () async {
            final v = await treatmentChoice(
              context,
              'Единица',
              {
                'таблетка',
                'капсула',
                'капля',
                'мл',
                'доза',
                'пакетик',
                'флакон',
                medicine.unit,
                unit,
              }.toList(),
              unit,
            );
            if (v != null && mounted) setState(() => unit = v);
          },
        ),
        const TreatmentSection('Как часто'),
        TreatmentChips(
          values: const [
            'Каждый день',
            'Через день',
            'По дням недели',
            'Циклами',
          ],
          selected: {
            const [
              'Каждый день',
              'Через день',
              'По дням недели',
              'Циклами',
            ][frequency.index],
          },
          onSelected: (v) => setState(
            () => frequency =
                IntakeFrequency.values[const [
                  'Каждый день',
                  'Через день',
                  'По дням недели',
                  'Циклами',
                ].indexOf(v)],
          ),
        ),
        if (frequency == IntakeFrequency.weekdays) ...[
          const SizedBox(height: 12),
          TreatmentChips(
            values: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
            selected: weekdays
                .map(
                  (d) =>
                      const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][d - 1],
                )
                .toSet(),
            onSelected: (v) => setState(() {
              final d =
                  const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].indexOf(v) +
                  1;
              if (weekdays.contains(d)) {
                weekdays.remove(d);
              } else {
                weekdays.add(d);
              }
            }),
          ),
        ],
        if (frequency == IntakeFrequency.cycles) ...[
          const SizedBox(height: 12),
          _counter(
            'Принимать, дней:',
            cycleDays,
            1,
            365,
            (v) => setState(() => cycleDays = v),
          ),
          _counter(
            'Перерыв, дней:',
            breakDays,
            1,
            365,
            (v) => setState(() => breakDays = v),
          ),
        ],
        const TreatmentSection('Время приёма'),
        for (var i = 0; i < times.length; i++)
          Row(
            children: [
              Expanded(
                child: TreatmentSelect(
                  'Приём ${i + 1}',
                  times[i].format(context),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: times[i],
                    );
                    if (t != null && mounted) setState(() => times[i] = t);
                  },
                ),
              ),
              if (times.length > 1)
                IconButton(
                  tooltip: 'Убрать время ${i + 1}',
                  onPressed: () => setState(() => times.removeAt(i)),
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
        if (times.length < 12)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 13, minute: 0),
                );
                if (t != null && mounted) setState(() => times.add(t));
              },
              child: const Text('+ Добавить время'),
            ),
          ),
        const TreatmentSection('Условие'),
        TreatmentChips(
          values: const [
            'До еды',
            'Во время еды',
            'После еды',
            'Независимо от еды',
          ],
          selected: {condition},
          onSelected: (v) => setState(() => condition = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: hint,
          decoration: const InputDecoration(
            labelText: 'Подсказка',
            hintText: 'Например, запейте стаканом воды',
          ),
          maxLength: 200,
        ),
        const TreatmentSection('Сколько принимать'),
        TreatmentSelect(
          'Длительность',
          duration == null
              ? 'Весь курс${widget.course.durationDays == null ? '' : ' — ${widget.course.durationDays} дней'}'
              : '$duration дней',
          onTap: () async {
            final v = await treatmentChoice(context, 'Длительность', [
              'Весь курс',
              '5 дней',
              '7 дней',
              '10 дней',
              '14 дней',
              '30 дней',
              'Свой срок',
            ], duration == null ? 'Весь курс' : '$duration дней');
            if (v == null || !mounted) return;
            if (v == 'Свой срок') {
              final d = await chooseNumber(
                this.context,
                'Длительность, дней',
                duration ?? 7,
                1,
                3650,
              );
              if (d != null && mounted) setState(() => duration = d);
            } else {
              setState(
                () => duration = v == 'Весь курс'
                    ? null
                    : int.parse(v.split(' ').first),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        if (comparable && needed != null)
          TreatmentBanner(
            needed > medicine.quantity
                ? 'Не хватит на весь курс'
                : 'Запаса хватит на весь курс',
            'Нужно $needed $unit, в аптечке ${medicine.quantity} ${medicine.unit}${needed > medicine.quantity ? '. Докупите ещё ${needed - medicine.quantity}' : ''}',
            success: needed <= medicine.quantity,
          )
        else
          TreatmentBanner(
            'Остаток в аптечке',
            '${medicine.quantity} ${medicine.unit}. Для расчёта запаса нужны одинаковые единицы дозы и остатка.',
          ),
        const SizedBox(height: 24),
        TreatmentButton(
          'Сохранить препарат',
          onPressed: () {
            if (frequency == IntakeFrequency.weekdays && weekdays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Выберите хотя бы один день недели'),
                ),
              );
              return;
            }
            if (times.map((t) => t.hour * 60 + t.minute).toSet().length !=
                times.length) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Время приёмов не должно повторяться'),
                ),
              );
              return;
            }
            times.sort(
              (a, b) =>
                  (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
            );
            Navigator.pop(context, result);
          },
        ),
      ],
    );
  }

  Widget _counter(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              final v = await chooseNumber(context, label, value, min, max);
              if (v != null && mounted) update(v);
            },
            child: Text('$value'),
          ),
          IconButton(
            tooltip: 'Уменьшить $label',
            onPressed: value > min ? () => update(value - 1) : null,
            icon: const DesignIcon('quantity-minus', size: 44),
          ),
          IconButton(
            tooltip: 'Увеличить $label',
            onPressed: value < max ? () => update(value + 1) : null,
            icon: const DesignIcon('quantity-plus', size: 44),
          ),
        ],
      ),
    ),
  );
}

String doseLabel(int amount, String unit) {
  final forms = <String, List<String>>{
    'таблетка': ['таблетка', 'таблетки', 'таблеток'],
    'капсула': ['капсула', 'капсулы', 'капсул'],
    'капля': ['капля', 'капли', 'капель'],
    'доза': ['доза', 'дозы', 'доз'],
    'пакетик': ['пакетик', 'пакетика', 'пакетиков'],
    'флакон': ['флакон', 'флакона', 'флаконов'],
  };
  final f = forms[unit];
  if (f == null) return '$amount $unit';
  return russianCount(amount, f[0], f[1], f[2]);
}

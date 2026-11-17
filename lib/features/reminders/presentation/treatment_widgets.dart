import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/core/utils/drug_text.dart';
import 'package:aptechka/features/medicines/domain/medicine.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String treatmentDate(DateTime day) =>
    '${day.day} ${const ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'][day.month - 1]}';
String medicineTitle(Medicine m) =>
    '${readableDrugName(m.name)}${m.dosage.isEmpty ? '' : ', ${m.dosage}'}';
String timeText(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
Color secondaryFill(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF393A49)
    : const Color(0xFFD6DAE3);

class TreatmentPage extends StatelessWidget {
  const TreatmentPage({
    required this.title,
    required this.children,
    this.onBack,
    this.bottomBar,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? bottomBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: bottomBar,
    body: DefaultTextStyle.merge(
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        RoundIconButton(
                          tooltip: 'Назад',
                          icon: const DesignIcon('back'),
                          onPressed:
                              onBack ??
                              () => context.canPop()
                                  ? context.pop()
                                  : context.go('/reminders'),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TreatmentCard extends StatelessWidget {
  const TreatmentCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      child: child,
    ),
  );
}

class TreatmentSection extends StatelessWidget {
  const TreatmentSection(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class TreatmentButton extends StatelessWidget {
  const TreatmentButton(
    this.label, {
    required this.onPressed,
    this.secondary = false,
    this.danger = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, danger;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 60),
        backgroundColor: danger
            ? Colors.transparent
            : secondary
            ? secondaryFill(context)
            : null,
        foregroundColor: danger
            ? Theme.of(context).colorScheme.error
            : secondary
            ? Theme.of(context).colorScheme.onSurface
            : null,
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class TreatmentSelect extends StatelessWidget {
  const TreatmentSelect(
    this.label,
    this.value, {
    required this.onTap,
    this.trailing,
    super.key,
  });
  final String label, value;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              trailing ?? const Icon(Icons.unfold_more, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

class TreatmentSwitch extends StatelessWidget {
  const TreatmentSwitch(
    this.label,
    this.value, {
    required this.onChanged,
    super.key,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}

class TreatmentChips extends StatelessWidget {
  const TreatmentChips({
    required this.values,
    required this.selected,
    required this.onSelected,
    this.horizontal = false,
    super.key,
  });
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    final chips = values.map((v) {
      final active = selected.contains(v);
      return Material(
        color: active
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: StadiumBorder(
          side: active
              ? BorderSide.none
              : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onSelected(v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              v,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active
                    ? Theme.of(context).colorScheme.surfaceContainerLowest
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }).toList();
    return horizontal
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: 8, children: chips),
          )
        : Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class TreatmentDrugIcon extends StatelessWidget {
  const TreatmentDrugIcon(this.medicine, {this.large = false, super.key});
  final Medicine medicine;
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? 48 : 40,
    height: large ? 48 : 40,
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: DesignIcon(
      'treatment-${medicine.form.toLowerCase().contains('капл') || medicine.form.toLowerCase().contains('раствор')
          ? 'drops-20'
          : large
          ? 'pill-24'
          : 'pill-20'}',
      size:
          large &&
              !(medicine.form.toLowerCase().contains('капл') ||
                  medicine.form.toLowerCase().contains('раствор'))
          ? 24
          : 20,
    ),
  );
}

class TreatmentBanner extends StatelessWidget {
  const TreatmentBanner(
    this.title,
    this.message, {
    this.success = false,
    this.action,
    this.onAction,
    super.key,
  });
  final String title, message;
  final bool success;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (success ? Colors.green : Colors.orange).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignIcon(
          success ? 'treatment-okay-24' : 'treatment-warning',
          size: success ? 28.8 : 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 32),
                  ),
                  child: Text(action!),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<T?> treatmentSheet<T>(
  BuildContext context,
  String title,
  Widget child, {
  String? subtitle,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (c) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .9),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: secondaryFill(c),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(c),
                    tooltip: 'Закрыть',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (subtitle != null)
                Text(subtitle, style: Theme.of(c).textTheme.bodyMedium),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<String?> treatmentChoice(
  BuildContext context,
  String title,
  List<String> values,
  String selected,
) => treatmentSheet<String>(
  context,
  title,
  Column(
    mainAxisSize: MainAxisSize.min,
    children: values
        .map(
          (v) => ListTile(
            title: Text(v),
            trailing: v == selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.pop(context, v),
          ),
        )
        .toList(),
  ),
);

Future<bool> treatmentConfirm(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> treatmentAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить изменения. Повторите действие.'),
        ),
      );
    }
  }
}

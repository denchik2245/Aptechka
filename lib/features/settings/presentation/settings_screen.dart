import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/settings/domain/app_settings.dart';
import 'package:aptechka/features/settings/domain/backup_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

  Future<void> _save(Future<void> Function() action, {String? message}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted && message != null) _message(message);
    } catch (_) {
      if (mounted) {
        _message('Не удалось сохранить изменения. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _change(AppSettings Function(AppSettings) update) => _save(() {
    final current = ref.read(appControllerProvider).requireValue.settings;
    return ref
        .read(appControllerProvider.notifier)
        .updateSettings(update(current));
  });

  Future<void> _choose<T>(
    String title,
    T selected,
    Map<T, String> choices,
    AppSettings Function(AppSettings, T) update,
  ) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...choices.entries.map(
                  (entry) => ListTile(
                    title: Text(entry.value),
                    minTileHeight: 56,
                    trailing: entry.key == selected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: () => Navigator.pop(sheetContext, entry.key),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      await _change((settings) => update(settings, result));
    }
  }

  Future<bool> _confirm(
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _export() async {
    final source = BackupCodec.encode(
      ref.read(appControllerProvider).requireValue,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Резервная копия'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Скопируйте текст и сохраните его в файл .json. Копия содержит все аптечки, упаковки, расписание, историю приёма и настройки. Храните её в надёжном месте: текст не зашифрован.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  source,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Копировать'),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: source));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  _message('Копия скопирована. Сохраните её в файл .json.');
                }
              } catch (_) {
                if (mounted) {
                  _message('Выделите текст копии и скопируйте его вручную.');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final backup = await showDialog<AppState>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (backup == null || !mounted) {
      return;
    }
    final confirmed = await _confirm(
      'Восстановить данные?',
      'В копии: ${backup.pharmacies.length} аптечки, ${backup.medicines.length} упаковок, ${backup.reminders.length} записей расписания. Все текущие записи и настройки будут заменены. Сначала сохраните текущую копию, если она нужна.',
      'Восстановить',
    );
    if (confirmed && mounted) {
      await _save(
        () => ref.read(appControllerProvider.notifier).restoreBackup(backup),
        message: 'Данные и настройки восстановлены',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: SafeArea(
      top: false,
      child: AsyncValueView(
        value: ref.watch(appControllerProvider),
        data: (state) {
          final settings = state.settings;
          final profile = ref.watch(localAccountsProvider).asData?.value.active;
          const appearances = {
            AppAppearance.system: 'Как на устройстве',
            AppAppearance.light: 'Светлая',
            AppAppearance.dark: 'Тёмная',
          };
          final scales = {
            1.0: 'Обычный',
            1.15: 'Крупный',
            1.3: 'Очень крупный',
          };
          const sorts = {
            InventorySort.name: 'По названию',
            InventorySort.expiry: 'По ближайшему сроку',
          };
          final defaultName = state.pharmacies
              .where((item) => item.id == settings.defaultPharmacyId)
              .firstOrNull
              ?.name;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AbsorbPointer(
                absorbing: _saving,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Text(
                      'Аптечка под ваш ритм',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Настройки сохраняются на этом устройстве и сразу применяются в приложении.',
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: const Icon(Icons.account_circle_outlined),
                        title: Text(profile == null ? 'Аккаунт' : profile.name),
                        subtitle: Text(
                          profile == null
                              ? 'Вход, привязка аптечек и перенос данных · демо'
                              : 'Демо-профиль · способы входа и ваши аптечки',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/account'),
                      ),
                    ),
                    _Section(
                      title: 'Внешний вид',
                      icon: Icons.palette_outlined,
                      children: [
                        _SettingRow(
                          title: 'Тема',
                          value: appearances[settings.appearance]!,
                          onTap: () => _choose(
                            'Тема',
                            settings.appearance,
                            appearances,
                            (s, value) => s.copyWith(appearance: value),
                          ),
                        ),
                        _SettingRow(
                          title: 'Размер текста',
                          value: scales[settings.textScale]!,
                          subtitle: 'Дополнительно к системному размеру текста',
                          onTap: () => _choose(
                            'Размер текста',
                            settings.textScale,
                            scales,
                            (s, value) => s.copyWith(textScale: value),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Содержимое аптечки',
                      icon: Icons.medication_outlined,
                      children: [
                        _SettingRow(
                          title: 'Аптечка при запуске',
                          value: defaultName ?? 'Последняя открытая',
                          onTap: () => _choose(
                            'Аптечка при запуске',
                            settings.defaultPharmacyId ?? '',
                            {
                              '': 'Последняя открытая',
                              for (final pharmacy in state.pharmacies)
                                pharmacy.id: pharmacy.name,
                            },
                            (s, value) => s.copyWith(
                              defaultPharmacyId: value,
                              clearDefaultPharmacy: value.isEmpty,
                            ),
                          ),
                        ),
                        _SettingRow(
                          title: 'Сортировка препаратов',
                          value: sorts[settings.inventorySort]!,
                          onTap: () => _choose(
                            'Сортировка препаратов',
                            settings.inventorySort,
                            sorts,
                            (s, value) => s.copyWith(inventorySort: value),
                          ),
                        ),
                        _SettingRow(
                          title: 'Срок скоро истечёт',
                          value: 'За ${settings.expiryWarningDays} дней',
                          subtitle: 'Для фильтра и статусов. Учитывается и срок после вскрытия.',
                          onTap: () => _choose(
                            'Когда предупреждать о сроке',
                            settings.expiryWarningDays,
                            {
                              for (final days in [7, 14, 30, 60, 90])
                                days: 'За $days дней',
                            },
                            (s, value) => s.copyWith(expiryWarningDays: value),
                          ),
                        ),
                        _SettingRow(
                          title: 'Управление аптечками',
                          subtitle: 'Создание и выбор личной аптечки',
                          onTap: () => context.go('/'),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Предупреждения',
                      icon: Icons.notifications_outlined,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Text(
                            'Сводка отображается в разделе «Приём», пока приложение открыто. Системные уведомления в фоне пока не подключены.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          title: const Text('Сроки годности'),
                          subtitle: const Text(
                            'Истекающие, истёкшие и неуказанные сроки',
                          ),
                          value: settings.expiryAlerts,
                          onChanged: (value) =>
                              _change((s) => s.copyWith(expiryAlerts: value)),
                        ),
                        SwitchListTile.adaptive(
                          title: const Text('Малый остаток'),
                          subtitle: const Text(
                            'Проверять количество в каждой упаковке',
                          ),
                          value: settings.stockAlerts,
                          onChanged: (value) =>
                              _change((s) => s.copyWith(stockAlerts: value)),
                        ),
                        _SettingRow(
                          title: 'Порог малого остатка',
                          value: '${settings.lowStockThreshold} или меньше',
                          subtitle:
                              'В единицах записи: таблетки, флаконы и т. д.',
                          enabled: settings.stockAlerts,
                          onTap: () => _choose(
                            'Порог малого остатка',
                            settings.lowStockThreshold,
                            {
                              for (final count in [1, 2, 3, 5, 10])
                                count: '$count или меньше',
                            },
                            (s, value) => s.copyWith(lowStockThreshold: value),
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Расписание приёма',
                      icon: Icons.schedule_outlined,
                      children: [
                        SwitchListTile.adaptive(
                          title: const Text('Показывать расписание'),
                          subtitle: const Text(
                            'При выключении расписание и история сохраняются',
                          ),
                          value: settings.intakeSchedule,
                          onChanged: (value) =>
                              _change((s) => s.copyWith(intakeSchedule: value)),
                        ),
                        if (state.reminders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Расписаний пока нет. Добавьте расписание при создании упаковки.',
                            ),
                          ),
                        ...state.reminders.map((reminder) {
                          final medicine = state.medicines
                              .where((item) => item.id == reminder.medicineId)
                              .firstOrNull;
                          final pharmacy = state.pharmacies
                              .where((item) => item.id == medicine?.pharmacyId)
                              .firstOrNull;
                          return SwitchListTile.adaptive(
                            title: Text(
                              medicine?.name ?? 'Упаковка не найдена',
                            ),
                            subtitle: Text(
                              '${reminder.timeLabel} · ${reminder.dose}\n${pharmacy?.name ?? ''}',
                            ),
                            value: reminder.enabled,
                            onChanged: settings.intakeSchedule
                                ? (value) => _save(
                                    () => ref
                                        .read(appControllerProvider.notifier)
                                        .setReminderEnabled(reminder.id, value),
                                  )
                                : null,
                          );
                        }),
                        _SettingRow(
                          title: 'Открыть приём и предупреждения',
                          onTap: () => context.go('/reminders'),
                        ),
                      ],
                    ),
                    _Section(
                      title: 'Данные и резервная копия',
                      icon: Icons.backup_outlined,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Text(
                            '${state.pharmacies.length} аптечки · ${state.medicines.length} упаковок\nДанные локальные. Очистка данных приложения или браузера удалит записи. Сохраните резервную копию.',
                          ),
                        ),
                        _SettingRow(
                          title: 'Создать резервную копию',
                          subtitle: 'Скопировать все данные в формате JSON',
                          onTap: _export,
                        ),
                        _SettingRow(
                          title: 'Восстановить из копии',
                          subtitle: 'Проверить и заменить текущие данные',
                          onTap: _import,
                        ),
                        _SettingRow(
                          title: 'Сбросить настройки',
                          subtitle:
                              'Вернуть значения по умолчанию, сохранить записи',
                          onTap: () async {
                            if (await _confirm(
                                  'Сбросить настройки?',
                                  'Тема, текст, предупреждения и другие параметры вернутся к исходным значениям. Записи и переключатели отдельных расписаний сохранятся.',
                                  'Сбросить',
                                ) &&
                                mounted) {
                              await _save(
                                () => ref
                                    .read(appControllerProvider.notifier)
                                    .updateSettings(const AppSettings()),
                                message: 'Настройки сброшены',
                              );
                            }
                          },
                        ),
                        _SettingRow(
                          title: 'Удалить все записи',
                          subtitle: 'Упаковки, расписания и история приёма',
                          danger: true,
                          onTap: () async {
                            if (await _confirm(
                                  'Удалить все записи?',
                                  'Будут удалены упаковки во всех аптечках, расписания и история приёма. Названия аптечек и настройки сохранятся. Отменить удаление можно только восстановлением из копии.',
                                  'Удалить записи',
                                ) &&
                                mounted) {
                              await _save(
                                () => ref
                                    .read(appControllerProvider.notifier)
                                    .clearInventory(),
                                message: 'Записи удалены',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const _Section(
                      title: 'О приложении',
                      icon: Icons.health_and_safety_outlined,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: Text(
                            'Аптечка · версия 1.0.0 · прототип\n\nАккаунты доступны в локальном демо. Настоящий вход, облачная копия и семейный доступ между устройствами пока не подключены. «Аптечка мамы» — демонстрационный пример.\n\nПриложение помогает учитывать лекарства и внесённое расписание. Оно не назначает лечение. Даты и условия хранения проверяйте по упаковке и инструкции.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                children[index],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.enabled = true,
    this.danger = false,
  });
  final String title;
  final String? value;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
    minTileHeight: 72,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: danger ? Theme.of(context).colorScheme.error : null,
      ),
    ),
    subtitle: value == null && subtitle == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              if (subtitle != null) Text(subtitle!),
            ],
          ),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: enabled ? onTap : null,
  );
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _source = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Восстановление из копии'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Вставьте полный текст JSON. Сначала проверим копию, затем покажем подтверждение замены данных.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _source,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Текст резервной копии',
                errorText: _error,
                errorMaxLines: 4,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final backup = BackupCodec.decode(_source.text);
            Navigator.pop(context, backup);
          } on FormatException catch (error) {
            setState(() => _error = error.message);
          }
        },
        child: const Text('Проверить копию'),
      ),
    ],
  );
}

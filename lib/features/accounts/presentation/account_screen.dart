import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/utils/russian_count.dart';
import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/features/accounts/domain/account.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login(LoginMethod method, {bool linking = false}) async {
    final identity = await showDialog<LoginIdentity>(
      context: context,
      builder: (_) => _DemoLoginDialog(method: method, linking: linking),
    );
    if (identity == null || !mounted) return;
    await _run(() async {
      final controller = ref.read(localAccountsProvider.notifier);
      if (linking) {
        await controller.linkDemo(identity);
      } else {
        await controller.signInDemo(identity);
        await ref.read(appControllerProvider.future);
      }
    });
  }

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(text),
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

  Future<void> _copyGuest() async {
    final guest = await ref.read(appControllerProvider.notifier).guestData();
    if (!mounted) return;
    final ids = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _GuestImportDialog(guest: guest),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await _run(
      () => ref.read(appControllerProvider.notifier).copyGuestPharmacies(ids),
    );
  }

  Future<void> _rename(AccountProfile profile) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(name: profile.name),
    );
    if (name != null && mounted) {
      await _run(() => ref.read(localAccountsProvider.notifier).rename(name));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Аккаунт')),
    body: SafeArea(
      top: false,
      child: AsyncValueView(
        value: ref.watch(localAccountsProvider),
        data: (accounts) {
          final profile = accounts.active;
          final inventory = ref.watch(appControllerProvider).asData?.value;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  children: [
                    _Notice(
                      icon: Icons.science_outlined,
                      text: 'Демонстрация аккаунтов. Вход не подтверждает личность. Профили и записи хранятся только на этом устройстве; письма не отправляются, облако не подключено.',
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 24),
                    if (profile == null) ...[
                      Text(
                        'Один аккаунт для ваших аптечек',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'В будущей онлайн-версии аккаунт сохранит аптечки между устройствами. Сейчас можно проверить сценарии входа, привязки и переноса в локальном демо.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _login(LoginMethod.yandex),
                        icon: const _YandexMark(),
                        label: const Text('Демо входа через Яндекс'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _login(LoginMethod.email),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Демо входа по почте'),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Продолжить без аккаунта'),
                      ),
                    ] else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Icon(
                                      Icons.person_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        const Text(
                                          'Демо-профиль · на этом устройстве',
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _rename(profile),
                                    tooltip: 'Изменить имя',
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '${russianCount(inventory?.pharmacies.length ?? 0, 'аптечка', 'аптечки', 'аптечек')} · ${russianCount(inventory?.medicines.length ?? 0, 'упаковка', 'упаковки', 'упаковок')}',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Записи этого профиля отделены от гостевых данных и других демо-профилей.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Heading('Способы входа'),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ...profile.identities.map(
                              (identity) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Icon(
                                  identity.method == LoginMethod.email
                                      ? Icons.mail_outline
                                      : Icons.verified_user_outlined,
                                ),
                                title: Text(identity.method.label),
                                subtitle: Text(identity.label),
                                trailing: IconButton(
                                  tooltip: profile.identities.length <= 1
                                      ? 'Последний способ нельзя отключить'
                                      : 'Отключить способ входа',
                                  onPressed: profile.identities.length <= 1
                                      ? null
                                      : () async {
                                          if (await _confirm(
                                                'Отключить ${identity.method.label}?',
                                                'Вход через этот способ перестанет открывать текущий демо-профиль. Другой способ останется доступен.',
                                                'Отключить',
                                              ) &&
                                              mounted) {
                                            await _run(
                                              () => ref
                                                  .read(
                                                    localAccountsProvider
                                                        .notifier,
                                                  )
                                                  .unlinkDemo(identity.method),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.link_off),
                                ),
                              ),
                            ),
                            if (!profile.identities.any(
                              (item) => item.method == LoginMethod.yandex,
                            ))
                              ListTile(
                                title: const Text('Привязать Яндекс ID'),
                                subtitle: const Text(
                                  'Демо · тот же профиль и те же аптечки',
                                ),
                                trailing: const Icon(Icons.add),
                                onTap: () =>
                                    _login(LoginMethod.yandex, linking: true),
                              ),
                            if (!profile.identities.any(
                              (item) => item.method == LoginMethod.email,
                            ))
                              ListTile(
                                title: const Text('Привязать почту'),
                                subtitle: const Text(
                                  'Демо · резервный способ входа',
                                ),
                                trailing: const Icon(Icons.add),
                                onTap: () =>
                                    _login(LoginMethod.email, linking: true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Heading('Аптечки и данные'),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Мои аптечки'),
                              subtitle: const Text(
                                'Открыть записи текущего профиля',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Скопировать гостевые аптечки'),
                              subtitle: const Text(
                                'Выбрать аптечки, упаковки и историю. Оригиналы сохранятся.',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _copyGuest,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: const Text('Резервная копия'),
                              subtitle: const Text(
                                'Экспорт и восстановление данных этого профиля',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/settings'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Notice(
                        icon: Icons.cloud_off_outlined,
                        text: 'Синхронизация между устройствами и приглашения в общую аптечку пока не подключены. Для облака потребуется сервер в РФ и отдельное оформление обработки данных о здоровье.',
                      ),
                      const SizedBox(height: 24),
                      _Heading('Управление профилем'),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Выйти из демо-профиля'),
                              subtitle: const Text(
                                'Вернуться к гостевым записям. Данные профиля сохранятся.',
                              ),
                              trailing: const Icon(Icons.logout),
                              onTap: () async {
                                await _run(
                                  () => ref
                                      .read(localAccountsProvider.notifier)
                                      .signOut(),
                                );
                                if (context.mounted) context.go('/');
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              title: Text(
                                'Удалить демо-профиль',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              subtitle: const Text(
                                'Удалить профиль и все его локальные записи',
                              ),
                              trailing: const Icon(Icons.delete_outline),
                              onTap: () async {
                                if (!await _confirm(
                                      'Удалить демо-профиль?',
                                      'Все записи этого профиля будут удалены с устройства. Гостевые записи и другие профили сохранятся. Сначала сохраните резервную копию, если она нужна.',
                                      'Удалить профиль',
                                    ) ||
                                    !mounted) {
                                  return;
                                }
                                await _run(() async {
                                  final repository = LocalMedicineRepository(
                                    await SharedPreferences.getInstance(),
                                    profileScopeId: profile.id,
                                  );
                                  await repository.deleteProfileData();
                                  await ref
                                      .read(localAccountsProvider.notifier)
                                      .deleteActiveDemo();
                                });
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _Heading('Другие способы входа'),
                    const SizedBox(height: 12),
                    const Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.people_outline),
                            title: Text('VK ID'),
                            subtitle: Text(
                              'Запланирован после регистрации приложения и подключения сервера',
                            ),
                          ),
                          Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.public_outlined),
                            title: Text('Google'),
                            subtitle: Text(
                              'Отключён для российской версии. Возможен отдельный вариант для других регионов после проверки требований.',
                            ),
                          ),
                          Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.apple),
                            title: Text('Apple'),
                            subtitle: Text(
                              'Для iOS требуется отдельно согласовать способы входа с правилами App Store и требованиями РФ.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/account/privacy'),
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Как будут защищены данные'),
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

class AccountPrivacyScreen extends StatelessWidget {
  const AccountPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Аккаунт и данные')),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _Notice(
                icon: Icons.science_outlined,
                text: 'Это описание проектируемой системы, а не действующая политика или согласие. Сервис пока не собирает данные на сервере.',
              ),
              const SizedBox(height: 24),
              _Heading('Минимум данных для аккаунта'),
              const SizedBox(height: 8),
              const Text(
                'Для входа понадобятся подтверждённый адрес почты либо идентификатор Яндекса. Имя можно выбрать самостоятельно. Контакты, паспорт, геолокация и доступ к Яндекс Диску не нужны для обычного аккаунта.',
              ),
              const SizedBox(height: 24),
              _Heading('Российская инфраструктура'),
              const SizedBox(height: 8),
              const Text(
                'Планируем хранить аккаунты, аптечки, резервные копии и служебные журналы в РФ. Провайдер входа получает запрос авторизации, но не списки лекарств или историю приёма.',
              ),
              const SizedBox(height: 24),
              _Heading('Отдельное решение для данных о здоровье'),
              const SizedBox(height: 8),
              const Text(
                'Сведения о приёме и лекарствах могут раскрывать состояние здоровья. Перед облачным сохранением потребуется определить законное основание и, когда оно необходимо, оформить письменное согласие, включая допустимую электронную форму. Простое создание аккаунта не запускает отправку записей.',
              ),
              const SizedBox(height: 24),
              _Heading('Контроль остаётся у вас'),
              const SizedBox(height: 8),
              const Text(
                'В онлайн-версии будут доступны список устройств, завершение сеансов, выгрузка данных, отзыв согласия и удаление аккаунта. Доступ к общей аптечке предоставляется отдельно; личное расписание и история не открываются другим участникам автоматически.',
              ),
              const SizedBox(height: 24),
              _Heading('Документы до запуска'),
              const SizedBox(height: 8),
              const Text(
                'Потребуются реквизиты оператора, политика обработки данных, условия использования, отдельные формы согласий, сроки хранения и контакты для обращений. До их оформления прототип не выдаёт демо-переключатели за юридически значимое согласие.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DemoLoginDialog extends StatefulWidget {
  const _DemoLoginDialog({required this.method, required this.linking});
  final LoginMethod method;
  final bool linking;
  @override
  State<_DemoLoginDialog> createState() => _DemoLoginDialogState();
}

class _DemoLoginDialogState extends State<_DemoLoginDialog> {
  final _email = TextEditingController(text: 'anna@example.test');
  final _code = TextEditingController();
  bool _codeStage = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.linking ? 'Привязка' : 'Вход'} · ${widget.method.label}',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Локальная демонстрация. Не вводите настоящие коды, пароли или персональные данные.',
            ),
            const SizedBox(height: 16),
            if (widget.method == LoginMethod.email) ...[
              if (!_codeStage)
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Демо-почта',
                    helperText:
                        'Адрес на example.test, например anna@example.test',
                    helperMaxLines: 3,
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                )
              else ...[
                Text(
                  'Демо-код для ${_email.text.trim()}: 123456. Письмо не отправлялось.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Демо-код',
                    errorText: _error,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _codeStage = false;
                    _error = null;
                    _code.clear();
                  }),
                  child: const Text('Изменить демо-почту'),
                ),
              ],
            ] else
              const Text(
                'В настоящей версии откроется страница Яндекс ID. В этом сценарии используется вымышленный профиль «Анна». Доступ к данным Яндекса не запрашивается.',
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
            final identity = LocalAccountController.demoIdentity(
              widget.method,
              email: _email.text,
            );
            if (widget.method == LoginMethod.email && !_codeStage) {
              setState(() {
                _codeStage = true;
                _error = null;
              });
              return;
            }
            if (widget.method == LoginMethod.email && _code.text != '123456') {
              setState(() => _error = 'Введите показанный демо-код 123456');
              return;
            }
            Navigator.pop(context, identity);
          } on FormatException catch (error) {
            setState(() => _error = error.message);
          }
        },
        child: Text(
          widget.method == LoginMethod.email && !_codeStage
              ? 'Показать демо-код'
              : widget.linking
              ? 'Привязать в демо'
              : 'Войти в демо',
        ),
      ),
    ],
  );
}

class _GuestImportDialog extends StatefulWidget {
  const _GuestImportDialog({required this.guest});
  final AppState guest;
  @override
  State<_GuestImportDialog> createState() => _GuestImportDialogState();
}

class _GuestImportDialogState extends State<_GuestImportDialog> {
  late final Set<String> _selected = widget.guest.pharmacies
      .where((item) => item.canEdit && !item.isShared)
      .map((item) => item.id)
      .toSet();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Выберите гостевые аптечки'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Упаковки, связанные расписания и история будут скопированы в текущий демо-профиль. Гостевые оригиналы и настройки сохранятся. Повторное копирование не создаёт дубликаты и не перезаписывает уже скопированные записи.',
            ),
            const SizedBox(height: 12),
            ...widget.guest.pharmacies.map(
              (pharmacy) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(pharmacy.name),
                subtitle: Text(
                  '${russianCount(widget.guest.medicinesIn(pharmacy.id).length, 'упаковка', 'упаковки', 'упаковок')}${pharmacy.isShared ? ' · демонстрационная общая' : ''}',
                ),
                value: _selected.contains(pharmacy.id),
                onChanged: pharmacy.canEdit
                    ? (value) => setState(() {
                        if (value == true) {
                          _selected.add(pharmacy.id);
                        } else {
                          _selected.remove(pharmacy.id);
                        }
                      })
                    : null,
              ),
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
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('Скопировать выбранные'),
      ),
    ],
  );
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});
  final String name;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Имя профиля'),
    content: TextField(
      controller: _name,
      maxLength: 40,
      decoration: const InputDecoration(labelText: 'Имя'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text.trim()),
        child: const Text('Сохранить'),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class _YandexMark extends StatelessWidget {
  const _YandexMark();
  @override
  Widget build(BuildContext context) => const Text(
    'Я',
    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
  );
}

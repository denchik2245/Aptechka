import 'dart:convert';

import 'package:aptechka/features/accounts/domain/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Local UX simulation only. This store does not authenticate a person or hold tokens.
final localAccountsProvider =
    AsyncNotifierProvider<LocalAccountController, LocalAccounts>(
      LocalAccountController.new,
    );
final activeProfileIdProvider = Provider<String>(
  (ref) => ref.watch(
    localAccountsProvider.select(
      (value) => value.asData?.value.active?.id ?? 'guest',
    ),
  ),
);

class LocalAccountController extends AsyncNotifier<LocalAccounts> {
  static const storageKey = 'aptechka_demo_accounts_v1';
  late SharedPreferences _preferences;
  @override
  Future<LocalAccounts> build() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences.getString(storageKey);
    return raw == null
        ? const LocalAccounts()
        : LocalAccounts.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map),
          );
  }

  Future<void> _save(LocalAccounts value) async {
    if (!await _preferences.setString(storageKey, jsonEncode(value.toJson()))) {
      throw StateError('Не удалось сохранить демо-профиль');
    }
    state = AsyncData(value);
  }

  static LoginIdentity demoIdentity(
    LoginMethod method, {
    String email = 'anna@example.test',
  }) {
    if (method == LoginMethod.email) {
      final normalized = email.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9._+-]+@example\.test$').hasMatch(normalized)) {
        throw const FormatException(
          'В демо используйте адрес вида anna@example.test',
        );
      }
      return LoginIdentity(
        method: method,
        subject: normalized,
        label: normalized,
      );
    }
    if (method == LoginMethod.yandex) {
      return const LoginIdentity(
        method: LoginMethod.yandex,
        subject: 'demo-yandex-anna',
        label: 'Анна · демо Яндекса',
      );
    }
    throw StateError('Этот способ входа не подключён');
  }

  Future<void> signInDemo(LoginIdentity identity) async {
    final current = state.requireValue;
    final found = current.profiles
        .where(
          (profile) => profile.identities.any(
            (item) =>
                item.method == identity.method &&
                item.subject == identity.subject,
          ),
        )
        .firstOrNull;
    final profile =
        found ??
        AccountProfile(
          id: const Uuid().v4(),
          name: identity.method == LoginMethod.yandex
              ? 'Анна'
              : identity.subject.split('@').first,
          identities: [identity],
          createdAt: DateTime.now(),
        );
    await _save(
      LocalAccounts(
        profiles: found == null
            ? [...current.profiles, profile]
            : current.profiles,
        activeId: profile.id,
      ),
    );
  }

  Future<void> linkDemo(LoginIdentity identity) async {
    final current = state.requireValue;
    final active = current.active;
    if (active == null) throw StateError('Сначала войдите в демо-профиль');
    final owner = current.profiles
        .where(
          (profile) => profile.identities.any(
            (item) =>
                item.method == identity.method &&
                item.subject == identity.subject,
          ),
        )
        .firstOrNull;
    if (owner != null && owner.id != active.id) {
      throw StateError(
        'Этот способ уже привязан к другому демо-профилю. Объединение по совпадению почты не выполняется.',
      );
    }
    if (active.identities.any((item) => item.method == identity.method)) {
      throw StateError('Этот способ уже подключён');
    }
    final updated = active.copyWith(
      identities: [...active.identities, identity],
    );
    await _save(
      LocalAccounts(
        profiles: current.profiles
            .map((item) => item.id == active.id ? updated : item)
            .toList(),
        activeId: active.id,
      ),
    );
  }

  Future<void> unlinkDemo(LoginMethod method) async {
    final current = state.requireValue;
    final active = current.active;
    if (active == null) return;
    if (active.identities.length <= 1) {
      throw StateError('Сначала добавьте другой способ входа');
    }
    final updated = active.copyWith(
      identities: active.identities
          .where((item) => item.method != method)
          .toList(),
    );
    await _save(
      LocalAccounts(
        profiles: current.profiles
            .map((item) => item.id == active.id ? updated : item)
            .toList(),
        activeId: active.id,
      ),
    );
  }

  Future<void> rename(String name) async {
    final current = state.requireValue;
    if (current.active == null ||
        name.trim().isEmpty ||
        name.trim().length > 40) {
      return;
    }
    await _save(
      LocalAccounts(
        profiles: current.profiles
            .map(
              (item) => item.id == current.activeId
                  ? item.copyWith(name: name.trim())
                  : item,
            )
            .toList(),
        activeId: current.activeId,
      ),
    );
  }

  Future<void> signOut() =>
      _save(LocalAccounts(profiles: state.requireValue.profiles));

  Future<void> deleteActiveDemo() async {
    final current = state.requireValue;
    await _save(
      LocalAccounts(
        profiles: current.profiles
            .where((item) => item.id != current.activeId)
            .toList(),
      ),
    );
  }
}

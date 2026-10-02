import 'package:aptechka/features/accounts/application/account_controller.dart';
import 'package:aptechka/features/accounts/domain/account.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/data/medicine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profile switching isolates data; import preserves originals and is idempotent', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(localAccountsProvider.future);
    final guest = await container.read(appControllerProvider.future);
    final accounts = container.read(localAccountsProvider.notifier);
    await accounts.signInDemo(
      LocalAccountController.demoIdentity(LoginMethod.email),
    );
    final first = await container.read(appControllerProvider.future);
    expect(first.medicines, isEmpty);
    expect(first.profileScopeId, isNot('guest'));
    final firstId = first.profileScopeId;
    await container.read(appControllerProvider.notifier).copyGuestPharmacies({
      'home',
    });
    final copied = container.read(appControllerProvider).requireValue;
    expect(copied.medicines, hasLength(guest.medicinesIn('home').length));
    expect(
      copied.pharmacies.every((item) => item.ownerAccountId == firstId),
      isTrue,
    );
    expect(
      copied.reminders.every(
        (item) =>
            copied.medicines.any((medicine) => medicine.id == item.medicineId),
      ),
      isTrue,
    );
    await container.read(appControllerProvider.notifier).copyGuestPharmacies({
      'home',
    });
    expect(
      container.read(appControllerProvider).requireValue.toJson(),
      copied.toJson(),
    );
    await accounts.signOut();
    final afterLogout = await container.read(appControllerProvider.future);
    expect(afterLogout.toJson(), guest.toJson());
    await accounts.signInDemo(
      LocalAccountController.demoIdentity(
        LoginMethod.email,
        email: 'bob@example.test',
      ),
    );
    final second = await container.read(appControllerProvider.future);
    expect(second.profileScopeId, isNot(firstId));
    expect(second.medicines, isEmpty);
    await accounts.signOut();
    await accounts.signInDemo(
      LocalAccountController.demoIdentity(LoginMethod.email),
    );
    expect(
      (await container.read(appControllerProvider.future)).toJson(),
      copied.toJson(),
    );
  });

  test('explicit linking keeps account ID, refuses conflicts and protects last method', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(localAccountsProvider.future);
    final accounts = container.read(localAccountsProvider.notifier);
    final email = LocalAccountController.demoIdentity(LoginMethod.email);
    final yandex = LocalAccountController.demoIdentity(LoginMethod.yandex);
    await accounts.signInDemo(email);
    final firstId = container.read(localAccountsProvider).requireValue.activeId;
    await expectLater(accounts.unlinkDemo(LoginMethod.email), throwsStateError);
    await accounts.linkDemo(yandex);
    expect(
      container.read(localAccountsProvider).requireValue.active!.identities,
      hasLength(2),
    );
    await accounts.signOut();
    await accounts.signInDemo(yandex);
    expect(
      container.read(localAccountsProvider).requireValue.activeId,
      firstId,
    );
    await accounts.signOut();
    await accounts.signInDemo(
      LocalAccountController.demoIdentity(
        LoginMethod.email,
        email: 'bob@example.test',
      ),
    );
    await expectLater(accounts.linkDemo(yandex), throwsStateError);
    expect(
      () => LocalAccountController.demoIdentity(LoginMethod.google),
      throwsStateError,
    );
  });

  test('repository rejects a different profile and backup restoration assigns current owner', () async {
    final prefs = await SharedPreferences.getInstance();
    final guest = await LocalMedicineRepository(prefs).load();
    final scoped = LocalMedicineRepository(prefs, profileScopeId: 'profile-a');
    await expectLater(scoped.save(guest), throwsStateError);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(localAccountsProvider.future);
    await container
        .read(localAccountsProvider.notifier)
        .signInDemo(LocalAccountController.demoIdentity(LoginMethod.email));
    await container.read(appControllerProvider.future);
    final scope = container.read(activeProfileIdProvider);
    await container.read(appControllerProvider.notifier).restoreBackup(guest);
    final restored = container.read(appControllerProvider).requireValue;
    expect(restored.profileScopeId, scope);
    expect(
      restored.pharmacies.every((item) => item.ownerAccountId == scope),
      isTrue,
    );
  });
}

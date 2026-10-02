import 'package:aptechka/features/medicines/domain/medicine.dart';

class MedicineGroup {
  const MedicineGroup(this.packages);

  final List<Medicine> packages;

  Medicine get representative => packages.first;
  String get name => representative.name;
  String get form => representative.form;
  String get dosage => representative.dosageLabel;

  int get packagesNeedingAttention => attentionCount();

  int attentionCount({int warningDays = 30}) => packages
      .where(
        (item) =>
            item.statusAt(DateTime.now(), warningDays: warningDays) !=
            MedicineStatus.okay,
      )
      .length;

  String get locationSummary {
    final locations = packages.map((item) => item.location).toSet().toList();
    if (locations.isEmpty) return 'Место не указано';
    if (locations.length == 1) return locations.first;
    return '${locations.first} и ещё ${locations.length - 1}';
  }
}

List<MedicineGroup> groupMedicines(List<Medicine> packages) {
  final groups = <String, List<Medicine>>{};
  for (final package in packages) {
    groups.putIfAbsent(package.groupKey, () => []).add(package);
  }
  return groups.values.map((items) => MedicineGroup(items)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

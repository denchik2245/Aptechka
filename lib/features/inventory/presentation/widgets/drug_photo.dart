import 'package:aptechka/features/inventory/data/drug_photo_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DrugPhotoPanel extends ConsumerWidget {
  const DrugPhotoPanel({required this.gtin, super.key});
  final String? gtin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(drugPhotoProvider(gtin)).asData?.value;
    if (photo == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.asset(
                    photo.asset,
                    height: 180,
                    fit: BoxFit.contain,
                    semanticLabel: 'Фото упаковки из справочника РЛС',
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Фотография недоступна',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                photo.credit,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Оформление упаковки может отличаться. Сверьте название и дозировку.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

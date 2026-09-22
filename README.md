# Аптечка

Кроссплатформенное Flutter-приложение для учёта домашних лекарств, сроков годности и регулярного приёма. Проект создаётся для Android и iOS; Web используется как быстрый предпросмотр интерфейса.

## Возможности MVP

- главная сводка по домашней аптечке;
- список препаратов, поиск и фильтры;
- статусы «годен», «скоро истечёт» и «просрочен»;
- добавление препарата вручную;
- сканирование Data Matrix, EAN-13 и EAN-8;
- выделение GTIN из российского кода маркировки;
- локальное сохранение данных;
- расписание и отметка факта приёма;
- светлая/тёмная тема и адаптивная навигация.

Приложение не ставит диагноз и не назначает лечение.

## Запуск на Windows

В текущей рабочей копии Flutter SDK находится в `.tooling/flutter` и не включается в Git:

```powershell
.\.tooling\flutter\bin\flutter.bat pub get
.\.tooling\flutter\bin\flutter.bat run -d chrome
```

Для Android установите Android Studio, Android SDK и создайте эмулятор, затем:

```powershell
.\.tooling\flutter\bin\flutter.bat devices
.\.tooling\flutter\bin\flutter.bat run -d <device-id>
```

## Запуск на macOS

Установите Flutter и Xcode, откройте репозиторий и выполните:

```bash
flutter pub get
flutter run -d ios
```

Для физического iPhone потребуется выбрать команду разработки в Xcode в настройках Signing & Capabilities.

## Проверка качества

```bash
flutter analyze
flutter test
flutter build web --release
```

Архитектура описана в [docs/architecture.md](docs/architecture.md), визуальные правила — в [docs/design-system.md](docs/design-system.md).

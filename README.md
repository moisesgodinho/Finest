# Finest

Base inicial de um app Flutter offline-first para controle financeiro pessoal.

## Stack

- Flutter e Dart
- SQLite local com Drift
- Riverpod para estado
- MVVM por feature
- Repository Pattern e Service Layer
- Rotas com GoRouter
- Tema centralizado inspirado em fintech

## Estrutura

```text
lib/
  main.dart
  app.dart
  core/
    auth/
    backup/
    database/
      app_database.dart
      daos/
      tables/
    routing/
    theme/
    utils/
  data/
    models/
    repositories/
  features/
    auth/login/
    home/
    accounts/
    cards/
    planning/
    transactions/
    investments/
    pet/
    settings/
  shared/
    constants/
    widgets/
```

Valores monetários no Drift são armazenados como inteiros em centavos.

## Próximos passos no ambiente Flutter

```bash
flutter create . --platforms=android,ios
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

O SDK Flutter não está disponível neste terminal, então os arquivos de plataforma Android/iOS devem ser gerados no ambiente local com Flutter instalado.

## Android Studio

Abra a pasta raiz `C:\Dev\Finest` como projeto Flutter, não como projeto Gradle. Em um projeto Flutter, a raiz não precisa de `settings.gradle`; o Gradle fica dentro de `android/` e é gerenciado pelo Flutter tooling.

# Flutter Feature File Tree

## Single-page feature

```text
lib/features/<name>/
├── domain/      <name>.dart (@freezed entity + mock()), <name>_failure.dart (sealed), <name>_repository.dart (abstract interface class), _domain.dart
├── data/        <name>_dto.dart, <name>_mapper.dart, <name>_datasource.dart, <name>_repository_impl.dart, _data.dart
├── providers/   <name>_provider.dart (@riverpod notifier), _providers.dart
├── pages/       <name>_page.dart, _pages.dart
└── widgets/     <name>_widget.dart, _widgets.dart
```

## Multi-page feature

```text
lib/features/<name>/
├── domain/ data/            # as above
├── providers/ widgets/      # shared across pages only
└── pages/
    ├── <page1>/
    │   ├── providers/       # page-scoped (omit if none): <page1>_provider.dart, _providers.dart
    │   ├── widgets/         # page-scoped (omit if none): <page1>_widget.dart, _widgets.dart
    │   ├── <page1>_page.dart
    │   └── _<page1>.dart    # page barrel
    ├── <page2>/ …
    └── _pages.dart          # re-exports page barrels
```

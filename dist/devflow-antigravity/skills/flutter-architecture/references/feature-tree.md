# Flutter Feature File Tree

## Single-page feature

```text
lib/features/<name>/
├── domain/
│   ├── <name>.dart              # @freezed entity + mock()
│   ├── <name>_failure.dart      # sealed failure union
│   ├── <name>_repository.dart   # abstract interface class
│   └── _domain.dart             # barrel
├── data/
│   ├── <name>_dto.dart
│   ├── <name>_mapper.dart
│   ├── <name>_datasource.dart
│   ├── <name>_repository_impl.dart
│   └── _data.dart
├── providers/
│   ├── <name>_provider.dart     # @riverpod notifier
│   └── _providers.dart
├── pages/
│   ├── <name>_page.dart
│   └── _pages.dart
└── widgets/
    ├── <name>_widget.dart
    └── _widgets.dart
```

## Multi-page feature

Each page becomes a subfolder mirroring the feature structure with only page-specific elements:

```text
lib/features/<name>/
├── domain/  …
├── data/    …
├── providers/ …                 # shared across pages
├── widgets/   …                 # shared across pages
└── pages/
    ├── <page1>/
    │   ├── providers/           # page-scoped notifiers (if any)
    │   │   ├── <page1>_provider.dart
    │   │   └── _providers.dart
    │   ├── widgets/             # page-scoped widgets
    │   │   ├── <page1>_widget.dart
    │   │   └── _widgets.dart
    │   ├── <page1>_page.dart
    │   └── _<page1>.dart        # barrel
    ├── <page2>/
    │   ├── widgets/
    │   │   ├── <page2>_widget.dart
    │   │   └── _widgets.dart
    │   ├── <page2>_page.dart
    │   └── _<page2>.dart
    └── _pages.dart              # re-exports all page barrels
```

## Multi-page rules

- Feature-level `providers/` — state shared across pages. Page-level `providers/` — state used only by that page.
- Feature-level `widgets/` — widgets shared across pages. Page-scoped widgets live inside the page folder.
- Omit `providers/` or `widgets/` subfolders inside a page folder when not needed.
- Page barrels (`_<page>.dart`) export all public symbols of that page; `_pages.dart` re-exports all page barrels.

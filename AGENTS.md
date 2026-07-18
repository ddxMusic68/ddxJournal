# AGENTS.md

## Project

Single-package Flutter app (SDK ^3.11.5). Entry point: `lib/main.dart`. No monorepo structure.

## Commands

- `flutter run` — run the app
- `flutter test` — run tests (no `test/` dir exists yet; create it before adding tests)
- `flutter analyze` — lint (uses `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`)
- `flutter pub get` — install dependencies after editing `pubspec.yaml`

## Notes

- No CI, no codegen, no migrations, no environment files.
- `flutter_lints` is the only dev dependency; run `flutter analyze` before committing changes.

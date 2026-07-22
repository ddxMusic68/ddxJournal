A personal journaling app built with Flutter. Write daily entries organized by a calendar view, with rich text editing, photo attachments, tagging, PIN privacy lock, and optional Dropbox cloud sync.

## Features

- **Calendar-based navigation** — Month-view home screen with visual indicators for days that have entries. Tap any day to open or create that day's journal entry.
- **Rich text editing** — Format your writing with bold, italic, underline, bullet lists, and numbered lists powered by `flutter_quill`.
- **Photo attachments** — Attach images from your gallery or camera to any entry, with automatic compression.
- **Tags** — Add freeform text tags to entries for organization, displayed as colored chips.
- **PIN lock** — Optional 4–8 digit PIN to protect your journal (SHA-256 hashed).
- **Dropbox cloud sync** — Bidirectional sync of all journal data and media to your own Dropbox account via OAuth 2.0 with PKCE.
- **Import/Export** — Export your journal data to a local folder and import it back with merge or replace options.
- **Light & Dark theme** — Follows your system preference with Material 3 theming.

<!-- Add screenshots here -->
<!-- ![Calendar Home](screenshots/calendar.png) -->
<!-- ![Entry Editor](screenshots/editor.png) -->

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.5`
- Dart SDK `^3.11.5`

### Run the app

```bash
git clone <repo-url>
cd ddxJournal
flutter pub get
flutter run
```

## Dropbox Sync Setup

Dropbox sync requires your own Dropbox app credentials. No API keys are baked into the app.

1. Go to [Dropbox App Console](https://www.dropbox.com/developers/apps).
2. Click **Create app** and choose **Scoped access** → **Full Dropbox** (or App folder).
3. Under the **Permissions** tab, enable `files.content.write` and `files.content.read`, then click **Submit**.
4. Copy the **App key** from the app's overview page.
5. In ddxJournal, open **Settings** → **Dropbox Sync** → **Connect**.
6. Enter your App key, then authorize the app in your browser and paste the authorization code back into the app.

Once connected, use **Sync Now** in settings to sync manually. Auto-sync runs on app startup when enabled.

## Architecture

```
lib/
├── main.dart                  # Entry point, provider initialization
├── app.dart                   # MaterialApp, theming, auth gate
├── models/                    # Data classes (JournalEntry, Tag)
├── providers/                 # ChangeNotifiers (Auth, Journal, Sync)
├── screens/                   # UI screens (Home, Entry, Settings, Sync, Lock)
├── services/                  # Singletons (Database, Auth, Sync, Media, Import/Export)
├── widgets/                   # Reusable UI components (TagChip, EntryCard)
└── utils/                     # Constants (colors)
```

- **State management:** Provider with three `ChangeNotifier`s (`AuthProvider`, `JournalProvider`, `SyncProvider`).
- **Data persistence:** Single JSON file (`journal_data.json`) in the app documents directory, with an in-memory cache.
- **No codegen:** Models use manual `toMap()`/`fromMap()` serialization.
- **Navigation:** Imperative `Navigator.push` — no routing package.

## Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `flutter_quill` | Rich text editor |
| `dio` | HTTP client for Dropbox API |
| `shared_preferences` | Key-value storage (PIN, sync tokens) |
| `image_picker` | Camera/gallery image selection |
| `flutter_image_compress` | Image compression |
| `file_picker` | Directory/file selection for import/export |
| `crypto` | SHA-256 hashing for PIN and Dropbox PKCE |
| `url_launcher` | Opening OAuth URL in browser |
| `path_provider` | App documents directory access |
| `intl` | Date formatting |

## Development

```bash
flutter pub get       # Install dependencies
flutter run            # Run the app
flutter analyze        # Lint check (uses flutter_lints)
```

Tests can be added by creating a `test/` directory and running `flutter test`.

## Platform Support

| Platform | Status |
|---|---|
| Android | Supported |
| iOS | Unknown |
| Web | Unsupported |
| Linux | Unknown |
| macOS | Unknown |
| Windows | Supported |

## Contributing

1. Fork the repository.
2. Create a feature branch.
3. Run `flutter analyze` before committing.
4. Open a pull request with a description of your changes.

## Screenshots
<img width="154" height="338" alt="Screenshot 2026-07-20 204719" src="https://github.com/user-attachments/assets/fda3ed4d-1a07-4785-8f34-813a8e7edb85" />

<img width="156" height="338" alt="Screenshot 2026-07-20 205333" src="https://github.com/user-attachments/assets/bf125943-5e0c-440d-b311-7f21866ea38d" />

<img width="155" height="353" alt="Screenshot 2026-07-20 204706" src="https://github.com/user-attachments/assets/f8fb506f-22f0-43dd-8175-cbc504fdd337" />

<img width="152" height="339" alt="Screenshot 2026-07-20 204713" src="https://github.com/user-attachments/assets/f9c0546f-e926-42b8-9149-2e5880b2ab71" />

## Todo
- Add a green color scheme
- add a color scheme picker in settings
- make sync ask you for time periods for sync
- make sync work with deleting entries
- make disabling sync not forget your key
- resize icon



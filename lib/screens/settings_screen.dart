import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/sync_provider.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import 'sync_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Security'),
          SwitchListTile(
            title: const Text('PIN Lock'),
            subtitle: const Text('Require PIN to open the app'),
            value: auth.pinIsSet,
            onChanged: (value) async {
              if (value) {
                _showSetPinDialog(context);
              } else {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove PIN?'),
                    content: const Text('This will remove the PIN lock from the app.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  auth.clearPin();
                }
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Sync'),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Dropbox Sync'),
            subtitle: Text(
              sync.isAuthenticated ? 'Connected' : 'Not connected',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncScreen()),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Import / Export'),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export Data'),
            subtitle: const Text('Save journal entries and media to a folder'),
            onTap: () async {
              try {
                final path = await ImportExportService().exportData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported to $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Data'),
            subtitle: const Text('Restore entries from a JSON backup'),
            onTap: () async {
              try {
                final result = await ImportExportService().pickAndReadImportFile();
                if (result == null || !context.mounted) return;
                final (data, importDir) = result;

                final choice = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Import mode'),
                    content: const Text('How should the imported data be combined with your existing journal?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'merge'),
                        child: const Text('Merge'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, 'replace'),
                        child: const Text('Replace', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (choice == null || choice == 'cancel' || !context.mounted) return;

                final ieService = ImportExportService();

                if (choice == 'replace') {
                  await ieService.replaceAll(data, importDir);
                } else {
                  await ieService.mergeData(data, importDir);
                }

                if (context.mounted) {
                  context.read<JournalProvider>().loadMonth(
                        DateTime.now().year,
                        DateTime.now().month,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import completed ($choice)')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import failed: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Danger Zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset Local Data'),
            subtitle: const Text('Delete all entries and tags'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset all data?'),
                  content: const Text('This will permanently delete all journal entries and tags. This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await DatabaseService().resetAll();
                if (context.mounted) {
                  context.read<JournalProvider>().loadMonth(
                        DateTime.now().year,
                        DateTime.now().month,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data deleted')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_off, color: Colors.red),
            title: const Text('Reset Cloud Data'),
            subtitle: const Text('Delete all Dropbox backup data'),
            onTap: sync.isAuthenticated
                ? () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset cloud data?'),
                        content: const Text('This will permanently delete all data stored in Dropbox. This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<SyncProvider>().resetCloud();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cloud data deleted')),
                        );
                      }
                    }
                  }
                : null,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Journal App'),
            subtitle: Text('Version 0.1.0'),
          ),
        ],
      ),
    );
  }

  void _showSetPinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Enter PIN', counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final pin = controller.text;
              if (pin.length >= 4) {
                context.read<AuthProvider>().setPin(pin);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN set successfully')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

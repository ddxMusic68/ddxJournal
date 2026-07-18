import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sync_provider.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _appKeyController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _waitingForCode = false;

  @override
  void dispose() {
    _appKeyController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _connect() async {
    final appKey = _appKeyController.text.trim();
    if (appKey.isEmpty) return;

    final sync = context.read<SyncProvider>();
    await sync.openAuthUrl(appKey);

    setState(() => _waitingForCode = true);
    _showCodeDialog(appKey);
  }

  void _showCodeDialog(String appKey) {
    _codeController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Authorization Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy the authorization code from the Dropbox page and paste it below.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: 'Authorization code',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _waitingForCode = false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<SyncProvider>().submitAuthCode(appKey, code);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Dropbox Sync')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: sync.isAuthenticated
              ? _buildConnected(context, sync)
              : _buildDisconnected(context, sync),
        ),
      ),
    );
  }

  Widget _buildDisconnected(BuildContext context, SyncProvider sync) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off,
          size: 80,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 24),
        Text(
          'Dropbox Sync',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Sync your journal across devices',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _appKeyController,
          decoration: const InputDecoration(
            hintText: 'Dropbox App Key',
            border: OutlineInputBorder(),
            helperText: 'Create an app at dropbox.com/developers',
          ),
        ),
        if (sync.syncError != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            sync.syncError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _waitingForCode ? null : _connect,
            child: _waitingForCode
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ),
      ],
    );
  }

  Widget _buildConnected(BuildContext context, SyncProvider sync) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_done,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Dropbox Sync',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Connected',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        SwitchListTile(
          title: const Text('Sync Enabled'),
          value: sync.isSyncEnabled,
          onChanged: (value) {
            if (!value) {
              sync.disableSync();
            }
          },
        ),
        if (sync.lastSyncTime != null)
          ListTile(
            title: const Text('Last synced'),
            subtitle: Text(DateFormat.yMMMd().add_jm().format(sync.lastSyncTime!)),
          ),
        if (sync.syncError != null)
          ListTile(
            title: const Text('Error'),
            subtitle: SelectableText(
              sync.syncError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: sync.isSyncing ? null : () => sync.syncNow(),
            icon: sync.isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(sync.isSyncing ? 'Syncing...' : 'Sync Now'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => sync.disableSync(),
            child: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }
}

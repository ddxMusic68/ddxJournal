import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/journal_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  await authProvider.init();

  final syncProvider = SyncProvider();
  await syncProvider.init();

  final journalProvider = JournalProvider();
  syncProvider.onSyncComplete = () {
    journalProvider.loadMonth(journalProvider.selectedMonth.year, journalProvider.selectedMonth.month);
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: journalProvider),
        ChangeNotifierProvider.value(value: syncProvider),
      ],
      child: const JournalApp(),
    ),
  );
}

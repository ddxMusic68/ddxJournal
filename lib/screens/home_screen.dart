import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/journal_provider.dart';
import 'entry_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      context.read<JournalProvider>().loadMonth(now.year, now.month);
    });
  }

  void _onDayTap(DateTime date) async {
    final journal = context.read<JournalProvider>();
    final existing = await journal.getEntryForDate(date);
    if (!mounted) return;

    if (existing != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EntryScreen(entry: existing)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EntryScreen(entryDate: date)),
      );
    }

    if (!mounted) return;
    journal.loadMonth(journal.selectedMonth.year, journal.selectedMonth.month);
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final month = journal.selectedMonth;
    final year = month.year;
    final monthNum = month.month;
    final daysInMonth = DateTime(year, monthNum + 1, 0).day;
    final firstWeekday = DateTime(year, monthNum, 1).weekday % 7;
    final today = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: journal.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: journal.previousMonth,
                      ),
                      Text(
                        DateFormat.yMMMM().format(month),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: journal.nextMonth,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 7,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1,
                    children: List.generate(42, (index) {
                      final dayOffset = index - firstWeekday;
                      final day = dayOffset + 1;

                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox.shrink();
                      }

                      final date = DateTime(year, monthNum, day);
                      final hasEntry = journal.hasEntryForDate(date);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;

                      return GestureDetector(
                        onTap: () => _onDayTap(date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: hasEntry ? colorScheme.primary : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: hasEntry
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                                fontWeight: isToday || hasEntry
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}

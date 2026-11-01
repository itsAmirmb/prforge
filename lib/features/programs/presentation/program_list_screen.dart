import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/name_dialog.dart';
import '../../../core/widgets/state_views.dart';
import 'program_detail_screen.dart';
import 'program_providers.dart';

class ProgramListScreen extends ConsumerStatefulWidget {
  const ProgramListScreen({super.key});

  @override
  ConsumerState<ProgramListScreen> createState() => _ProgramListScreenState();
}

class _ProgramListScreenState extends ConsumerState<ProgramListScreen> {
  bool _showArchived = false;

  Future<void> _add() async {
    final name = await showNameDialog(context, title: 'New program');
    if (name == null) return;
    final id = await ref.read(programRepositoryProvider).add(name);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgramDetailScreen(programId: id),
      ),
    );
  }

  Future<void> _setArchived(Program p, bool archived) async {
    final repo = ref.read(programRepositoryProvider);
    await repo.setArchived(p.id, archived);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            archived ? '"${p.name}" archived' : '"${p.name}" restored',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.setArchived(p.id, !archived),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final programs = ref.watch(programListProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Archived programs' : 'Programs'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Show active' : 'Show archived',
            icon: Icon(
              _showArchived ? Icons.list_alt : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: programs.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(e),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: _showArchived
                  ? Icons.inventory_2_outlined
                  : Icons.list_alt_outlined,
              message: _showArchived
                  ? 'No archived programs'
                  : 'No programs yet. Tap + to create one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.fabClearance,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              return Card(
                child: ListTile(
                  leading: const IconBadge(icon: Icons.list_alt),
                  title: Text(
                    p.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProgramDetailScreen(programId: p.id),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: _showArchived ? 'Restore' : 'Archive',
                    icon: Icon(
                      _showArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    onPressed: () => _setArchived(p, !_showArchived),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              tooltip: 'New program',
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
    );
  }
}

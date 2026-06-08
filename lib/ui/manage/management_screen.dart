import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/management_repository.dart';

/// Tryb zarządzania tekstami (Windows): lista + walidacja oraz edycja
/// metadanych i kategorii w lokalnym repozytorium tekstów (folder na dysku).
class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  String? _path;
  List<ManageEntry>? _entries;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = ref.read(managementServiceProvider).repoPath;
    if (_path != null) _load();
  }

  Future<void> _chooseFolder() async {
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath(lockParentWindow: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się otworzyć okna wyboru: $e')),
        );
      }
      return;
    }
    if (dir == null) return; // anulowano
    await ref.read(managementServiceProvider).setRepoPath(dir);
    setState(() => _path = dir);
    _load();
  }

  Future<void> _load() async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ref.read(managementServiceProvider).load(path);
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _edit(ManageEntry entry) async {
    final categories = <String>{
      for (final e in _entries ?? <ManageEntry>[]) e.category,
    }.toList()
      ..sort();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(entry: entry, categories: categories),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarządzanie tekstami'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _path == null ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _path ?? 'Nie wybrano folderu repozytorium tekstów',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Wybierz folder'),
                  onPressed: _chooseFolder,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_path == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Wskaż folder z plikiem index.json (lokalna kopia repo tekstów),\n'
            'aby zarządzać tekstami.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Błąd: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    final entries = _entries ?? const <ManageEntry>[];
    if (entries.isEmpty) {
      return const Center(child: Text('Brak tekstów w index.json.'));
    }

    final invalidCount = entries.where((e) => !e.valid).length;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${entries.length} tekstów · '
            '${invalidCount == 0 ? "wszystkie poprawne" : "$invalidCount z błędami"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final e in entries) _entryTile(e),
      ],
    );
  }

  Widget _entryTile(ManageEntry e) {
    final statusIcon = e.valid
        ? const Icon(Icons.check_circle, color: Colors.green)
        : const Icon(Icons.error, color: Colors.red);
    final subtitle = [
      e.category,
      if (e.level != null) e.level!,
      if (e.author != null) e.author!,
    ].join(' · ');

    if (e.valid) {
      return ListTile(
        leading: statusIcon,
        title: Text(e.title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Edytuj metadane',
          onPressed: () => _edit(e),
        ),
        onTap: () => _edit(e),
      );
    }
    // Niepoprawny — pokaż listę problemów.
    return ExpansionTile(
      leading: statusIcon,
      title: Text(e.title),
      subtitle: Text('$subtitle · ${e.issues.length} problemów'),
      childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
      children: [
        for (final issue in e.issues)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('• $issue',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edytuj metadane'),
            onPressed: () => _edit(e),
          ),
        ),
      ],
    );
  }
}

class _EditDialog extends ConsumerStatefulWidget {
  final ManageEntry entry;
  final List<String> categories;
  const _EditDialog({required this.entry, required this.categories});

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _level;
  late final TextEditingController _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry.title);
    _author = TextEditingController(text: widget.entry.author ?? '');
    _level = TextEditingController(text: widget.entry.level ?? '');
    _category = TextEditingController(text: widget.entry.category);
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _level.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final path = ref.read(managementServiceProvider).repoPath;
    if (path == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(managementServiceProvider).saveMetadata(
            path,
            widget.entry.id,
            title: _title.text.trim(),
            author: _author.text.trim(),
            level: _level.text.trim(),
            category: _category.text.trim().isEmpty
                ? 'Ogólne'
                : _category.text.trim(),
          );
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(
        content: Text('Zapisano. Pamiętaj o git commit + push.'),
      ));
    } catch (e) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edytuj: ${widget.entry.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Tytuł'),
            ),
            TextField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Autor (opcjonalnie)'),
            ),
            TextField(
              controller: _level,
              decoration:
                  const InputDecoration(labelText: 'Poziom (np. B1, opcjonalnie)'),
            ),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Kategoria'),
            ),
            if (widget.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final c in widget.categories)
                      ActionChip(
                        label: Text(c),
                        onPressed: () => _category.text = c,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Zapisz'),
        ),
      ],
    );
  }
}

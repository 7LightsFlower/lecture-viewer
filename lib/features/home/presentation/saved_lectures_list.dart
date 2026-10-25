import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lecture_viewer_v3/core/lecture_snapshot/lecture_snapshot_provider.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/format/saved_lecture_last_join_format.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lecture.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';
import 'package:lecture_viewer_v3/features/lecture_session/presentation/lecture_share_from_snapshot.dart';

class SavedLecturesList extends ConsumerStatefulWidget {
  const SavedLecturesList({super.key});

  @override
  ConsumerState<SavedLecturesList> createState() => _SavedLecturesListState();
}

class _SavedLecturesListState extends ConsumerState<SavedLecturesList> {
  final Set<String> _selectedIds = {};

  Future<void> _confirmDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved lectures?'),
        content: Text('Delete $count saved lecture${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(savedLecturesProvider.notifier).removeByIds(_selectedIds);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
  }

  void _toggleSelection(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _openLecture(SavedLecture lecture) async {
    final joined = await openLectureSessionFromLinkRecord(
      context,
      lecture.linkRecord,
      sessionName: lecture.displayName,
      joinUrl: lecture.joinUrl,
    );
    if (!mounted) return;
    if (!joined) {
      final invalidLink = meetingNameFromLinkRecord(lecture.linkRecord) == null;
      if (invalidLink) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid session link')),
        );
      }
      return;
    }
    await ref.read(savedLecturesProvider.notifier).recordLastJoin(lecture.id);
  }

  Future<void> _renameLecture(SavedLecture lecture) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameLectureDialog(initialName: lecture.displayName),
    );
    if (newName == null || !mounted) return;
    final ok = await ref
        .read(savedLecturesProvider.notifier)
        .updateDisplayName(lecture.id, newName);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename lecture')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lectures = ref.watch(savedLecturesProvider);
    final hasSelection = _selectedIds.isNotEmpty;

    return Column(
      children: [
        if (hasSelection)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('${_selectedIds.length} selected'),
                  const Spacer(),
                  TextButton(
                    onPressed: _confirmDelete,
                    child: Text('Delete selected (${_selectedIds.length})'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lectures.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              final selected = _selectedIds.contains(lecture.id);
              return _SavedLectureListTile(
                lecture: lecture,
                selected: selected,
                locale: Localizations.localeOf(context),
                onToggleSelection: (v) => _toggleSelection(lecture.id, v),
                onJoin: () => _openLecture(lecture),
                onRename: () => _renameLecture(lecture),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedLectureListTile extends StatelessWidget {
  const _SavedLectureListTile({
    required this.lecture,
    required this.selected,
    required this.locale,
    required this.onToggleSelection,
    required this.onJoin,
    required this.onRename,
  });

  final SavedLecture lecture;
  final bool selected;
  final Locale locale;
  final ValueChanged<bool?> onToggleSelection;
  final VoidCallback onJoin;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: selected,
        onChanged: onToggleSelection,
      ),
      title: Text(lecture.displayName),
      subtitle: Text(
        '${lecture.sessionId}\n'
        '${formatSavedLectureLastJoinTime(
          lecture.lastJoinedAt,
          now: DateTime.now(),
          locale: locale,
        )}',
      ),
      isThreeLine: true,
      trailing: _SavedLectureListTrailing(
        linkRecord: lecture.linkRecord,
        displayName: lecture.displayName,
        onRename: onRename,
      ),
      onTap: onJoin,
    );
  }
}

class _SavedLectureListTrailing extends ConsumerWidget {
  const _SavedLectureListTrailing({
    required this.linkRecord,
    required this.displayName,
    required this.onRename,
  });

  final String linkRecord;
  final String displayName;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showShare = ref.watch(lectureSnapshotShareableProvider(linkRecord)).maybeWhen(
      data: (shareable) => shareable,
      orElse: () => false,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showShare)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => showLectureShareFromLinkRecord(
              context,
              ref,
              linkRecord: linkRecord,
              displayName: displayName,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Rename lecture',
          onPressed: onRename,
        ),
      ],
    );
  }
}

class _RenameLectureDialog extends StatefulWidget {
  const _RenameLectureDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameLectureDialog> createState() => _RenameLectureDialogState();
}

class _RenameLectureDialogState extends State<_RenameLectureDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename lecture'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Lecture name',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

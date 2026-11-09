import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lecture_viewer_v3/features/lecture_session/domain/share/cached_text_fetcher.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/lecture_share_input.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/meeting_share_filename.dart';
import 'package:lecture_viewer_v3/features/lecture_session/domain/share/pdf_generator.dart';

Future<void> showLectureShareSheet({
  required BuildContext context,
  required LectureShareInput input,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _LectureShareSheet(input: input),
  );
}

enum _LoadStatus { none, loading, ready, failed }

class _LectureShareSheet extends StatefulWidget {
  const _LectureShareSheet({required this.input});

  final LectureShareInput input;

  @override
  State<_LectureShareSheet> createState() => _LectureShareSheetState();
}

class _LectureShareSheetState extends State<_LectureShareSheet> {
  final Set<String> _selected = {};
  final Map<String, _LoadStatus> _loadStatus = {};
  final Map<String, Uint8List> _pdfCache = {};
  final Map<String, int> _loadToken = {};
  final Map<String, http.Client> _clients = {};
  bool _sharing = false;

  bool get _hasAnyLoading =>
      _loadStatus.values.any((status) => status == _LoadStatus.loading);

  bool get _canShare =>
      !_hasAnyLoading &&
      _selected.any(
        (language) =>
            _loadStatus[language] == _LoadStatus.ready &&
            _pdfCache.containsKey(language),
      );

  bool _allSelected(List<String> languages) =>
      languages.isNotEmpty && languages.every(_selected.contains);

  @override
  void dispose() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
    _pdfCache.clear();
    super.dispose();
  }

  void _closeSheet() {
    if (_sharing) return;
    Navigator.of(context).pop();
  }

  void _invalidateLoad(String language) {
    _loadToken[language] = (_loadToken[language] ?? 0) + 1;
  }

  void _deselectLanguage(String language) {
    if ((_loadStatus[language] ?? _LoadStatus.none) == _LoadStatus.loading) {
      _invalidateLoad(language);
      _clients.remove(language)?.close();
      setState(() {
        _loadStatus[language] =
            _pdfCache.containsKey(language) ? _LoadStatus.ready : _LoadStatus.none;
      });
    }
    setState(() => _selected.remove(language));
  }

  void _clearAll(List<String> languages) {
    for (final language in languages) {
      if ((_loadStatus[language] ?? _LoadStatus.none) == _LoadStatus.loading) {
        _invalidateLoad(language);
        _clients.remove(language)?.close();
        _loadStatus[language] = _pdfCache.containsKey(language)
            ? _LoadStatus.ready
            : _LoadStatus.none;
      }
    }
    setState(() => _selected.clear());
  }

  void _selectLanguage(String language) {
    if (_pdfCache.containsKey(language)) {
      setState(() {
        _selected.add(language);
        _loadStatus[language] = _LoadStatus.ready;
      });
      return;
    }
    _startLoad(language);
  }

  void _onLanguageToggled(String language, bool? checked) {
    if (_sharing) return;
    if (checked == true) {
      _selectLanguage(language);
      return;
    }
    _deselectLanguage(language);
  }

  void _selectAll(List<String> languages) {
    if (_sharing) return;

    final pending = Queue<String>();
    setState(() {
      for (final language in languages) {
        _selected.add(language);
        if (_pdfCache.containsKey(language)) {
          _loadStatus[language] = _LoadStatus.ready;
          continue;
        }
        if ((_loadStatus[language] ?? _LoadStatus.none) == _LoadStatus.loading) {
          continue;
        }
        _loadStatus[language] = _LoadStatus.loading;
        pending.add(language);
      }
    });

    if (pending.isEmpty) return;

    var inFlight = 0;

    void pump() {
      while (pending.isNotEmpty && inFlight < kShareSelectAllFetchConcurrency) {
        final language = pending.removeFirst();
        inFlight++;
        _startLoad(language).whenComplete(() {
          inFlight--;
          pump();
        });
      }
    }

    pump();
  }

  Future<void> _startLoad(String language) async {
    _invalidateLoad(language);
    final token = _loadToken[language]!;

    setState(() {
      _selected.add(language);
      _loadStatus[language] = _LoadStatus.loading;
    });

    final client = http.Client();
    _clients[language] = client;

    try {
      final html = await fetchCachedText(
        sessionId: widget.input.sessionId,
        language: language,
        httpsOrigin: widget.input.httpsOrigin,
        client: client,
      );
      if (!_isCurrentLoad(language, token)) return;

      final pdfBytes = await htmlToPdfBytes(html);
      if (!_isCurrentLoad(language, token)) return;

      if (!mounted) return;
      setState(() {
        _loadStatus[language] = _LoadStatus.ready;
        _pdfCache[language] = pdfBytes;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('share load failed ($language): $e');
      if (!_isCurrentLoad(language, token)) return;
      if (!mounted) return;
      setState(() {
        _loadStatus[language] = _LoadStatus.failed;
        _selected.remove(language);
        _pdfCache.remove(language);
      });
    } finally {
      if (_clients.remove(language) != null) {
        client.close();
      }
    }
  }

  bool _isCurrentLoad(String language, int token) =>
      mounted && _loadToken[language] == token;

  Future<void> _shareSelected() async {
    if (_sharing || !_canShare) return;

    setState(() => _sharing = true);
    final tempPaths = <String>[];

    try {
      final now = DateTime.now();
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];

      for (final language in widget.input.activeLanguages) {
        if (!_selected.contains(language)) continue;
        if (_loadStatus[language] != _LoadStatus.ready) continue;
        final pdfBytes = _pdfCache[language];
        if (pdfBytes == null) continue;

        final path =
            '${dir.path}/${meetingSharePdfFileNameForLanguage(now, language)}';
        await File(path).writeAsBytes(pdfBytes, flush: true);
        tempPaths.add(path);
        files.add(XFile(path));
      }

      if (files.isEmpty) return;

      await SharePlus.instance.share(
        ShareParams(files: files, subject: widget.input.subject),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (kDebugMode) debugPrint('share failed: $e');
    } finally {
      for (final path in tempPaths) {
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget? _subtitle(BuildContext context, String language) {
    final loadStatus = _loadStatus[language] ?? _LoadStatus.none;
    final colorScheme = Theme.of(context).colorScheme;

    if (loadStatus == _LoadStatus.failed) {
      return Text(
        'Unexpected error, please retry!',
        style: TextStyle(color: colorScheme.error),
      );
    }

    if (!_selected.contains(language)) return null;

    final String? text = switch (loadStatus) {
      _LoadStatus.loading => 'Loading data...',
      _LoadStatus.ready => 'Ready to share',
      _ => null,
    };
    if (text == null) return null;

    final color = loadStatus == _LoadStatus.ready
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Text(text, style: TextStyle(color: color));
  }

  @override
  Widget build(BuildContext context) {
    final languages = widget.input.activeLanguages;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: _sharing ? null : _closeSheet,
                  ),
                ],
              ),
              if (languages.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _sharing
                        ? null
                        : () {
                            if (_allSelected(languages)) {
                              _clearAll(languages);
                            } else {
                              _selectAll(languages);
                            }
                          },
                    child: Text(
                      _allSelected(languages) ? 'Clear all' : 'Select all',
                    ),
                  ),
                ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final language in languages)
                      CheckboxListTile(
                        title: Text(language),
                        subtitle: _subtitle(context, language),
                        value: _selected.contains(language),
                        enabled: !_sharing,
                        onChanged: _sharing
                            ? null
                            : (value) => _onLanguageToggled(language, value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _sharing || !_canShare ? null : _shareSelected,
                child: _sharing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

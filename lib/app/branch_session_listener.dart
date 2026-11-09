import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

import 'package:lecture_viewer_v3/app/app_navigator.dart';
import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';
import 'package:lecture_viewer_v3/core/util/open_lecture_session.dart';

class BranchSessionListener extends StatefulWidget {
  const BranchSessionListener({required this.child, super.key});

  final Widget child;

  @override
  State<BranchSessionListener> createState() => _BranchSessionListenerState();
}

class _BranchSessionListenerState extends State<BranchSessionListener> {
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  String? _lastLinkRecord;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // No Branch in the browser: open `?link=<app link | link_record | name>`
      // from the page URL instead.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPageUrl());
      return;
    }
    _subscription = FlutterBranchSdk.listSession().listen(
      _onSession,
      onError: (_) {},
    );
  }

  Future<void> _openFromPageUrl([int attempt = 0]) async {
    final params = Uri.base.queryParameters;
    final raw = params['link'] ?? params['link_record'];
    if (raw == null || raw.trim().isEmpty) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      // MaterialApp may not have built its navigator on the first frame yet.
      if (attempt < 20 && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (mounted) await _openFromPageUrl(attempt + 1);
      }
      return;
    }
    final ok = await openLectureSessionFromUserInput(nav.context, raw);
    if (!ok && kDebugMode) debugPrint('[web] could not open link from URL: $raw');
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _onSession(Map<dynamic, dynamic> data) async {
    if (data['+clicked_branch_link'] != true) return;
    final linkRecord = linkRecordFromBranchSession(data);
    if (linkRecord == null) {
      _showMessage('Missing session link');
      return;
    }
    if (_isDuplicate(linkRecord)) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      _showMessage('Could not open session');
      return;
    }
    final sessionName = sessionNameFromBranchSession(data);
    final joinUrl = joinUrlFromBranchSession(data);
    final ok = await openLectureSessionFromLinkRecord(
      nav.context,
      linkRecord,
      sessionName: sessionName,
      joinUrl: joinUrl,
    );
    if (!mounted) return;
    if (!ok) _showMessage('Invalid session link');
  }

  bool _isDuplicate(String linkRecord) {
    final now = DateTime.now();
    if (_lastLinkRecord == linkRecord &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastLinkRecord = linkRecord;
    _lastHandledAt = now;
    return false;
  }

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

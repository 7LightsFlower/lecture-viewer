import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:lecture_viewer_v3/core/providers/app_settings_notifier.dart';

class WakelockLifecycleBinding extends ConsumerStatefulWidget {
  const WakelockLifecycleBinding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WakelockLifecycleBinding> createState() =>
      _WakelockLifecycleBindingState();
}

class _WakelockLifecycleBindingState
    extends ConsumerState<WakelockLifecycleBinding>
    with WidgetsBindingObserver {
  bool _retryPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_syncWakelock());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_setWakelock(enabled: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_syncWakelock(lifecycle: state));
  }

  Future<void> _syncWakelock({AppLifecycleState? lifecycle}) async {
    final keepOn = ref.read(appSettingsProvider).keepScreenOn;
    final resumed =
        (lifecycle ?? WidgetsBinding.instance.lifecycleState) ==
        AppLifecycleState.resumed;
    await _setWakelock(enabled: keepOn && resumed);
  }

  Future<void> _setWakelock({required bool enabled}) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } on PlatformException catch (error) {
      if (error.code != 'NoActivityException') {
        rethrow;
      }
      if (enabled) {
        _scheduleWakelockRetry();
      }
    }
  }

  void _scheduleWakelockRetry() {
    if (_retryPending || !mounted) {
      return;
    }
    _retryPending = true;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      _retryPending = false;
      if (mounted) {
        unawaited(_syncWakelock());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider.select((s) => s.keepScreenOn), (_, _) {
      unawaited(_syncWakelock());
    });
    return widget.child;
  }
}

import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:lecture_viewer_v3/core/bootstrap/soloud_engine.dart';

/// Tears down SoLoud when the app process exits or the engine detaches.
///
/// Hot restart is handled in [releaseStaleSoloudEngine] at startup because
/// [dispose] here is not guaranteed to run before the isolate is torn down.
class LectureSoloudLifecycleBinding extends StatefulWidget {
  const LectureSoloudLifecycleBinding({required this.child, super.key});

  final Widget child;

  @override
  State<LectureSoloudLifecycleBinding> createState() =>
      _LectureSoloudLifecycleBindingState();
}

class _LectureSoloudLifecycleBindingState
    extends State<LectureSoloudLifecycleBinding> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onDetach: disposeSoloudEngine,
      onExitRequested: () async {
        disposeSoloudEngine();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    disposeSoloudEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

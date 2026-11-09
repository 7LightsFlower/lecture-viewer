import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/app/branch_session_listener.dart';
import 'package:lecture_viewer_v3/app/lecture_viewer_app.dart';
import 'package:lecture_viewer_v3/app/soloud_lifecycle_binding.dart';
import 'package:lecture_viewer_v3/app/wakelock_lifecycle_binding.dart';
import 'package:lecture_viewer_v3/core/bootstrap/configure_lecture_tts_audio_session.dart';
import 'package:lecture_viewer_v3/core/bootstrap/init_lecture_tts_audio_service.dart';
import 'package:lecture_viewer_v3/core/bootstrap/soloud_engine.dart';
import 'package:lecture_viewer_v3/core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureLectureTtsAudioSession();
  await initLectureTtsAudioService();
  await initializeSoloudEngine();
  // Branch needs its own JS SDK in a browser; deep links come via ?link= there.
  if (!kIsWeb) await FlutterBranchSdk.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LectureSoloudLifecycleBinding(
        child: WakelockLifecycleBinding(
          child: BranchSessionListener(child: LectureViewerApp()),
        ),
      ),
    ),
  );
}

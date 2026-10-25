import 'package:url_launcher/url_launcher.dart';

import 'package:lecture_viewer_v3/core/util/lecture_app_link.dart';

/// Opens resolved session URL in the system browser.
/// Returns false if launch failed.
Future<bool> handleLectureSessionLink(String linkRecord) async {
  final url = Uri.parse(resolveSessionUrl(linkRecord));
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

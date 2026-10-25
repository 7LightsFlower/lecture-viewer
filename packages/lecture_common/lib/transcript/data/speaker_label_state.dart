import 'package:flutter/foundation.dart';

@immutable
class SpeakerLabelState {
  const SpeakerLabelState({
    required this.show,
    required this.speakerName,
  });

  final bool show;
  final String speakerName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'show': show,
        'speakerName': speakerName,
      };

  factory SpeakerLabelState.fromJson(Map<String, dynamic> json) {
    return SpeakerLabelState(
      show: json['show'] == true,
      speakerName: json['speakerName']?.toString() ?? '',
    );
  }
}

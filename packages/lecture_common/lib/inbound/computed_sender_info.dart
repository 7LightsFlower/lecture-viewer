class ComputedSenderInfo {
  const ComputedSenderInfo({
    required this.language,
    required this.type,
    required this.percent,
    this.langCode,
  });

  final String language;
  final String type;
  final int percent;
  final String? langCode;

  Map<String, dynamic> toJson() => {
        'language': language,
        'type': type,
        'percent': percent,
        if (langCode != null) 'langCode': langCode,
      };

  factory ComputedSenderInfo.fromJson(Map<String, dynamic> json) {
    return ComputedSenderInfo(
      language: json['language'] as String,
      type: json['type'] as String,
      percent: json['percent'] as int,
      langCode: json['langCode'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ComputedSenderInfo &&
        other.language == language &&
        other.type == type &&
        other.percent == percent &&
        other.langCode == langCode;
  }

  @override
  int get hashCode => Object.hash(language, type, percent, langCode);
}

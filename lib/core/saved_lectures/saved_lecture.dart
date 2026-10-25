class SavedLecture {
  const SavedLecture({
    required this.id,
    required this.displayName,
    required this.linkRecord,
    required this.sessionId,
    required this.savedAt,
    required this.lastJoinedAt,
    this.joinUrl,
  });

  final String id;
  final String displayName;
  final String linkRecord;
  final String sessionId;
  final String savedAt;
  final String lastJoinedAt;
  final String? joinUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'linkRecord': linkRecord,
        'sessionId': sessionId,
        'savedAt': savedAt,
        'lastJoinedAt': lastJoinedAt,
        'joinUrl': joinUrl,
      };

  factory SavedLecture.fromJson(Map<String, dynamic> json) {
    final savedAt = json['savedAt'] as String;
    final rawJoinUrl = json['joinUrl'] as String?;
    final trimmedJoinUrl = rawJoinUrl?.trim();
    return SavedLecture(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      linkRecord: json['linkRecord'] as String,
      sessionId: json['sessionId'] as String,
      savedAt: savedAt,
      lastJoinedAt: json['lastJoinedAt'] as String? ?? savedAt,
      joinUrl: (trimmedJoinUrl == null || trimmedJoinUrl.isEmpty)
          ? null
          : trimmedJoinUrl,
    );
  }

  SavedLecture copyWith({
    String? displayName,
    String? lastJoinedAt,
    String? joinUrl,
  }) {
    return SavedLecture(
      id: id,
      displayName: displayName ?? this.displayName,
      linkRecord: linkRecord,
      sessionId: sessionId,
      savedAt: savedAt,
      lastJoinedAt: lastJoinedAt ?? this.lastJoinedAt,
      joinUrl: joinUrl ?? this.joinUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedLecture &&
        other.id == id &&
        other.displayName == displayName &&
        other.linkRecord == linkRecord &&
        other.sessionId == sessionId &&
        other.savedAt == savedAt &&
        other.lastJoinedAt == lastJoinedAt &&
        other.joinUrl == joinUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        linkRecord,
        sessionId,
        savedAt,
        lastJoinedAt,
        joinUrl,
      );
}

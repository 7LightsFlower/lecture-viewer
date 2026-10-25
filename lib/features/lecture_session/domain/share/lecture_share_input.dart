class LectureShareInput {
  const LectureShareInput({
    required this.subject,
    required this.activeLanguages,
    required this.sessionId,
    required this.httpsOrigin,
  });

  final String subject;
  final List<String> activeLanguages;
  final String sessionId;
  final String httpsOrigin;
}

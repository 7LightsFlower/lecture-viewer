String lectureBucketKey({
  required String languageDisplayName,
  required String rawSender,
}) =>
    '$languageDisplayName|$rawSender';

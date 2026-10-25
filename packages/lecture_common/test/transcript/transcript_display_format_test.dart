import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_common/lecture_common.dart';

void main() {
  test('speakerNameForDisplay strips hash only when requested', () {
    expect(
      speakerNameForDisplay('Speaker #1', stripHash: true),
      'Speaker 1',
    );
    expect(
      speakerNameForDisplay('Speaker #1', stripHash: false),
      'Speaker #1',
    );
  });

  group('stripLeadingSpaceBeforePunctuation', () {
    test('removes leading spaces/tabs before punctuation', () {
      expect(stripLeadingSpaceBeforePunctuation(' , which is'), ', which is');
      expect(stripLeadingSpaceBeforePunctuation('\t)'), ')');
      expect(stripLeadingSpaceBeforePunctuation('  .'), '.');
    });

    test('leaves text without leading space-before-punct unchanged', () {
      expect(stripLeadingSpaceBeforePunctuation(', which is'), ', which is');
      expect(stripLeadingSpaceBeforePunctuation(' which is'), ' which is');
      expect(stripLeadingSpaceBeforePunctuation('hello'), 'hello');
    });
  });

  group('needsInsertedSpaceBetween', () {
    test('does not insert before punctuation (with or without leading space)', () {
      expect(needsInsertedSpaceBetween('laptop', ', which is'), isFalse);
      expect(needsInsertedSpaceBetween('laptop', ' , which is'), isFalse);
      expect(needsInsertedSpaceBetween('which is', ', you know'), isFalse);
    });

    test('still inserts between normal words', () {
      expect(needsInsertedSpaceBetween('laptop', 'which is'), isTrue);
    });

    test('does not double-space when either side already has whitespace', () {
      expect(needsInsertedSpaceBetween('laptop ', 'which'), isFalse);
      expect(needsInsertedSpaceBetween('laptop', ' which'), isFalse);
    });
  });

  group('partialWithGap', () {
    test('does not prefix space before punctuation partial', () {
      expect(
        partialWithGap(previousText: 'laptop', partial: ', which'),
        ', which',
      );
      expect(
        partialWithGap(previousText: 'laptop', partial: ' , which'),
        ', which',
      );
    });

    test('still prefixes space for normal partial', () {
      expect(
        partialWithGap(previousText: 'laptop', partial: 'which'),
        ' which',
      );
    });
  });
}

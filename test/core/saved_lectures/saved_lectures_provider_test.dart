import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lecture_viewer_v3/core/providers/core_providers.dart';
import 'package:lecture_viewer_v3/core/saved_lectures/saved_lectures_provider.dart';

void main() {
  test('add updates provider state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    const linkRecord = 'host/mobile/session/foo-lecture';
    final ok = await container.read(savedLecturesProvider.notifier).add(
          displayName: 'My lecture',
          linkRecord: linkRecord,
          sessionId: 'foo-lecture',
        );
    expect(ok, isTrue);

    final list = container.read(savedLecturesProvider);
    expect(list, hasLength(1));
    expect(list.first.displayName, 'My lecture');
    expect(list.first.linkRecord, linkRecord);
  });

  test('add without displayName uses default date name', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    final ok = await notifier.add(
      linkRecord: 'host/mobile/session/a',
      sessionId: 'a',
      locale: const Locale('en', 'US'),
      now: DateTime(2026, 5, 20),
    );
    expect(ok, isTrue);
    expect(
      container.read(savedLecturesProvider).single.displayName,
      'May 20, 2026',
    );
  });

  test('updateDisplayName updates state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    await notifier.add(
      displayName: 'Original',
      linkRecord: 'host/mobile/session/a',
      sessionId: 'a',
    );
    expect(
      await notifier.updateDisplayName(
        container.read(savedLecturesProvider).single.id,
        'Renamed',
      ),
      isTrue,
    );
    expect(
      container.read(savedLecturesProvider).single.displayName,
      'Renamed',
    );
  });

  test('add persists joinUrl', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/foo-lecture';
    final ok = await container.read(savedLecturesProvider.notifier).add(
          displayName: 'My lecture',
          linkRecord: 'host/mobile/session/foo-lecture',
          sessionId: 'foo-lecture',
          joinUrl: url,
        );
    expect(ok, isTrue);
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
  });

  test('setJoinUrlIfMissing updates provider state once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(savedLecturesProvider.notifier);
    await notifier.add(
      displayName: 'My lecture',
      linkRecord: 'host/mobile/session/foo-lecture',
      sessionId: 'foo-lecture',
    );
    const url =
        'https://lectureviewer.app.link/x?link_record=host/mobile/session/foo-lecture';
    expect(
      await notifier.setJoinUrlIfMissing(
        'host/mobile/session/foo-lecture',
        url,
      ),
      isTrue,
    );
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
    expect(
      await notifier.setJoinUrlIfMissing(
        'host/mobile/session/foo-lecture',
        'https://lectureviewer.app.link/other?link_record=host/mobile/session/foo-lecture',
      ),
      isFalse,
    );
    expect(container.read(savedLecturesProvider).single.joinUrl, url);
  });
}

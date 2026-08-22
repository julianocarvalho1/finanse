import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantém suporte mínimo ao Android 7 e assinatura release protegida', () {
    final String gradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(gradle, contains('minSdk = 24'));
    expect(gradle, contains('applicationId = "com.finanse.finanse"'));
    expect(
      gradle,
      contains('releaseTaskRequested && !releaseSigningConfigured'),
    );
    expect(gradle, contains('A assinatura release não está configurada.'));
  });

  test(
    'manifesto protege backups e limita permissões às funções declaradas',
    () {
      final String manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, isNot(contains('android.permission.INTERNET')));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
      expect(
        RegExp(
          r'ScheduledNotificationReceiver[\s\S]*?android:exported="false"',
        ).hasMatch(manifest),
        isTrue,
      );
      expect(
        RegExp(
          r'ScheduledNotificationBootReceiver[\s\S]*?android:exported="false"',
        ).hasMatch(manifest),
        isTrue,
      );
    },
  );
}

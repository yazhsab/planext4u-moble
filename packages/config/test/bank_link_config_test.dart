import 'package:flutter_test/flutter_test.dart';
import 'package:planext4u_config/planext4u_config.dart';

void main() {
  test(
    'bank launch requires an explicit origin and secure production transport',
    () {
      expect(
        AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: '',
        ).bankLinkLaunchOrigin,
        isNull,
      );
      expect(
        AppConfig.fromPublicDefines({
          'APP_ENV': 'production',
          'BANK_LINK_LAUNCH_ORIGIN': 'https://bank.example.test',
        }).bankLinkLaunchOrigin,
        Uri.parse('https://bank.example.test'),
      );
      for (final value in [
        'http://bank.example.test',
        'https://bank.example.test/path',
        'https://secret@bank.example.test',
        'https://bank.example.test?secret=x',
        'https://bank.example.test#secret',
      ]) {
        expect(
          () => AppConfig.parse(
            rawEnvironment: 'production',
            rawApiBaseUrl: '',
            rawBankLinkLaunchOrigin: value,
          ),
          throwsFormatException,
        );
      }
      expect(
        AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: '',
          rawBankLinkLaunchOrigin: 'http://127.0.0.1:18081',
        ).bankLinkLaunchOrigin,
        Uri.parse('http://127.0.0.1:18081'),
      );
      expect(
        () => AppConfig.parse(
          rawEnvironment: 'development',
          rawApiBaseUrl: '',
          rawBankLinkLaunchOrigin: 'http://bank.example.test',
        ),
        throwsFormatException,
      );
    },
  );
}

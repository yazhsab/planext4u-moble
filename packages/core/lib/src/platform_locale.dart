const planext4uDefaultLocaleCode = 'en';

const planext4uSupportedLocaleCodes = <String>[
  'en',
  'ta',
  'hi',
  'te',
  'kn',
  'ml',
  'mr',
  'bn',
  'gu',
];

bool isPlanext4uLocaleCode(String value) =>
    planext4uSupportedLocaleCodes.contains(value);

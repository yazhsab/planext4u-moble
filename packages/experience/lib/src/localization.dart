import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

final class Planext4uLocalizations {
  const Planext4uLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ta')];
  static const LocalizationsDelegate<Planext4uLocalizations> delegate =
      _Planext4uLocalizationsDelegate();

  static Planext4uLocalizations of(BuildContext context) =>
      Localizations.of<Planext4uLocalizations>(
        context,
        Planext4uLocalizations,
      ) ??
      const Planext4uLocalizations(Locale('en'));

  Map<String, String> get _values =>
      _translations[locale.languageCode] ?? _translations['en']!;
  String get updateRequired => _values['update_required']!;
  String get updateRequiredMessage => _values['update_required_message']!;
  String get maintenanceTitle => _values['maintenance_title']!;
  String get maintenanceMessage => _values['maintenance_message']!;
  String get retry => _values['retry']!;
  String get locationTitle => _values['location_title']!;
  String get allowLocation => _values['allow_location']!;
  String get chooseManually => _values['choose_manually']!;
  String get homeTitle => _values['home_title']!;
  String get categories => _values['categories']!;
  String get featured => _values['featured']!;
  String get offlineData => _values['offline_data']!;
}

final class _Planext4uLocalizationsDelegate
    extends LocalizationsDelegate<Planext4uLocalizations> {
  const _Planext4uLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => {'en', 'ta'}.contains(locale.languageCode);
  @override
  Future<Planext4uLocalizations> load(Locale locale) =>
      SynchronousFuture(Planext4uLocalizations(locale));
  @override
  bool shouldReload(_Planext4uLocalizationsDelegate old) => false;
}

const _translations = <String, Map<String, String>>{
  'en': {
    'update_required': 'Update required',
    'update_required_message':
        'Install the latest Planext4u version to continue safely.',
    'maintenance_title': 'We’ll be back shortly',
    'maintenance_message': 'Planext4u is undergoing scheduled maintenance.',
    'retry': 'Try again',
    'location_title': 'Find services near you',
    'allow_location': 'Use my location',
    'choose_manually': 'Choose location manually',
    'home_title': 'Home',
    'categories': 'Categories',
    'featured': 'Featured near you',
    'offline_data': 'Showing saved information',
  },
  'ta': {
    'update_required': 'புதுப்பிப்பு தேவை',
    'update_required_message':
        'பாதுகாப்பாகத் தொடர Planext4u-வின் புதிய பதிப்பை நிறுவவும்.',
    'maintenance_title': 'விரைவில் மீண்டும் வருகிறோம்',
    'maintenance_message': 'Planext4u திட்டமிட்ட பராமரிப்பில் உள்ளது.',
    'retry': 'மீண்டும் முயற்சி',
    'location_title': 'அருகிலுள்ள சேவைகளைக் கண்டறியுங்கள்',
    'allow_location': 'என் இருப்பிடத்தைப் பயன்படுத்து',
    'choose_manually': 'இருப்பிடத்தைத் தேர்ந்தெடு',
    'home_title': 'முகப்பு',
    'categories': 'வகைகள்',
    'featured': 'உங்களுக்கு அருகிலுள்ள சிறப்புகள்',
    'offline_data': 'சேமித்த தகவல் காட்டப்படுகிறது',
  },
};

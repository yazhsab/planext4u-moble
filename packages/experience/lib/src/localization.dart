import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

final class Planext4uLocalizations {
  const Planext4uLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ta'),
    Locale('hi'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('bn'),
    Locale('gu'),
  ];
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
  String get exploreTitle => _values['explore_title']!;
  String get activityTitle => _values['activity_title']!;
  String get profileTitle => _values['profile_title']!;
  String get secureCheckout => _values['secure_checkout']!;
  String get deliveryAddress => _values['delivery_address']!;
  String get orderReview => _values['order_review']!;
  String get orders => _values['orders']!;
  String get points => _values['points']!;
  String get orderTracking => _values['order_tracking']!;
  String get payment => _values['payment']!;
  String get total => _values['total']!;
  String get cashOnDelivery => _values['cash_on_delivery']!;
  String get searchLocal => _values['search_local']!;
  String get allCategories => _values['all_categories']!;
  String availablePoints(int points) =>
      _values['available_points']!.replaceAll('{points}', '$points');

  @visibleForTesting
  static bool hasCompleteTranslation(Locale locale) {
    final english = _translations['en']!.keys.toSet();
    final translated = _translations[locale.languageCode];
    return translated != null && translated.keys.toSet().containsAll(english);
  }
}

final class _Planext4uLocalizationsDelegate
    extends LocalizationsDelegate<Planext4uLocalizations> {
  const _Planext4uLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => Planext4uLocalizations.supportedLocales
      .any((value) => value.languageCode == locale.languageCode);
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
    'explore_title': 'Explore',
    'activity_title': 'Activity',
    'profile_title': 'Profile',
    'secure_checkout': 'Secure checkout',
    'delivery_address': 'Delivery address',
    'order_review': 'Order review',
    'orders': 'Orders',
    'points': 'Points',
    'order_tracking': 'Order tracking',
    'payment': 'Payment',
    'total': 'Total',
    'cash_on_delivery': 'Cash on delivery',
    'available_points': 'Available: {points} points',
    'search_local': 'Search local products and services',
    'all_categories': 'All categories',
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
    'explore_title': 'தேடுங்கள்',
    'activity_title': 'செயல்பாடு',
    'profile_title': 'சுயவிவரம்',
    'secure_checkout': 'பாதுகாப்பான செக்அவுட்',
    'delivery_address': 'டெலிவரி முகவரி',
    'order_review': 'ஆர்டர் மதிப்பாய்வு',
    'orders': 'ஆர்டர்கள்',
    'points': 'புள்ளிகள்',
    'order_tracking': 'ஆர்டர் கண்காணிப்பு',
    'payment': 'கட்டணம்',
    'total': 'மொத்தம்',
    'cash_on_delivery': 'டெலிவரியின் போது பணம்',
    'available_points': 'கிடைக்கும்: {points} புள்ளிகள்',
    'search_local': 'உள்ளூர் பொருட்கள் மற்றும் சேவைகளைத் தேடுங்கள்',
    'all_categories': 'அனைத்து வகைகள்',
  },
  'hi': {
    'update_required': 'अपडेट आवश्यक है',
    'update_required_message':
        'सुरक्षित रूप से जारी रखने के लिए Planext4u का नवीनतम संस्करण इंस्टॉल करें।',
    'maintenance_title': 'हम शीघ्र वापस आएँगे',
    'maintenance_message': 'Planext4u पर निर्धारित रखरखाव चल रहा है।',
    'retry': 'फिर से प्रयास करें',
    'location_title': 'अपने पास की सेवाएँ खोजें',
    'allow_location': 'मेरे स्थान का उपयोग करें',
    'choose_manually': 'स्थान स्वयं चुनें',
    'home_title': 'होम',
    'categories': 'श्रेणियाँ',
    'featured': 'आपके पास चुनिंदा विकल्प',
    'offline_data': 'सहेजी गई जानकारी दिखाई जा रही है',
    'explore_title': 'खोजें',
    'activity_title': 'गतिविधि',
    'profile_title': 'प्रोफ़ाइल',
    'secure_checkout': 'सुरक्षित चेकआउट',
    'delivery_address': 'डिलीवरी का पता',
    'order_review': 'ऑर्डर की समीक्षा',
    'orders': 'ऑर्डर',
    'points': 'पॉइंट्स',
    'order_tracking': 'ऑर्डर ट्रैकिंग',
    'payment': 'भुगतान',
    'total': 'कुल',
    'cash_on_delivery': 'डिलीवरी पर नकद',
    'available_points': 'उपलब्ध: {points} पॉइंट्स',
    'search_local': 'स्थानीय उत्पाद और सेवाएँ खोजें',
    'all_categories': 'सभी श्रेणियाँ',
  },
  'te': {
    'update_required': 'అప్‌డేట్ అవసరం',
    'update_required_message':
        'సురక్షితంగా కొనసాగడానికి తాజా Planext4u సంస్కరణను ఇన్‌స్టాల్ చేయండి.',
    'maintenance_title': 'త్వరలో తిరిగి వస్తాము',
    'maintenance_message': 'Planext4u నిర్దేశిత నిర్వహణలో ఉంది.',
    'retry': 'మళ్లీ ప్రయత్నించండి',
    'location_title': 'మీ సమీపంలోని సేవలను కనుగొనండి',
    'allow_location': 'నా స్థానాన్ని ఉపయోగించండి',
    'choose_manually': 'స్థానాన్ని స్వయంగా ఎంచుకోండి',
    'home_title': 'హోమ్',
    'categories': 'వర్గాలు',
    'featured': 'మీ సమీపంలోని ప్రత్యేక ఎంపికలు',
    'offline_data': 'సేవ్ చేసిన సమాచారం చూపబడుతోంది',
    'explore_title': 'అన్వేషించండి',
    'activity_title': 'కార్యాచరణ',
    'profile_title': 'ప్రొఫైల్',
    'secure_checkout': 'సురక్షిత చెక్అవుట్',
    'delivery_address': 'డెలివరీ చిరునామా',
    'order_review': 'ఆర్డర్ సమీక్ష',
    'orders': 'ఆర్డర్లు',
    'points': 'పాయింట్లు',
    'order_tracking': 'ఆర్డర్ ట్రాకింగ్',
    'payment': 'చెల్లింపు',
    'total': 'మొత్తం',
    'cash_on_delivery': 'డెలివరీ సమయంలో నగదు',
    'available_points': 'అందుబాటులో: {points} పాయింట్లు',
    'search_local': 'స్థానిక ఉత్పత్తులు మరియు సేవలను వెతకండి',
    'all_categories': 'అన్ని వర్గాలు',
  },
  'kn': {
    'update_required': 'ನವೀಕರಣ ಅಗತ್ಯವಿದೆ',
    'update_required_message':
        'ಸುರಕ್ಷಿತವಾಗಿ ಮುಂದುವರಿಯಲು ಇತ್ತೀಚಿನ Planext4u ಆವೃತ್ತಿಯನ್ನು ಸ್ಥಾಪಿಸಿ.',
    'maintenance_title': 'ಶೀಘ್ರದಲ್ಲೇ ಮರಳುತ್ತೇವೆ',
    'maintenance_message': 'Planext4u ನಿಗದಿತ ನಿರ್ವಹಣೆಯಲ್ಲಿದೆ.',
    'retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    'location_title': 'ನಿಮ್ಮ ಹತ್ತಿರದ ಸೇವೆಗಳನ್ನು ಹುಡುಕಿ',
    'allow_location': 'ನನ್ನ ಸ್ಥಳವನ್ನು ಬಳಸಿ',
    'choose_manually': 'ಸ್ಥಳವನ್ನು ಕೈಯಾರೆ ಆಯ್ಕೆಮಾಡಿ',
    'home_title': 'ಮುಖಪುಟ',
    'categories': 'ವರ್ಗಗಳು',
    'featured': 'ನಿಮ್ಮ ಹತ್ತಿರದ ವಿಶೇಷ ಆಯ್ಕೆಗಳು',
    'offline_data': 'ಉಳಿಸಿದ ಮಾಹಿತಿಯನ್ನು ತೋರಿಸಲಾಗುತ್ತಿದೆ',
    'explore_title': 'ಅನ್ವೇಷಿಸಿ',
    'activity_title': 'ಚಟುವಟಿಕೆ',
    'profile_title': 'ಪ್ರೊಫೈಲ್',
    'secure_checkout': 'ಸುರಕ್ಷಿತ ಚೆಕ್ಔಟ್',
    'delivery_address': 'ವಿತರಣಾ ವಿಳಾಸ',
    'order_review': 'ಆರ್ಡರ್ ಪರಿಶೀಲನೆ',
    'orders': 'ಆರ್ಡರ್‌ಗಳು',
    'points': 'ಪಾಯಿಂಟ್‌ಗಳು',
    'order_tracking': 'ಆರ್ಡರ್ ಟ್ರ್ಯಾಕಿಂಗ್',
    'payment': 'ಪಾವತಿ',
    'total': 'ಒಟ್ಟು',
    'cash_on_delivery': 'ವಿತರಣೆಯ ವೇಳೆ ನಗದು',
    'available_points': 'ಲಭ್ಯ: {points} ಪಾಯಿಂಟ್‌ಗಳು',
    'search_local': 'ಸ್ಥಳೀಯ ಉತ್ಪನ್ನಗಳು ಮತ್ತು ಸೇವೆಗಳನ್ನು ಹುಡುಕಿ',
    'all_categories': 'ಎಲ್ಲಾ ವರ್ಗಗಳು',
  },
  'ml': {
    'update_required': 'അപ്‌ഡേറ്റ് ആവശ്യമാണ്',
    'update_required_message':
        'സുരക്ഷിതമായി തുടരാൻ ഏറ്റവും പുതിയ Planext4u പതിപ്പ് ഇൻസ്റ്റാൾ ചെയ്യുക.',
    'maintenance_title': 'ഞങ്ങൾ ഉടൻ മടങ്ങിവരും',
    'maintenance_message': 'Planext4u നിശ്ചിത പരിപാലനത്തിലാണ്.',
    'retry': 'വീണ്ടും ശ്രമിക്കുക',
    'location_title': 'സമീപത്തെ സേവനങ്ങൾ കണ്ടെത്തുക',
    'allow_location': 'എന്റെ സ്ഥാനം ഉപയോഗിക്കുക',
    'choose_manually': 'സ്ഥലം സ്വയം തിരഞ്ഞെടുക്കുക',
    'home_title': 'ഹോം',
    'categories': 'വിഭാഗങ്ങൾ',
    'featured': 'സമീപത്തെ തിരഞ്ഞെടുത്തവ',
    'offline_data': 'സംരക്ഷിച്ച വിവരങ്ങൾ കാണിക്കുന്നു',
    'explore_title': 'കണ്ടെത്തുക',
    'activity_title': 'പ്രവർത്തനം',
    'profile_title': 'പ്രൊഫൈൽ',
    'secure_checkout': 'സുരക്ഷിത ചെക്ക്ഔട്ട്',
    'delivery_address': 'ഡെലിവറി വിലാസം',
    'order_review': 'ഓർഡർ അവലോകനം',
    'orders': 'ഓർഡറുകൾ',
    'points': 'പോയിന്റുകൾ',
    'order_tracking': 'ഓർഡർ ട്രാക്കിംഗ്',
    'payment': 'പേയ്മെന്റ്',
    'total': 'ആകെ',
    'cash_on_delivery': 'ഡെലിവറിയിൽ പണം',
    'available_points': 'ലഭ്യം: {points} പോയിന്റുകൾ',
    'search_local': 'പ്രാദേശിക ഉൽപ്പന്നങ്ങളും സേവനങ്ങളും തിരയുക',
    'all_categories': 'എല്ലാ വിഭാഗങ്ങളും',
  },
  'mr': {
    'update_required': 'अपडेट आवश्यक आहे',
    'update_required_message':
        'सुरक्षितपणे पुढे जाण्यासाठी Planext4u ची नवीनतम आवृत्ती स्थापित करा.',
    'maintenance_title': 'आम्ही लवकरच परत येऊ',
    'maintenance_message': 'Planext4u चे नियोजित देखभाल कार्य सुरू आहे.',
    'retry': 'पुन्हा प्रयत्न करा',
    'location_title': 'तुमच्या जवळच्या सेवा शोधा',
    'allow_location': 'माझे स्थान वापरा',
    'choose_manually': 'स्थान स्वतः निवडा',
    'home_title': 'होम',
    'categories': 'श्रेणी',
    'featured': 'तुमच्या जवळील वैशिष्ट्यपूर्ण पर्याय',
    'offline_data': 'जतन केलेली माहिती दाखवत आहे',
    'explore_title': 'शोधा',
    'activity_title': 'क्रियाकलाप',
    'profile_title': 'प्रोफाइल',
    'secure_checkout': 'सुरक्षित चेकआउट',
    'delivery_address': 'वितरण पत्ता',
    'order_review': 'ऑर्डरचा आढावा',
    'orders': 'ऑर्डर',
    'points': 'पॉइंट्स',
    'order_tracking': 'ऑर्डर ट्रॅकिंग',
    'payment': 'पेमेंट',
    'total': 'एकूण',
    'cash_on_delivery': 'वितरणावेळी रोख',
    'available_points': 'उपलब्ध: {points} पॉइंट्स',
    'search_local': 'स्थानिक उत्पादने आणि सेवा शोधा',
    'all_categories': 'सर्व श्रेणी',
  },
  'bn': {
    'update_required': 'আপডেট প্রয়োজন',
    'update_required_message':
        'নিরাপদে চালিয়ে যেতে Planext4u-এর সর্বশেষ সংস্করণ ইনস্টল করুন।',
    'maintenance_title': 'আমরা শীঘ্রই ফিরে আসব',
    'maintenance_message': 'Planext4u-তে নির্ধারিত রক্ষণাবেক্ষণ চলছে।',
    'retry': 'আবার চেষ্টা করুন',
    'location_title': 'আপনার কাছাকাছি পরিষেবা খুঁজুন',
    'allow_location': 'আমার অবস্থান ব্যবহার করুন',
    'choose_manually': 'নিজে অবস্থান বেছে নিন',
    'home_title': 'হোম',
    'categories': 'বিভাগ',
    'featured': 'আপনার কাছাকাছি নির্বাচিত বিকল্প',
    'offline_data': 'সংরক্ষিত তথ্য দেখানো হচ্ছে',
    'explore_title': 'অন্বেষণ',
    'activity_title': 'কার্যকলাপ',
    'profile_title': 'প্রোফাইল',
    'secure_checkout': 'নিরাপদ চেকআউট',
    'delivery_address': 'ডেলিভারির ঠিকানা',
    'order_review': 'অর্ডার পর্যালোচনা',
    'orders': 'অর্ডার',
    'points': 'পয়েন্ট',
    'order_tracking': 'অর্ডার ট্র্যাকিং',
    'payment': 'পেমেন্ট',
    'total': 'মোট',
    'cash_on_delivery': 'ডেলিভারির সময় নগদ',
    'available_points': 'উপলভ্য: {points} পয়েন্ট',
    'search_local': 'স্থানীয় পণ্য ও পরিষেবা খুঁজুন',
    'all_categories': 'সব বিভাগ',
  },
  'gu': {
    'update_required': 'અપડેટ જરૂરી છે',
    'update_required_message':
        'સુરક્ષિત રીતે ચાલુ રાખવા માટે Planext4u નું નવીનતમ સંસ્કરણ ઇન્સ્ટોલ કરો.',
    'maintenance_title': 'અમે ટૂંક સમયમાં પાછા આવીશું',
    'maintenance_message': 'Planext4u પર નિર્ધારિત જાળવણી ચાલી રહી છે.',
    'retry': 'ફરી પ્રયાસ કરો',
    'location_title': 'તમારી નજીકની સેવાઓ શોધો',
    'allow_location': 'મારા સ્થાનનો ઉપયોગ કરો',
    'choose_manually': 'સ્થાન જાતે પસંદ કરો',
    'home_title': 'હોમ',
    'categories': 'શ્રેણીઓ',
    'featured': 'તમારી નજીકના પસંદગીના વિકલ્પો',
    'offline_data': 'સાચવેલી માહિતી બતાવવામાં આવી રહી છે',
    'explore_title': 'શોધો',
    'activity_title': 'પ્રવૃત્તિ',
    'profile_title': 'પ્રોફાઇલ',
    'secure_checkout': 'સુરક્ષિત ચેકઆઉટ',
    'delivery_address': 'ડિલિવરી સરનામું',
    'order_review': 'ઓર્ડર સમીક્ષા',
    'orders': 'ઓર્ડર',
    'points': 'પોઇન્ટ્સ',
    'order_tracking': 'ઓર્ડર ટ્રેકિંગ',
    'payment': 'ચુકવણી',
    'total': 'કુલ',
    'cash_on_delivery': 'ડિલિવરી સમયે રોકડ',
    'available_points': 'ઉપલબ્ધ: {points} પોઇન્ટ્સ',
    'search_local': 'સ્થાનિક ઉત્પાદનો અને સેવાઓ શોધો',
    'all_categories': 'બધી શ્રેણીઓ',
  },
};

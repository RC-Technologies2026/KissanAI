/// App-wide API base URL — change per environment.
class ApiConstants {
  ApiConstants._();

  // Production backend URL
  static const String baseUrl = 'https://kissanai-pkzn.onrender.com';

  // OpenWeatherMap API
  static const String openWeatherApiKey = '67ba3394df80888194a8f99ac8d56826';
  static const String openWeatherBaseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String openWeatherOneCallUrl = 'https://api.openweathermap.org/data/3.0/onecall';

  // Google Maps API
  static const String googleMapsApiKey = 'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao';

  // Auth
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String profile = '/api/auth/profile';

  // Onboarding
  static const String onboardingSubmit = '/api/onboarding/submit';

  // Images
  static const String imageUpload = '/api/images/upload';

  // Disease
  static const String diseaseDetect = '/api/disease/detect';

  // Pests
  static const String pestDetect = '/api/pests/detect';

  // Pesticides / Insecticides
  static const String pesticidesRecommend = '/api/pesticides/recommend';
  static const String insecticidesRecommend = '/api/insecticides/recommend';

  // Weather
  static const String weatherCurrent = '/api/weather/current';

  // Crop Recommendation (via irrigation module)
  static const String cropRecommendation = '/api/irrigation/recommend';

  // Irrigation
  static const String irrigation = '/api/irrigation/guide';

  // Chat
  static const String chatMessage = '/api/chat';

  // History
  static const String historyList = '/api/history';
}

/// Hive box names.
class HiveBoxes {
  HiveBoxes._();

  static const String authBox = 'auth_box';
  static const String settingsBox = 'settings_box';
  static const String onboardingBox = 'onboarding_box';
}

/// Keys used inside Hive boxes.
class HiveKeys {
  HiveKeys._();

  static const String token = 'jwt_token';
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';
  static const String language = 'language';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String onboardingComplete = 'onboarding_complete';

  // Farm details
  static const String farmName = 'farm_name';
  static const String farmProvince = 'farm_province';
  static const String farmDistrict = 'farm_district';
  static const String farmCity = 'farm_city';
  static const String farmSize = 'farm_size';
  static const String farmSizeUnit = 'farm_size_unit';
  static const String farmLocation = 'farm_location';
  static const String farmerType = 'farmer_type';
  static const String userPhone = 'user_phone';
}

/// Onboarding data options.
class OnboardingData {
  OnboardingData._();

  static const List<String> provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Gilgit-Baltistan',
    'Azad Kashmir',
    'Islamabad',
  ];

  static const List<String> languages = [
    'English',
    'Urdu',
    'Punjabi',
    'Sindhi',
    'Pashto',
    'Balochi',
  ];

  static const List<String> farmerTypes = [
    'New Farmer',
    'Experienced Farmer',
  ];

  static const List<String> crops = [
    'Wheat',
    'Rice',
    'Cotton',
    'Sugarcane',
    'Maize',
    'Potato',
    'Tomato',
    'Onion',
    'Chili',
    'Citrus',
    'Mango',
    'Banana',
  ];

  static const List<String> livestock = [
    'Cattle',
    'Buffalo',
    'Goat',
    'Sheep',
    'Poultry',
    'Camel',
    'Horse',
    'Fish',
  ];

  static const List<String> sizeUnits = ['Acres', 'Kanal', 'Hectares'];

  static const List<String> seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
  static const List<String> soilTypes = [
    'Loamy',
    'Clay',
    'Sandy',
    'Silt',
    'Peaty',
  ];
  static const List<String> waterAvailability = [
    'High',
    'Medium',
    'Low',
  ];
}

/// Global constants (§1, §2, §6.2, §8.1).
abstract final class AppConstants {
  /// Working product name kept in one constant so it can change easily (§1).
  static const String appName = 'LuckyLedger';

  /// Internal synthetic email domain for Phone + PIN auth (§6.2).
  static const String authEmailDomain = 'luckyledger.app';

  /// Maximum tickets allowed in a single stock batch (§6.5, §7.1).
  static const int maxBatchTickets = 5000;

  /// Canonical list of the 14 Kerala districts (§8.1).
  static const List<String> keralaDistrictKeys = <String>[
    'Thiruvananthapuram',
    'Kollam',
    'Pathanamthitta',
    'Alappuzha',
    'Kottayam',
    'Idukki',
    'Ernakulam',
    'Thrissur',
    'Palakkad',
    'Malappuram',
    'Kozhikode',
    'Wayanad',
    'Kannur',
    'Kasaragod',
  ];
}

/// Varlik (asset) yollari tek yerden yonetilir.
/// Yazim hatasi yuzunden calisma aninda cokmeyi onler.
class AppAssets {
  const AppAssets._();

  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _animations = 'assets/animations';

  static const String logo = '$_images/logo.png';
  static const String cardBack = '$_images/card_back.png';
  static const String pitchBackground = '$_images/pitch_bg.png';
  static const String placeholderPlayer = '$_images/player_placeholder.png';

  static const String iconShield = '$_icons/shield.png';
  static const String iconTrophy = '$_icons/trophy.png';

  static const String searchingOpponent = '$_animations/searching.json';
}

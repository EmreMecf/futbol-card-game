import 'package:freezed_annotation/freezed_annotation.dart';

import 'game_rules.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Oyuncu profili.
///
/// Sunucu bu sinifi `toJson()` ile gonderir, uygulama `fromJson()` ile
/// okur. Ayni sinifi kullandiklari icin alan adi uyusmazligi IMKANSIZ.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String username,
    @Default('') String email,
    String? avatarUrl,
    @Default(0) int coins,

    /// Maca girerken korumaya alinabilecek kart sayisi.
    /// Her galibiyette 1 artar (ust sinir [GameRules.maxProtectionSlots]).
    @Default(GameRules.baseProtectionSlots) int protectionSlots,

    @Default(1000) int mmr,
    @Default(0) int wins,
    @Default(0) int losses,
    @Default(0) int draws,
    DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Oynanan toplam mac
  int get totalMatches => wins + losses + draws;

  /// Kazanma yuzdesi (0.0 - 1.0). Hic mac oynanmadiysa 0.
  double get winRate => totalMatches == 0 ? 0 : wins / totalMatches;

  /// Koruma hakki en ust sinira ulasti mi?
  bool get hasMaxProtection => protectionSlots >= GameRules.maxProtectionSlots;
}

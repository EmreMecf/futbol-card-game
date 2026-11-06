import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// BAŞARIMLAR (MD bölüm 4-J) — sadece gerçek veriden, ödülsüz.
///
/// ===================================================================
/// KURAL 1: SADECE SUNUCUDA GERÇEKTEN DURAN SAYILAR
/// ===================================================================
/// Her başarım `users` tablosundaki sayaçlardan (galibiyet, mağlubiyet,
/// beraberlik) ya da sunucunun hesapladığı lig basamağından türetiliyor.
/// İstemci hiçbir şey saymıyor, uydurmuyor.
///
/// BİLEREK EKLENMEYENLER:
///   * "5 galibiyet serisi" — profil son 20 maçı getiriyor. Daha önce
///     yapılmış bir seriyi bilemeyiz; rozet yanlışlıkla "kilitli"
///     görünürdü.
///   * "Rakipten 10 kart kazan" — aynı sebep: toplam sayı sunucuda
///     tutulmuyor, sadece son maçlar var.
/// Bunlar için sunucuya sayaç eklenmesi gerekiyor.
///
/// ===================================================================
/// KURAL 2: ÖDÜL YOK
/// ===================================================================
/// Başarımlar coin ya da kart VERMİYOR. Ödül vermek yeni bir ekonomi
/// mekaniği olurdu ve MD kural 13 bunun için onay istiyor. Şu an
/// sadece oyuncunun ilerlemesini gösteren rozetler.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  /// Şu anki değer ve hedef (ilerleme çubuğu için)
  final int current;
  final int target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.current,
    required this.target,
  });

  bool get isUnlocked => current >= target;

  /// 0.0 - 1.0
  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);

  /// "7 / 10" — açılmışsa hedef gösterilir ("10 / 10")
  String get progressText =>
      '${current > target ? target : current} / $target';

  // ------------------------------------------------------------------
  // HESAPLAMA
  // ------------------------------------------------------------------
  /// Lig kodlarının sırası (sunucudaki `league_tiers` ile aynı)
  static const _ligSirasi = ['amateur', 'usta', 'master', 'master_class'];

  static int _ligSeviyesi(PlayerRank? r) {
    if (r == null) return 0;
    final i = _ligSirasi.indexOf(r.leagueCode);
    return i < 0 ? 0 : i;
  }

  /// Oyuncunun bütün başarımları.
  ///
  /// [rank] null ise (henüz yüklenmedi ya da hata) lig başarımları
  /// "kilitli" görünür; yanlışlıkla "açık" görünmesinden iyidir.
  static List<Achievement> evaluate(UserModel? user, PlayerRank? rank) {
    final g = user?.wins ?? 0;
    final toplam = g + (user?.losses ?? 0) + (user?.draws ?? 0);
    final lig = _ligSeviyesi(rank);

    return [
      Achievement(
        id: 'ilk_mac',
        title: 'İlk Düdük',
        description: 'İlk maçını tamamla',
        icon: Icons.sports_rounded,
        // Kilitli karoların grisinden (0xFF94A3B8) AYRI olmalı; aynı
        // renkte açılmış rozet kilitli sanılıyordu.
        color: const Color(0xFFE2E8F0),
        current: toplam,
        target: 1,
      ),
      Achievement(
        id: 'ilk_galibiyet',
        title: 'İlk Zafer',
        description: 'İlk maçını kazan',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF10B981),
        current: g,
        target: 1,
      ),
      Achievement(
        id: 'on_galibiyet',
        title: 'Seri Galip',
        description: '10 maç kazan',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF59E0B),
        current: g,
        target: 10,
      ),
      Achievement(
        id: 'elli_mac',
        title: 'Arena Emektarı',
        description: '50 maç oyna',
        icon: Icons.stadium_rounded,
        color: const Color(0xFF22D3EE),
        current: toplam,
        target: 50,
      ),
      Achievement(
        id: 'usta_ligi',
        title: 'Usta',
        description: 'Usta ligine yüksel',
        icon: Icons.shield_rounded,
        color: const Color(0xFFD4AF37),
        current: lig >= 1 ? 1 : 0,
        target: 1,
      ),
      Achievement(
        id: 'master_ligi',
        title: 'Master',
        description: 'Master ligine yüksel',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFF8B5CF6),
        current: lig >= 2 ? 1 : 0,
        target: 1,
      ),
    ];
  }
}

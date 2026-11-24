import '../../../core/error/app_exception.dart';

/// Sunucunun sandık hata kodlarını (031/032) Türkçe kullanıcı mesajına
/// çevirir. Sunucu mesajı ASCII; oyuncu düzgün Türkçe görür.
String chestErrorMessage(AppException e) => switch (e.technicalDetail) {
      'chest_not_found' => 'Sandık bulunamadı.',
      'chest_locked' => 'Önce sandığın kilidini aç.',
      'chest_not_ready' => 'Sandık henüz hazır değil.',
      'chest_already_unlocking' => 'Aynı anda yalnız bir sandığın kilidi açılabilir.',
      'chest_not_lockable' => 'Bu sandığın kilidi açılamaz.',
      'chest_in_mailbox' => 'Önce posta kutusundan boş bir yuvaya taşı.',
      'chest_not_in_mailbox' => 'Bu sandık posta kutusunda değil.',
      'chest_compensated' => 'Bu sandık telafi altınına dönüştü.',
      'slots_full' => 'Boş yuva yok. Önce bir sandık aç.',
      'economy_disabled' => 'Sandık sistemi henüz açık değil.',
      'squad_complete' => 'Kadron zaten kurulabiliyor.',
      'emergency_cooldown' => 'Acil kadro 24 saatte bir alınabilir.',
      'not_enough_gems' => 'Yeterli elmas yok.',
      'gem_cost_changed' => 'Elmas bedeli değişti, tekrar dene.',
      'chest_not_gem_openable' => 'Bu sandık elmasla açılamaz.',
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.',
      _ => e.message,
    };

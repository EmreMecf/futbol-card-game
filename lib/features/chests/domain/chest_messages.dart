import '../../../core/error/app_exception.dart';
import '../../../core/l10n/app_language.dart';

/// Sunucunun sandık hata kodlarını (031/032) Türkçe kullanıcı mesajına
/// çevirir. Sunucu mesajı ASCII; oyuncu düzgün Türkçe görür.
String chestErrorMessage(AppException e) => switch (e.technicalDetail) {
      'chest_not_found' => 'Sandık bulunamadı.'.tr,
      'chest_locked' => 'Önce sandığın kilidini aç.'.tr,
      'chest_not_ready' => 'Sandık henüz hazır değil.'.tr,
      'chest_already_unlocking' => 'Aynı anda yalnız bir sandığın kilidi açılabilir.'.tr,
      'chest_not_lockable' => 'Bu sandığın kilidi açılamaz.'.tr,
      'chest_in_mailbox' => 'Önce posta kutusundan boş bir yuvaya taşı.'.tr,
      'chest_not_in_mailbox' => 'Bu sandık posta kutusunda değil.'.tr,
      'chest_compensated' => 'Bu sandık telafi altınına dönüştü.'.tr,
      'slots_full' => 'Boş yuva yok. Önce bir sandık aç.'.tr,
      'economy_disabled' => 'Sandık sistemi henüz açık değil.'.tr,
      'squad_complete' => 'Kadron zaten kurulabiliyor.'.tr,
      'emergency_cooldown' => 'Acil kadro 24 saatte bir alınabilir.'.tr,
      'not_enough_gems' => 'Yeterli elmas yok.'.tr,
      'gem_cost_changed' => 'Elmas bedeli değişti, tekrar dene.'.tr,
      'chest_not_gem_openable' => 'Bu sandık elmasla açılamaz.'.tr,
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.'.tr,
      _ => e.message,
    };

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../features/settings/presentation/viewmodel/settings_view_model.dart';
import '../di/injection.dart';
import '../utils/logger.dart';

/// Müzik döngüleri (`assets/audio/music/`). Liste: docs/SES_LISTESI.md
enum Music {
  menu('muzik_menu'),
  search('muzik_arama'),
  match('muzik_mac'),
  stadium('ambiyans_stadyum');

  const Music(this.file);
  final String file;
}

/// Maç sonu kısa müzikleri (`assets/audio/music/`). Bir kez çalar.
enum Jingle {
  victory('jingle_zafer'),
  defeat('jingle_yenilgi'),
  draw('jingle_beraberlik');

  const Jingle(this.file);
  final String file;
}

/// Ses efektleri (`assets/audio/sfx/`). Numaralar docs/SES_LISTESI.md ile aynı.
enum Sfx {
  // 1. Genel arayüz
  tap('ui_tik'),
  back('ui_geri'),
  tab('ui_sekme'),
  error('ui_hata'),
  popup('ui_pencere'),
  toggle('ui_dugme'),
  notification('ui_bildirim'),
  // 2. Sandık
  chestShake('sandik_sallanma'),
  chestOpen('sandik_acilis'),
  chestReward('sandik_odul'),
  chestRare('sandik_nadir'),
  chestReady('sandik_hazir'),
  chestDaily('sandik_gunluk'),
  // 3. Paket ve mağaza
  packShake('paket_titreme'),
  packBurst('paket_patlama'),
  cardFlip('kart_cevirme'),
  cardFlipGold('kart_cevirme_altin'),
  cardRareGlow('kart_nadir_parilti'),
  packSkip('paket_hizli'),
  packSummary('paket_ozet'),
  purchase('magaza_satin_alma'),
  // 4. Walkout
  walkoutLights('walkout_isiklar'),
  walkoutHit('walkout_vurus'),
  walkoutCard('walkout_kart'),
  walkoutConfetti('walkout_konfeti'),
  // 5. Eşleşme
  searchPing('eslesme_radar'),
  opponentFound('eslesme_bulundu'),
  whistle('mac_duduk'),
  searchCancel('eslesme_iptal'),
  // 6. Maç
  position('mac_mevki'),
  cardSelect('mac_kart_sec'),
  cardPlay('mac_kart_oyna'),
  opponentPicked('mac_rakip_secti'),
  tacticPress('taktik_pres'),
  tacticCounter('taktik_kontra'),
  tacticWall('taktik_duvar'),
  noEnergy('mac_enerji_yok'),
  reveal('mac_acilis'),
  clash('mac_carpisma'),
  roundWin('mac_tur_kazan'),
  roundLose('mac_tur_kaybet'),
  roundDraw('mac_beraberlik'),
  legend('mac_efsane'),
  tick('mac_tiktak'),
  timeUp('mac_sure_doldu'),
  earlyFinish('mac_erken_bitis'),
  // 7. Sonuç ve ödüller
  coins('odul_altin'),
  xp('odul_xp'),
  trophy('odul_kupa'),
  cardsWon('odul_kart_kazan'),
  cardsLost('odul_kart_kaybet'),
  leagueUp('lig_atlama'),
  levelUp('seviye_atlama'),
  seasonClaim('sezon_odul'),
  // 8. Kadro, koleksiyon, takas
  squadLift('kadro_kaldir'),
  squadDrop('kadro_birak'),
  squadInvalid('kadro_gecersiz'),
  chemistry('kadro_kimya'),
  squadSave('kadro_kaydet'),
  exchange('takas_basarili'),
  // 9. Diğer
  tutorialTip('ogretici_ipucu'),
  missionDone('gorev_tamam');

  const Sfx(this.file);
  final String file;
}

/// Oyundaki bütün seslerin TEK kapısı ([GameFeedback]'in ses karşılığı).
///
///   ❌ AudioPlayer().play(...)        // ayarı ve eksik dosyayı bilmez
///   ✅ GameAudio.sfx(Sfx.chestOpen);
///
/// KURALLAR
/// - Ayarlar > "Ses efektleri" kapalıysa efekt ve jingle çalmaz;
///   "Müzik" kapalıysa müzik durur, açılınca kaldığı ekranın müziği başlar.
/// - Dosyası henüz eklenmemiş ses sessizce atlanır (hata yok). Sesler
///   docs/SES_LISTESI.md'deki adlarla klasöre konunca kendiliğinden çalar.
/// - Müzik ekrana göre seçilir ([AudioRouteListener]); ekranlar müzik
///   açıp kapatmaz. Maç sonu jingle'ı müziği durdurur.
/// - Uygulama arka plana geçince müzik duraklar, öne gelince sürer.
/// - Web: tarayıcı, kullanıcı dokunmadan ses çalmaya izin vermez. İlk
///   denemede reddedilen müzik, oyuncunun ilk dokunuşunda yeniden denenir.
/// - Kayıt yoksa (widget testleri) bütün çağrılar hiçbir şey yapmaz.
class GameAudio with WidgetsBindingObserver {
  GameAudio(this._settings);

  final SettingsViewModel _settings;

  /// Kayıtlı örnek; yoksa (testler) null ve çağrılar sessiz geçer.
  static GameAudio? get _i => getIt.isRegistered<GameAudio>() ? getIt<GameAudio>() : null;

  /// Bir ses efekti çalar.
  static void sfx(Sfx s) => _i?._playSfx(s);

  /// Maç sonu jingle'ı: müziği durdurur, bir kez çalar.
  static void jingle(Jingle j) => _i?._playJingle(j);

  /// Çalması gereken müziği belirler (null: sessizlik).
  static void music(Music? m) => _i?._setMusic(m);

  // ------------------------------------------------------------------

  static const _sfxDir = 'audio/sfx';
  static const _musicDir = 'audio/music';

  /// Efektler üst üste binebilsin diye sırayla kullanılan oynatıcılar.
  static const _sfxVoices = 6;
  static const _musicVolume = 0.55;
  static const _sfxVolume = 1.0;

  final Set<String> _available = {};
  final List<AudioPlayer> _voices = [];
  int _nextVoice = 0;
  AudioPlayer? _musicPlayer;
  AudioPlayer? _jinglePlayer;

  Music? _wanted;
  Music? _playing;
  bool _paused = false;
  bool _ready = false;

  /// Klasördeki ses dosyalarını öğrenir, ayarları dinlemeye başlar.
  Future<void> init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _available.addAll(manifest.listAssets().where((a) => a.startsWith('assets/audio/')));
      _musicPlayer = AudioPlayer(playerId: 'muzik');
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      _jinglePlayer = AudioPlayer(playerId: 'jingle');
      await _jinglePlayer!.setReleaseMode(ReleaseMode.stop);
      for (var i = 0; i < _sfxVoices; i++) {
        final v = AudioPlayer(playerId: 'efekt_$i');
        await v.setReleaseMode(ReleaseMode.stop);
        _voices.add(v);
      }
      _settings.addListener(_onSettings);
      WidgetsBinding.instance.addObserver(this);
      _ready = true;
      AppLogger.info('Ses: ${_available.length} dosya bulundu');
    } catch (e) {
      AppLogger.warning('Ses başlatılamadı: $e');
    }
  }

  bool _has(String path) => _available.contains('assets/$path');

  void _playSfx(Sfx s) {
    if (!_ready || !_settings.soundEffects) return;
    _retryMusicIfBlocked();
    final path = '$_sfxDir/${s.file}.mp3';
    if (!_has(path)) return;
    final p = _voices[_nextVoice];
    _nextVoice = (_nextVoice + 1) % _voices.length;
    _safe(() async {
      await p.stop();
      await p.play(AssetSource(path), volume: _sfxVolume, mode: PlayerMode.lowLatency);
    });
  }

  void _playJingle(Jingle j) {
    if (!_ready) return;
    _setMusic(null);
    if (!_settings.soundEffects) return;
    final path = '$_musicDir/${j.file}.mp3';
    if (!_has(path)) return;
    _safe(() => _jinglePlayer!.play(AssetSource(path), volume: 0.9));
  }

  void _setMusic(Music? m) {
    _wanted = m;
    _applyMusic();
  }

  void _applyMusic() {
    if (!_ready) return;
    final target = (_settings.music && !_paused) ? _wanted : null;
    final path = target == null ? null : '$_musicDir/${target.file}.mp3';
    final next = (path != null && _has(path)) ? target : null;
    if (next == _playing) return;
    _playing = next;
    final p = _musicPlayer!;
    _safe(() async {
      await p.stop();
      if (next != null) {
        await p.play(AssetSource('$_musicDir/${next.file}.mp3'), volume: _musicVolume);
      }
    }, onError: () => _playing = null);
  }

  /// Web'de ilk müzik isteği tarayıcı tarafından reddedilmiş olabilir.
  void _retryMusicIfBlocked() {
    if (_playing == null && _wanted != null) _applyMusic();
  }

  void _onSettings() {
    _applyMusic();
    if (!_settings.soundEffects) {
      for (final v in _voices) {
        _safe(v.stop);
      }
      _safe(_jinglePlayer!.stop);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (state == AppLifecycleState.resumed || background) {
      _paused = background;
      _applyMusic();
    }
  }

  /// Ses hiçbir zaman oyunu durdurmamalı: eklenti hataları yutulur.
  void _safe(Future<void> Function() f, {VoidCallback? onError}) {
    unawaited(
      Future.sync(f).catchError((Object e) {
        onError?.call();
        AppLogger.info('Ses çalınamadı: $e', tag: 'SES');
      }),
    );
  }
}

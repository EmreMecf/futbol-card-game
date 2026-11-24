import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/audio/audio_route_listener.dart';
import 'package:futbol_card/core/audio/game_audio.dart';
import 'package:futbol_card/core/audio/sound_cues.dart';

void main() {
  group('Ekrana göre müzik', () {
    test('maç adresi maç müziği', () {
      expect(musicForPath('/mac/abc-123'), Music.match);
    });

    test('eşleşme ekranı arama müziği', () {
      expect(musicForPath('/eslesme'), Music.search);
    });

    test('diğer ekranlar menü müziği', () {
      for (final p in ['/', '/giris', '/ana-sayfa', '/koleksiyon', '/magaza', '/sezon', '/arkadaslar']) {
        expect(musicForPath(p), Music.menu, reason: p);
      }
    });

    test('"/mac" kökü maç sayılmaz (id yok)', () {
      expect(musicForPath('/mac'), Music.menu);
    });
  });

  group('Ses listesi', () {
    test('dosya adları benzersiz ve listede yazılı', () {
      final names = [
        ...Music.values.map((m) => m.file),
        ...Jingle.values.map((j) => j.file),
        ...Sfx.values.map((s) => s.file),
      ];
      expect(names.toSet().length, names.length);

      // docs/SES_LISTESI.md ile kod aynı adları kullanmalı
      final doc = File('docs/SES_LISTESI.md').readAsStringSync();
      for (final n in names) {
        expect(doc.contains('`$n.mp3`'), isTrue, reason: '$n listede yok');
      }
      expect(Sfx.values.length, 62);
    });
  });

  group('Kayıt yokken (widget testleri)', () {
    test('çağrılar hata vermeden hiçbir şey yapmaz', () {
      GameAudio.sfx(Sfx.chestOpen);
      GameAudio.jingle(Jingle.victory);
      GameAudio.music(Music.menu);
      GameAudio.music(null);
    });
  });

  group('SoundCues', () {
    test('işaret geçilince bir kez çalar, atlamada sessiz geçer', () {
      final anim = _FakeAnimation();
      final played = <Sfx>[];
      final cues = SoundCues(anim, const [(0.3, Sfx.chestOpen), (0.1, Sfx.chestShake), (0.9, Sfx.coins)], play: played.add);

      anim.set(0.05);
      expect(played, isEmpty);
      anim.set(0.12);
      expect(played, [Sfx.chestShake], reason: 'işaretler sıraya dizilir');
      anim.set(0.15);
      expect(played, [Sfx.chestShake], reason: 'aynı işaret ikinci kez çalmaz');
      anim.set(0.31);
      expect(played, [Sfx.chestShake, Sfx.chestOpen]);

      // Oyuncu dokundu: 0.31 → 1.0 tek karede (atlama)
      anim.set(1.0);
      expect(played, [Sfx.chestShake, Sfx.chestOpen], reason: 'atlanan işaret patlamaz');

      cues.dispose();
      anim.set(0.0);
      expect(played.length, 2, reason: 'dispose sonrası dinlemez');
    });
  });
}

class _FakeAnimation extends Animation<double> with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  double _v = 0;

  void set(double v) {
    _v = v;
    notifyListeners();
  }

  @override
  double get value => _v;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}
}


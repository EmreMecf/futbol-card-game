import 'package:flutter/widgets.dart';

import 'game_audio.dart';

/// Bir animasyonun zaman çizelgesine ses bağlar.
///
///   SoundCues(_a, [
///     (0.00, Sfx.chestShake),
///     (0.22, Sfx.chestOpen),
///   ]);
///
/// Her işaret, animasyon o noktayı (0–1) GEÇTİĞİNDE bir kez çalar.
/// Oyuncu dokunup sahneyi atlarsa (değer bir karede büyük sıçrar)
/// aradaki sesler art arda patlamasın diye çalınmadan geçilir.
class SoundCues {
  SoundCues(this._anim, List<(double, Sfx)> cues, {void Function(Sfx)? play})
      : _cues = [...cues]..sort((a, b) => a.$1.compareTo(b.$1)),
        _play = play ?? GameAudio.sfx {
    _anim.addListener(_tick);
  }

  final Animation<double> _anim;
  final void Function(Sfx) _play;
  final List<(double, Sfx)> _cues;
  int _next = 0;
  double _last = 0;

  /// Tek karede bundan büyük ilerleme "atlama" sayılır.
  static const _skipJump = 0.2;

  void _tick() {
    final v = _anim.value;
    final skipped = v - _last > _skipJump;
    _last = v;
    while (_next < _cues.length && v >= _cues[_next].$1) {
      if (!skipped) _play(_cues[_next].$2);
      _next++;
    }
  }

  void dispose() => _anim.removeListener(_tick);
}

/// Ekran / panel ilk göründüğünde bir kez ses çalar.
///
/// `build` birden çok kez çalışabildiği için sesi orada çalmak yerine
/// bu sarmalayıcı kullanılır.
class SfxOnMount extends StatefulWidget {
  const SfxOnMount({super.key, required this.sfx, required this.child});

  final Sfx sfx;
  final Widget child;

  @override
  State<SfxOnMount> createState() => _SfxOnMountState();
}

class _SfxOnMountState extends State<SfxOnMount> {
  @override
  void initState() {
    super.initState();
    GameAudio.sfx(widget.sfx);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

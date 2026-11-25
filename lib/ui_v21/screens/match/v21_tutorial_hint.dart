import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/sound_cues.dart';
import '../../ui_v21.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 ÖĞRETİCİ İPUCU (referans hf12–hf14).
///
///        ÖĞRETİCİ · 1/3                [ÖDÜLSÜZ]
///     (✓)────(2)────(3)
///     MEVKİ   KART   TAKTİK
///   (koç) ╭ MEVKİ SEÇ ─────────────────────╮
///         │ Bu turun mevkisini sen …        │
///         ╰─────────────────────────────────╯
///
/// Metinler sunucu kural sayılarıyla uyumludur. Öğretici maçları ödülsüz ve puansızdır (042);
/// ödül yalnız 3. adım bitince verilen Gümüş sandık.
class V21TutorialHint extends StatelessWidget {
  final MatchState state;

  final double scale;

  const V21TutorialHint({super.key, required this.state, this.scale = 1});

  static List<String> get _steps => ['MEVKİ'.tr, 'KART'.tr, 'TAKTİK'.tr];

  /// (başlık, açıklama) — test edilebilsin diye ayrı
  static (String, String) textFor(MatchState s) {
    final adim = s.tutorialStep ?? 1;
    final mevki = s.phase == 'position';
    if (mevki) {
      if (s.amILead) {
        return adim == 1
            ? ('MEVKİ SEÇ'.tr, 'Bu turun mevkisini sen belirliyorsun. En güçlü kartının olduğu mevkiyi seç: iki oyuncu da o mevkiden kart oynayacak.'.tr)
            : ('MEVKİ SEÇ'.tr, 'Turu kazanan bir sonraki turun mevkisini seçer. Rakibinin zayıf olduğu yeri düşün.'.tr);
      }
      return ('RAKİP SEÇİYOR'.tr, 'Bu turun mevkisini rakip seçiyor. Turu kazanırsan mevkiyi sen seçersin.'.tr);
    }
    if (s.iHavePlayed) {
      return ('KARTIN GİZLİ'.tr, 'Rakip seçince iki kart birlikte açılır. Güçlü kart turu kazanır; beraberlikte kartlar ortada kalır, sonraki turu kazanan hepsini alır.'.tr);
    }
    return switch (adim) {
      1 => ('KART SEÇ'.tr, 'O mevkiden bir kart seç ve oyna. Kısa maç: 6 kart toplayan kazanır.'.tr),
      2 => ('GİZLİ SEÇİM'.tr, 'Rakip de şu an kartını seçiyor ama birbirinizinkini göremiyorsunuz. En güçlü kartını her tur harcama: bazen zayıf kartla turu bırakmak iyidir.'.tr),
      _ => ('TAKTİK'.tr, 'Kartla birlikte taktik seçebilirsin. Pres +9 (3 enerji) ama kontraya yenilir. Kontra presi yakalarsa +13 (2 enerji). Duvar savunurken +6 (2 enerji), prese kırılır. Enerji her tur +1 artar.'.tr),
    };
  }

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final step = (state.tutorialStep ?? 1).clamp(1, 3);
    final (title, text) = textFor(state);
    // Her yeni ipucu (başlık değişince) kısa bir "pop" sesiyle gelir
    return SfxOnMount(
      key: ValueKey(title),
      sfx: Sfx.tutorialTip,
      child: Semantics(
      container: true,
      liveRegion: true,
      label: 'Öğretici, adım {step} / 3, {p}. {title}. {text}'.trArgs({'step': step, 'p': _steps[step - 1].toLowerCase(), 'title': title, 'text': text}),
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 16,
        padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: 76 * k),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ÖĞRETİCİ · {step}/3'.trArgs({'step': step}),
                        style: V21Type.title(24 * k, color: V21Colors.goldTop, shadows: V21Type.inkShadow(k)),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 76 * k,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: V21Tag(
                        text: 'ÖDÜLSÜZ'.tr,
                        background: const Color(0xFF3B2F66),
                        foreground: V21Colors.textMuted,
                        scale: k,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * k),
            V21StepTracker(labels: _steps, current: step, scale: k),
            SizedBox(height: 10 * k),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Coach(size: 52 * k),
                SizedBox(width: 8 * k),
                Expanded(
                  child: _Bubble(title: title, text: text, scale: k),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _Coach extends StatelessWidget {
  final double size;
  const _Coach({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: V21Colors.goldTop, width: size * 0.05),
      color: const Color(0xFF4B23A8),
    ),
    clipBehavior: Clip.antiAlias,
    child: V21MascotHead(size: size),
  );
}

class _Bubble extends StatelessWidget {
  final String title;
  final String text;
  final double scale;
  const _Bubble({required this.title, required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      padding: EdgeInsets.fromLTRB(10 * k, 8 * k, 10 * k, 10 * k),
      decoration: BoxDecoration(
        color: const Color(0xFF241552),
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: V21Colors.goldTop, width: 2 * k),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: V21Type.title(18 * k, shadows: V21Type.inkShadow(k * 0.8))),
          SizedBox(height: 2 * k),
          Text(
            text,
            style: V21Type.label(12.5 * k, weight: FontWeight.w700, color: const Color(0xFFE6DBFF), height: 1.35),
          ),
        ],
      ),
    );
  }
}

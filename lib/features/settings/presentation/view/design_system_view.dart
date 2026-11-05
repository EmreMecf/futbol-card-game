import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/screen_header.dart';

/// TASARIM SİSTEMİ VİTRİNİ — renkler, yazı, butonlar, rozetler.
///
/// HTML prototipindeki "Tasarım Sistemi" sayfasının karşılığı. Amacı
/// bileşenleri GERÇEK uygulamada, gerçek yazı tipleriyle görmek ve
/// birbirleriyle yan yana tutarlı mı diye kontrol etmek.
///
/// SADECE GELİŞTİRME SÜRÜMÜNDE: Ayarlar ekranındaki bağlantı
/// `kDebugMode` ile korunuyor. Yayın sürümünde oyuncu bu ekranı görmez.
///
/// Buradaki sayılar (2/3 görev, %60 sezon) ÖRNEK veridir; hiçbir
/// sunucu verisine bağlı değildir.
class DesignSystemView extends StatefulWidget {
  const DesignSystemView({super.key});

  @override
  State<DesignSystemView> createState() => _DesignSystemViewState();
}

class _DesignSystemViewState extends State<DesignSystemView> {
  double _ilerleme = 0.66;
  bool _yukleniyor = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenEdge),
          children: [
            const ScreenHeader(
              title: 'Tasarım sistemi',
              showBack: true,
              breadcrumb: 'Ayarlar',
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ---- RENKLER ----
            _baslik('Renk paleti (MD bölüm 3)'),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Renk('Obsidian', AppColors.obsidian),
                _Renk('Deep Navy', AppColors.deepNavy),
                _Renk('Midnight', AppColors.midnightBlue),
                _Renk('Emerald', AppColors.emerald),
                _Renk('Cyan', AppColors.cyan),
                _Renk('Champagne', AppColors.championGold),
                _Renk('Victory', AppColors.victoryGold),
                _Renk('Danger', AppColors.dangerRed),
                _Renk('Purple', AppColors.epicPurple),
              ],
            ),

            // ---- YAZI ----
            _baslik('Tipografi'),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAÇA BAŞLA', style: AppTypography.h1),
                  Text('Bölüm başlığı', style: AppTypography.h2),
                  Text('KARO BAŞLIĞI', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Nunito · Açıklama metinleri uzun okumada yormaz. '
                    'Türkçe karakterler: ğüşıöç ĞÜŞİÖÇ',
                    style: AppTypography.bodyM,
                  ),
                  Text('İkincil metin', style: AppTypography.bodyS),
                  const SizedBox(height: AppSpacing.sm),
                  Text('97', style: AppTypography.cardPower),
                ],
              ),
            ),

            // ---- BUTONLAR ----
            _baslik('Butonlar (basılı tutup bırak)'),
            GameButton(
              label: 'Maça başla',
              icon: Icons.sports_soccer_rounded,
              trailingIcon: Icons.play_arrow_rounded,
              isLoading: _yukleniyor,
              onPressed: () async {
                setState(() => _yukleniyor = true);
                await Future<void>.delayed(const Duration(seconds: 1));
                if (mounted) setState(() => _yukleniyor = false);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: GameButton.neutral(label: 'İptal', onPressed: () {}),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GameButton.secondary(
                    label: 'Kartı oyna',
                    icon: Icons.bolt_rounded,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const GameButton(
              label: 'Paket al',
              onPressed: null,
              disabledReason: 'Yeterli coin yok',
            ),

            // ---- ROZETLER ----
            _baslik('Nadirlik rozetleri'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final t in CardTier.values) TierBadge(t)],
            ),

            // ---- İLERLEME ----
            _baslik('İlerleme çubukları (örnek veri)'),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cubuk('Görev', ProgressKind.task),
                  _cubuk('Sezon', ProgressKind.season),
                  _cubuk('Ödül', ProgressKind.reward),
                  _cubuk('Enerji', ProgressKind.energy),
                  Slider(
                    value: _ilerleme,
                    onChanged: (v) => setState(() => _ilerleme = v),
                  ),
                ],
              ),
            ),

            // ---- PANELLER ----
            _baslik('Cam paneller'),
            const GlassPanel(child: Text('Normal panel (blur yok — ucuz)')),
            const SizedBox(height: AppSpacing.sm),
            const GlassPanel(
              accentColor: AppColors.victoryGold,
              glow: true,
              child: Text('Vurgulu panel: ödül / seçili görev'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _baslik(String metin) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
    child: Text(metin.toUpperCase(), style: AppTypography.label),
  );

  Widget _cubuk(String ad, ProgressKind tur) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ad, style: AppTypography.bodyS),
        const SizedBox(height: AppSpacing.xs),
        GameProgressBar(value: _ilerleme, kind: tur),
      ],
    ),
  );
}

class _Renk extends StatelessWidget {
  final String ad;
  final Color renk;

  const _Renk(this.ad, this.renk);

  @override
  Widget build(BuildContext context) {
    // ARGB -> "#RRGGBB"
    final hex =
        '#${(renk.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: renk,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.surfaceLight),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ad,
            style: AppTypography.body(size: 11, weight: FontWeight.w800),
          ),
          Text(hex, style: AppTypography.bodyXS),
        ],
      ),
    );
  }
}

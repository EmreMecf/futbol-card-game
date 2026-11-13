import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../viewmodel/store_view_model.dart';
import '../widgets/pack_reveal_view.dart';

/// MAĞAZA — referans `shop()` ekranı.
///
///   .sectionhead  h2 "MAĞAZA" + altın bakiyesi
///   .tabstrip     PAKETLER · TEKLİFLER · KOZMETİK (son ikisi oyunda yok)
///   .shop-feature seçili / öne çıkan paket: ad, açıklama, kutu, oranlar, CTA
///   .shopgrid     paket karoları (dokun → seç; satın alma CTA'dan)
///   karşılaştırma bütün paketlerin kart sayısı, fiyatı ve nadirlik oranları
///   .card-panel   görev ödülleri
///   .note         çekiliş sunucuda
///
/// FİYAT VE ORANLAR SUNUCUDAN (pack_types). Paketin içeriği sunucuda
/// belirlenir; uygulama sonuca karışmaz.
///
/// ESKİ HATA (düzeltildi): masaüstü ızgarasında her paket sabit 420 px
/// yükseklikteki kutuya sığdırılıyordu; açıklaması ve oranı uzun paket
/// alttan 60-85 px taşıyordu ("BOTTOM OVERFLOWED"). Yeni yerleşimde
/// hiçbir pakete sabit yükseklik verilmez.
class StoreView extends StatelessWidget {
  const StoreView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoreViewModel>(
      create: (_) => getIt<StoreViewModel>()..load(),
      child: const _Govde(),
    );
  }
}

class _Govde extends StatefulWidget {
  const _Govde();

  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  String? _seciliSlug;

  PackType? _secili(StoreViewModel vm) {
    final slug = _seciliSlug ?? vm.featuredSlug;
    for (final p in vm.packs) {
      if (p.slug == slug) return p;
    }
    return vm.packs.where((p) => p.isPurchasable).firstOrNull ?? vm.packs.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StoreViewModel>();
    // Altın bakiyesi başlıkta anlık görünsün
    try {
      context.watch<SessionManager>();
    } on ProviderNotFoundException {
      // test
    }

    final acilis = vm.lastOpening;
    if (acilis != null) {
      final tur = vm.packs.where((p) => p.slug == acilis.packSlug);
      return PackRevealView(
        result: acilis,
        onClose: vm.clearOpening,
        packTier: tur.isEmpty ? CardTier.gold : tur.first.signatureTier,
      );
    }

    return AppShell(
      currentRoute: AppRoutes.store,
      child: LayoutBuilder(
        builder: (context, k) {
          final genis = k.maxWidth >= 900;
          return RefreshIndicator(
            color: Ref.accent,
            backgroundColor: Ref.panel,
            onRefresh: vm.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Ref.pagePadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: genis ? 1100 : 620),
                    child: RefPageEnter(child: _icerik(context, vm, genis)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _icerik(BuildContext context, StoreViewModel vm, bool genis) {
    final ust = [
      RefSectionHead(
        'MAĞAZA',
        size: 27,
        trailing: RefPill('${trThousands(vm.coins)} ALTIN', leading: const CoinGlyph(size: 11)),
      ),
      const SizedBox(height: Ref.pageGap),
      const _Sekmeler(),
      const SizedBox(height: Ref.pageGap),
    ];

    if (vm.isLoading && vm.packs.isEmpty) {
      return Column(
        children: [
          ...ust,
          const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Ref.accent),
          ),
        ],
      );
    }
    if (vm.packs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...ust,
          RefCardPanel(
            children: [
              Text(vm.errorMessage ?? 'Şu an satışta paket yok.', style: Ref.bodyText(13)),
              RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
            ],
          ),
        ],
      );
    }

    final secili = _secili(vm)!;
    final vitrin = _Vitrin(
      pack: secili,
      oneCikan: secili.slug == vm.featuredSlug,
      aciliyor: vm.openingPackSlug == secili.slug,
      parasiYeter: vm.canAfford(secili),
      onBuy: () => _satinAl(context, vm, secili),
    );
    final paketler = [
      RefSectionHead('KART PAKETLERİ', trailing: Text('FİYATLAR SUNUCUDAN', style: Ref.tiny(Ref.muted))),
      const SizedBox(height: Ref.pageGap),
      _PaketIzgarasi(packs: vm.packs, seciliSlug: secili.slug, onSelect: (p) => setState(() => _seciliSlug = p.slug)),
    ];
    final alt = [
      RefSectionHead('PAKET KARŞILAŞTIRMA', trailing: Text('ÇIKMA İHTİMALİ', style: Ref.tiny(Ref.muted))),
      const SizedBox(height: Ref.pageGap),
      _Karsilastirma(packs: vm.packs.where((p) => p.isPurchasable).toList()),
      const SizedBox(height: Ref.pageGap),
      RefCardPanel(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Em('🎁', size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('KART TAKASI ÖDÜLLERİ', style: Ref.bodyText(14, weight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    Text('Kartlarını takas et, ödül paketi kazan.', style: Ref.bodyText(10, color: Ref.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RefSecondaryButton('KART TAKASI', expand: false, onTap: () => context.go(AppRoutes.sbc)),
            ],
          ),
        ],
      ),
      const SizedBox(height: Ref.pageGap),
      const RefNote(
        'Paketten çıkan kartları sunucu belirler: rastgeleliği veritabanı üretir, uygulama sonuca karışamaz. '
        'Yukarıdaki oranlar gösterim değil, gerçekten uygulanan değerlerdir.',
        title: 'Çekiliş nasıl yapılıyor?',
      ),
    ];

    if (!genis) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...ust,
          _GununTeklifi(viewModel: vm),
          vitrin,
          const SizedBox(height: Ref.pageGap),
          ...paketler,
          const SizedBox(height: Ref.pageGap),
          ...alt,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...ust,
        _GununTeklifi(viewModel: vm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: vitrin),
            const SizedBox(width: 20),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...paketler,
                  const SizedBox(height: Ref.pageGap),
                  ...alt,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Hata olursa oyuncuya söyler (altın gitti mi gitmedi mi belli olsun)
  Future<void> _satinAl(BuildContext context, StoreViewModel vm, PackType p) async {
    final ok = await vm.openPack(p);
    if (ok || !context.mounted) return;
    final mesaj = vm.errorMessage;
    if (mesaj != null) {
      AppSnackBar.showError(context, mesaj);
      vm.clearError();
    }
  }
}

/// Paket simgesi (referans: 📦 Altın, 💠 Elmas, 🎴 Efsane paketi)
String packEmoji(PackType p) {
  if (p.slug.startsWith('test')) return '🧪';
  return switch (p.slug) {
    'standard' => '📦',
    'premium' => '💠',
    'squad' => '🎴',
    _ => '🎁',
  };
}

// ====================================================================
// .tabstrip
// ====================================================================
class _Sekmeler extends StatelessWidget {
  const _Sekmeler();

  @override
  Widget build(BuildContext context) {
    void yakinda(String ad) => ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text('$ad yakında. Şimdilik kart paketleri satışta.')));
    return Row(
      children: [
        const Expanded(child: _Sekme('PAKETLER', secili: true)),
        const SizedBox(width: 5),
        Expanded(child: _Sekme('TEKLİFLER', onTap: () => yakinda('Teklifler'))),
        const SizedBox(width: 5),
        Expanded(child: _Sekme('KOZMETİK', onTap: () => yakinda('Kozmetikler'))),
      ],
    );
  }
}

/// .tabstrip button { border:1px solid #334962; border-radius:8px; background:#101c2c;
///   color:#b8c6d9; font-size:10px; font-weight:900; padding:8px 4px }
/// .selected { background:#12563f; border-color:#19d999; color:#baffdf }
class _Sekme extends StatelessWidget {
  final String ad;
  final bool secili;
  final VoidCallback? onTap;
  const _Sekme(this.ad, {this.secili = false, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: secili ? ad : '$ad, yakında',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili ? Ref.tabSelectedBg : Ref.tabBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: secili ? Ref.tabSelectedBorder : Ref.tabBorder),
        ),
        child: Text(
          ad,
          style: Ref.bodyText(10, color: secili ? Ref.tabSelectedText : Ref.tabText, weight: FontWeight.w900),
        ),
      ),
    ),
  );
}

// ====================================================================
// .shop-feature
// ====================================================================
/// .shop-feature { background:radial-gradient(ellipse at center,#865f2c99,transparent 63%),
///   linear-gradient(#1b2532,#08111e); border:1px solid #b99454; border-radius:16px;
///   padding:20px; gap:7px; text-align:center }
/// .pack-art { font-size:94px; filter:drop-shadow(0 0 20px #efc66688) }
class _Vitrin extends StatelessWidget {
  final PackType pack;
  final bool oneCikan;
  final bool aciliyor;
  final bool parasiYeter;
  final VoidCallback onBuy;

  const _Vitrin({
    required this.pack,
    required this.oneCikan,
    required this.aciliyor,
    required this.parasiYeter,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final etkin = pack.isPurchasable && parasiYeter && !aciliyor;
    final String cta;
    if (aciliyor) {
      cta = 'AÇILIYOR...';
    } else if (!pack.isPurchasable) {
      cta = 'SATIŞTA DEĞİL';
    } else if (!parasiYeter) {
      cta = 'YETERSİZ ALTIN';
    } else if (pack.isFree) {
      cta = 'ÜCRETSİZ · PAKET AÇ';
    } else {
      cta = '${trThousands(pack.priceCoins)} · PAKET AL';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB99454)),
      ),
      child: CustomPaint(
        painter: const _VitrinZemini(),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(oneCikan ? 'ÖNE ÇIKAN PAKET' : 'SEÇİLİ PAKET', maxLines: 1, style: Ref.caps(Ref.gold)),
                ),
                const SizedBox(width: 5),
                const RefGlyphIcon(RefGlyph.sparkle, size: 9, color: Ref.gold),
              ],
            ),
            const SizedBox(height: 7),
            Text(pack.name.toUpperTr(), textAlign: TextAlign.center, style: Ref.h2()),
            const SizedBox(height: 7),
            if (pack.description != null && pack.description!.isNotEmpty)
              Text(pack.description!, textAlign: TextAlign.center, style: Ref.tiny(Ref.muted)),
            const SizedBox(height: 7),
            RefDropShadow(
              color: const Color(0x88EFC666),
              offset: Offset.zero,
              blur: 20,
              child: Em(packEmoji(pack), size: 94, height: 1.2),
            ),
            const SizedBox(height: 7),
            Text(
              pack.hasGuaranteedFormation
                  ? '${pack.cardCount} kart · tam kadro (1-4-4-2) garantili'
                  : '${pack.cardCount} kart',
              textAlign: TextAlign.center,
              style: Ref.bodyText(11, weight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            _OranCipleri(pack: pack),
            const SizedBox(height: 14),
            RefCta(
              cta,
              fontSize: 21,
              leadingWidget: etkin && !pack.isFree ? const CoinGlyph(size: 18) : null,
              onTap: etkin ? onBuy : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _VitrinZemini extends CustomPainter {
  const _VitrinZemini();

  @override
  void paint(Canvas c, Size s) {
    // Kenar boşluğunu da kaplasın (padding 20)
    final r = Rect.fromLTRB(-20, -20, s.width + 20, s.height + 20);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(15)));
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2532), Color(0xFF08111E)],
        ).createShader(r),
    );
    // radial-gradient(ellipse at center, #865f2c99, transparent 63%)
    c.translate(r.center.dx, r.center.dy);
    c.scale(r.width / r.height, 1);
    final yr = r.height / 2 * 1.41 * 0.63;
    c.drawCircle(
      Offset.zero,
      yr,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x99865F2C), Color(0x00865F2C)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: yr)),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_VitrinZemini old) => false;
}

/// Gerçek nadirlik oranları (ağırlığı 0 olanlar gösterilmez)
class _OranCipleri extends StatelessWidget {
  final PackType pack;
  const _OranCipleri({required this.pack});

  @override
  Widget build(BuildContext context) {
    // Nadirlik sırasıyla (Bronz → Efsane); ağırlığı 0 olanlar gösterilmez
    final oranlar = pack.odds.where((o) => o.weight > 0).toList()..sort((a, b) => a.tier.rank.compareTo(b.tier.rank));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in oranlar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1424),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: RefRarity.of(o.tier).color.withValues(alpha: 0.6)),
            ),
            child: Text(
              '${RefRarity.of(o.tier).name} %${_yuzde(o.percent)}',
              style: Ref.bodyText(10, color: RefRarity.of(o.tier).color, weight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

/// %55 / %1,9 / %0,1 (Türkçe ondalık virgül)
String _yuzde(double y) {
  if (y >= 10 || y == y.roundToDouble()) return y.round().toString();
  return y.toStringAsFixed(1).replaceAll('.', ',');
}

// ====================================================================
// .shopgrid { grid-template-columns:repeat(3,1fr); gap:8px }
// ====================================================================
class _PaketIzgarasi extends StatelessWidget {
  final List<PackType> packs;
  final String seciliSlug;
  final ValueChanged<PackType> onSelect;

  const _PaketIzgarasi({required this.packs, required this.seciliSlug, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final satirlar = <List<PackType>>[];
    for (var i = 0; i < packs.length; i += 3) {
      satirlar.add(packs.sublist(i, i + 3 > packs.length ? packs.length : i + 3));
    }
    return Column(
      children: [
        for (var r = 0; r < satirlar.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          // Sabit yükseklik YOK: satır en uzun karo kadar
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < satirlar[r].length
                        ? _PaketKarosu(
                            pack: satirlar[r][i],
                            secili: satirlar[r][i].slug == seciliSlug,
                            onTap: () => onSelect(satirlar[r][i]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// .shop-pack { background:#1b2439; border:1px solid #586076; border-radius:11px;
///   padding:12px 4px; gap:6px } span 36px · b 10px · small #63ecc5 800
class _PaketKarosu extends StatelessWidget {
  final PackType pack;
  final bool secili;
  final VoidCallback onTap;
  const _PaketKarosu({required this.pack, required this.secili, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: secili,
    label: '${pack.name}, ${pack.isFree ? 'ücretsiz' : '${pack.priceCoins} altın'}',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Ref.cardHover,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2439),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: secili ? Ref.accent : const Color(0xFF586076), width: secili ? 1.5 : 1),
          boxShadow: secili ? const [BoxShadow(color: Color(0x5521DFAA), blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Em(packEmoji(pack), size: 36),
            const SizedBox(height: 6),
            Text(
              pack.name.toUpperTr(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Ref.bodyText(10, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!pack.isFree) ...[const CoinGlyph(size: 10), const SizedBox(width: 3)],
                Text(
                  pack.isFree ? 'ÜCRETSİZ' : trThousands(pack.priceCoins),
                  style: Ref.bodyText(10, color: const Color(0xFF63ECC5), weight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ====================================================================
// PAKET KARŞILAŞTIRMA (referansta yok; kullanıcı istedi)
// ====================================================================
class _Karsilastirma extends StatelessWidget {
  final List<PackType> packs;
  const _Karsilastirma({required this.packs});

  @override
  Widget build(BuildContext context) {
    const seviyeler = CardTier.values;
    Widget hucre(String t, {Color? c, bool kalin = false, int flex = 2, TextAlign hiza = TextAlign.center}) => Expanded(
      flex: flex,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: hiza == TextAlign.left ? Alignment.centerLeft : Alignment.center,
        child: Text(
          t,
          maxLines: 1,
          style: Ref.bodyText(10, color: c ?? Ref.text, weight: kalin ? FontWeight.w900 : FontWeight.w700),
        ),
      ),
    );

    return RefCardPanel(
      gap: 8,
      children: [
        Row(
          children: [
            hucre('PAKET', c: Ref.muted, kalin: true, flex: 5, hiza: TextAlign.left),
            hucre('KART', c: Ref.muted, kalin: true),
            hucre('FİYAT', c: Ref.muted, kalin: true, flex: 3),
            for (final t in seviyeler)
              hucre(RefRarity.of(t).name.substring(0, 2).toUpperTr(), c: RefRarity.of(t).color, kalin: true),
          ],
        ),
        Container(height: 1, color: Ref.cardPanelBorder),
        for (final p in packs)
          Row(
            children: [
              hucre(p.name, kalin: true, flex: 5, hiza: TextAlign.left),
              hucre('${p.cardCount}'),
              hucre(p.isFree ? '0' : trThousands(p.priceCoins), c: const Color(0xFF63ECC5), flex: 3),
              for (final t in seviyeler)
                hucre(() {
                  final o = p.odds.where((x) => x.tier == t).firstOrNull;
                  return o == null || o.weight == 0 ? '—' : '%${_yuzde(o.percent)}';
                }(), c: RefRarity.of(t).color),
            ],
          ),
        Text('Br Bronz · Gü Gümüş · Al Altın · El Elmas · Ef Efsane', style: Ref.tiny(Ref.muted)),
      ],
    );
  }
}

// ====================================================================
// GÜNÜN TEKLİFİ (044)
// ====================================================================
class _GununTeklifi extends StatelessWidget {
  final StoreViewModel viewModel;
  const _GununTeklifi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final t = viewModel.dailyOffer;
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Ref.pageGap),
      child: RefCardPanel(children: [
        Row(children: [
          const Em('🏷️', size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('GÜNÜN TEKLİFİ · %${t.discountPct} İNDİRİM', style: Ref.caps(Ref.gold))),
        ]),
        Text('${t.name} (${t.cardCount} kart)', style: Ref.bodyText(13, weight: FontWeight.w800)),
        Text(
          t.boughtToday
              ? 'Bugünkü teklifi aldın. Yeni teklif gece yarısı (Türkiye saati).'
              : '${t.price} yerine ${t.discountedPrice} altın. Günde 1 kez.',
          style: Ref.bodyText(11, color: Ref.muted, height: 1.4),
        ),
        if (!t.boughtToday)
          RefSecondaryButton(
            // Premium paketteki gibi: altın yetmiyorsa nedeni yazılır
            viewModel.coins < t.discountedPrice ? 'YETERSİZ ALTIN' : 'AL · ${t.discountedPrice} ALTIN',
            onTap: viewModel.canBuyDailyOffer ? viewModel.buyDailyOffer : null,
          ),
      ]),
    );
  }
}

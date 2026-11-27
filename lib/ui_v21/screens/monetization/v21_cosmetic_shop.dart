import 'package:material_ui/material_ui.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/l10n/app_language.dart';
import '../../../features/monetization/cosmetics/cosmetic_shop.dart';
import '../../components/v21_cosmetics.dart';
import '../../ui_v21.dart';

/// 062 — KOZMETİK MAĞAZA bölümü (mağazanın KOZMETİK sekmesi).
///
/// Her teklif sabit içerik ve sabit elmas fiyatı; dokununca ÖNİZLEME
/// açılır (çerçeve oyuncunun kendi avatarında, zafer animasyonu döngüde).
/// Satın almadan önce açık onay; önce ücretsiz elmas harcanır.
/// Kozmetikler yalnız görseldir, maç gücü vermez.
class V21CosmeticShopSection extends StatelessWidget {
  final CosmeticShopController controller;
  final double scale;
  const V21CosmeticShopSection({super.key, required this.controller, this.scale = 1});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final k = scale;
      return Column(
        key: const Key('kozmetik-magaza'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('KOZMETİK'.tr, style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k))),
              ),
              _GemBalance(total: c.totalGems, scale: k),
            ],
          ),
          SizedBox(height: 4 * k),
          Text(
            'Yalnız görünüm: kozmetikler maç gücü vermez.'.tr,
            style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
          ),
          SizedBox(height: 12 * k),
          if (c.offers.isEmpty)
            Padding(
              padding: EdgeInsets.all(24 * k),
              child: Text(
                'Şu an satışta kozmetik yok.'.tr,
                textAlign: TextAlign.center,
                style: V21Type.label(13 * k, weight: FontWeight.w700, color: V21Colors.textDim),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                const perRow = 2;
                final gap = 10 * k;
                final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final o in c.offers)
                      SizedBox(
                        width: w,
                        child: _OfferCard(o: o, c: c, scale: k),
                      ),
                  ],
                );
              },
            ),
          if (c.error != null) ...[
            SizedBox(height: 10 * k),
            Text(
              c.error!,
              key: const Key('kozmetik-hata'),
              textAlign: TextAlign.center,
              style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.danger),
            ),
          ],
        ],
      );
    },
  );
}

class _GemBalance extends StatelessWidget {
  final int total;
  final double scale;
  const _GemBalance({required this.total, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '{n} elmas'.trArgs({'n': total}),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(6 * k, 4 * k, 12 * k, 4 * k),
        decoration: BoxDecoration(
          color: V21Colors.panel,
          borderRadius: BorderRadius.circular(20 * k),
          border: Border.all(color: V21Colors.ink, width: 2 * k),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            V21GemIcon(size: 22 * k),
            SizedBox(width: 4 * k),
            Text(V21Format.thousands(total), style: V21Type.title(16 * k)),
          ],
        ),
      ),
    );
  }
}

/// Teklifin küçük görseli (çerçeve: örnek avatar; zafer: yıldız)
class CosmeticOfferArt extends StatelessWidget {
  final String slug;
  final String slot;
  final double size;
  final bool animate;
  const CosmeticOfferArt({super.key, required this.slug, required this.slot, required this.size, this.animate = false});

  @override
  Widget build(BuildContext context) {
    if (slot == 'frame') {
      final u = getIt.isRegistered<SessionManager>() ? getIt<SessionManager>().user : null;
      return Center(
        child: CosmeticFrame(
          slug: slug,
          size: size * 0.78,
          child: V21PlayerAvatar(
            seed: 'oyuncu-${u?.id ?? u?.username ?? 'onizleme'}',
            semanticsLabel: '',
            name: u?.username,
            size: size * 0.78,
            ringColor: Colors.transparent,
            background: const Color(0xFFFF9F5A),
          ),
        ),
      );
    }
    // Zafer animasyonu
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: SizedBox(
        width: size * 1.4,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8A3FD8), Color(0xFF3A1680)],
                ),
              ),
            ),
            if (animate)
              slug == 'victory_star_rain'
                  ? const StarRainOverlay(active: true, loop: true)
                  : cosmeticVictoryOverlay(slug, active: true),
            Center(
              child: Text('ZAFER!'.tr, style: V21Type.title(size * 0.2, shadows: V21Type.inkShadow(size / 120))),
            ),
            if (!animate)
              Positioned(
                right: size * 0.08,
                top: size * 0.08,
                child: V21StarIcon(size: size * 0.22, color: V21Colors.goldTop),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final CosmeticOffer o;
  final CosmeticShopController c;
  final double scale;
  const _OfferCard({required this.o, required this.c, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final mesgul = c.busyOffer == o.id;
    return Semantics(
      button: true,
      label: '{name}, önizle'.trArgs({'name': o.name}),
      child: GestureDetector(
        key: Key('kozmetik-${o.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showCosmeticPreview(context, o, c),
        child: Container(
          padding: EdgeInsets.fromLTRB(8 * k, 10 * k, 8 * k, 10 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * k),
            border: Border.all(color: o.featured ? const Color(0xFFFFC832) : V21Colors.ink, width: 3 * k),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A2BA8), Color(0xFF2A1470)],
            ),
          ),
          child: Column(
            children: [
              if (o.featured)
                V21Tag(
                  text: 'ÖNE ÇIKAN'.tr,
                  background: const Color(0xFFFFD84A),
                  foreground: const Color(0xFF5A2A00),
                  scale: k,
                  fontSize: 10,
                ),
              SizedBox(height: 6 * k),
              SizedBox(
                height: 96 * k,
                child: CosmeticOfferArt(slug: o.itemSlug, slot: o.slot, size: 96 * k),
              ),
              SizedBox(height: 8 * k),
              Text(
                o.name.contains(': ') ? o.name.split(': ').last : o.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V21Type.title(16 * k, shadows: V21Type.inkShadow(k * 0.6)),
              ),
              Text(
                o.slot == 'frame' ? 'Profil çerçevesi'.tr : 'Zafer animasyonu'.tr,
                style: V21Type.label(11 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
              ),
              SizedBox(height: 8 * k),
              _OfferButton(o: o, c: c, busy: mesgul, scale: k * 0.85),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferButton extends StatelessWidget {
  final CosmeticOffer o;
  final CosmeticShopController c;
  final bool busy;
  final double scale;
  const _OfferButton({required this.o, required this.c, required this.busy, required this.scale});

  @override
  Widget build(BuildContext context) {
    final durum = busy ? V21ButtonStatus.loading : V21ButtonStatus.normal;
    if (o.equipped) {
      return V21GameButton(
        label: 'GİYİLİ'.tr,
        size: V21ButtonSize.small,
        scale: scale,
        status: V21ButtonStatus.disabled,
        onPressed: null,
      );
    }
    if (o.owned) {
      return V21GameButton(
        key: Key('giy-${o.id}'),
        label: 'GİY'.tr,
        tone: V21ButtonTone.blue,
        size: V21ButtonSize.small,
        scale: scale,
        status: durum,
        onPressed: () => c.equip(o),
      );
    }
    final yeter = c.canAfford(o);
    return V21GameButton(
      key: Key('kozmetik-al-${o.id}'),
      label: V21Format.thousands(o.priceGems),
      leading: V21GemIcon(size: 20 * scale),
      tone: V21ButtonTone.green,
      size: V21ButtonSize.small,
      scale: scale,
      status: busy ? V21ButtonStatus.loading : (yeter ? V21ButtonStatus.normal : V21ButtonStatus.disabled),
      semanticsLabel: '{p} elmas ile satın al'.trArgs({'p': o.priceGems}),
      onPressed: yeter ? () => confirmCosmeticPurchase(context, o, c) : null,
    );
  }
}

/// Önizleme: büyük görsel + açıklama + satın al / giy
Future<void> showCosmeticPreview(BuildContext context, CosmeticOffer o, CosmeticShopController c) async {
  final yeter = c.canAfford(o);
  final eylem = await V21GameDialog.show<String>(
    context,
    subtitle: 'ÖNİZLEME'.tr,
    title: o.name.contains(': ') ? o.name.split(': ').last : o.name,
    message: o.description,
    content: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        key: const Key('kozmetik-onizleme'),
        height: 150,
        child: CosmeticOfferArt(slug: o.itemSlug, slot: o.slot, size: 150, animate: true),
      ),
    ),
    actions: [
      if (o.owned && !o.equipped) V21DialogAction('GİY'.tr, tone: V21ButtonTone.blue, result: 'equip'),
      if (!o.owned)
        V21DialogAction(
          yeter ? '{p} ELMAS'.trArgs({'p': o.priceGems}) : 'ELMAS YETMİYOR'.tr,
          tone: V21ButtonTone.green,
          result: yeter ? 'buy' : null,
        ),
      V21DialogAction('KAPAT'.tr, tone: V21ButtonTone.purple, result: null),
    ],
  );
  if (!context.mounted) return;
  if (eylem == 'equip') {
    await c.equip(o);
  } else if (eylem == 'buy') {
    await confirmCosmeticPurchase(context, o, c);
  }
}

/// Açık onay: fiyat, ne kadarının ücretsiz/ücretli elmastan düşeceği
Future<void> confirmCosmeticPurchase(BuildContext context, CosmeticOffer o, CosmeticShopController c) async {
  final ucretsiz = c.freeGems < o.priceGems ? c.freeGems : o.priceGems;
  final ucretli = o.priceGems - ucretsiz;
  final evet = await V21GameDialog.show<bool>(
    context,
    subtitle: 'SATIN AL'.tr,
    title: o.name.contains(': ') ? o.name.split(': ').last : o.name,
    message: ucretli > 0
        ? '{p} elmas: {free} ücretsiz + {paid} satın alınmış elmas.'.trArgs({
            'p': o.priceGems,
            'free': ucretsiz,
            'paid': ucretli,
          })
        : '{p} elmas (ücretsiz elmasından).'.trArgs({'p': o.priceGems}),
    actions: [
      V21DialogAction('SATIN AL'.tr, tone: V21ButtonTone.green, result: true),
      V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.purple, result: false),
    ],
  );
  if (evet != true || !context.mounted) return;
  if (await c.buy(o) && context.mounted) {
    final giy = await V21GameDialog.show<bool>(
      context,
      title: 'TEBRİKLER!'.tr,
      message: '{name} artık senin.'.trArgs({'name': o.name}),
      actions: [
        V21DialogAction('ŞİMDİ GİY'.tr, tone: V21ButtonTone.blue, result: true),
        V21DialogAction('TAMAM'.tr, tone: V21ButtonTone.purple, result: false),
      ],
    );
    if (giy == true) {
      final guncel = c.offers.where((x) => x.id == o.id).firstOrNull;
      if (guncel != null) await c.equip(guncel);
    }
  }
}

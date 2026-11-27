import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/app_language.dart';
import '../../../features/monetization/purchase/purchase_controller.dart';
import '../../ui_v21.dart';
import 'v21_cosmetic_shop.dart';

/// 061 — Mağazada ELMAS PAKETLERİ.
///
/// Yalnız sunucu satışı açtıysa ve mağaza fiyat döndürdüyse görünür
/// (fiyat uydurulmaz, gerçek mağaza fiyatı yerel para biriminde).
/// Satın almadan önce açık onay: içerik, fiyat ve "dijital içerik anında
/// teslim edilir; cayma hakkı yoktur" (Mesafeli Sözleşmeler Yönetmeliği
/// m.15/1-ğ — hukuki metin insan onayı gerektirir).
class V21GemPacksSection extends StatefulWidget {
  final double scale;
  const V21GemPacksSection({super.key, this.scale = 1});

  @override
  State<V21GemPacksSection> createState() => _V21GemPacksSectionState();
}

class _V21GemPacksSectionState extends State<V21GemPacksSection> {
  PurchaseController? _c;

  @override
  void initState() {
    super.initState();
    _c = getIt.isRegistered<PurchaseController>() ? getIt<PurchaseController>() : null;
    _c?.load();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.enabled) return const SizedBox.shrink();
        final k = widget.scale;
        final mesaj = c.message;
        // 062: başlangıç paketi ayrı afiş (tek seferlik; alındıysa gösterilmez)
        final baslangic = c.products.where((p) => p.category == 'STARTER_PACK' && !p.owned).toList();
        final paketler = c.products.where((p) => p.category == 'GEM_PACK').toList();
        return Column(
          key: const Key('elmas-paketleri'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in baslangic) ...[_StarterPackBanner(p: p, c: c, scale: k), SizedBox(height: 16 * k)],
            Text('ELMAS PAKETLERİ'.tr, style: V21Type.title(24 * k, shadows: V21Type.inkShadow(k))),
            SizedBox(height: 4 * k),
            Text(
              'Elmas kozmetik ürünlerde kullanılır; maç gücü vermez.'.tr,
              style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
            ),
            SizedBox(height: 10 * k),
            Wrap(
              spacing: 8 * k,
              runSpacing: 8 * k,
              children: [
                for (final p in paketler)
                  SizedBox(
                    width: 112 * k,
                    child: _PackCard(p: p, c: c, scale: k),
                  ),
              ],
            ),
            if (mesaj != null && mesaj.isNotEmpty) ...[
              SizedBox(height: 8 * k),
              Text(
                mesaj,
                key: const Key('satin-alma-mesaji'),
                textAlign: TextAlign.center,
                style: V21Type.label(
                  13 * k,
                  weight: FontWeight.w800,
                  color: c.state == PurchaseFlowState.failed ? V21Colors.danger : V21Colors.successText,
                ),
              ),
            ],
            Align(
              child: TextButton(
                onPressed: c.restore,
                child: Text(
                  'SATIN ALIMLARI GERİ YÜKLE'.tr,
                  style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 063 — PREMIUM SEZON YOLU teklifi (sezon ekranında).
///
/// Yalnız sunucu satıyorsa görünür: süren sezonun premium yolu tamamen
/// güçsüz (ücretli elmas + pas kozmetiği), bayrak açık, oyuncu bu sezon
/// almamış. Alınınca ulaşılmış kademelerin premium ödülleri hemen
/// alınabilir (geriye dönük); [onPremium] sezon ekranını yeniler.
class V21SeasonPremiumOffer extends StatefulWidget {
  final double scale;
  final Future<void> Function()? onPremium;
  const V21SeasonPremiumOffer({super.key, this.scale = 1, this.onPremium});

  @override
  State<V21SeasonPremiumOffer> createState() => _V21SeasonPremiumOfferState();
}

class _V21SeasonPremiumOfferState extends State<V21SeasonPremiumOffer> {
  PurchaseController? _c;
  PurchaseFlowState? _onceki;

  @override
  void initState() {
    super.initState();
    _c = getIt.isRegistered<PurchaseController>() ? getIt<PurchaseController>() : null;
    _c?.addListener(_durum);
    _c?.load();
  }

  void _durum() {
    final s = _c?.state;
    if (s == PurchaseFlowState.success && _onceki != s) widget.onPremium?.call();
    _onceki = s;
  }

  @override
  void dispose() {
    _c?.removeListener(_durum);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.products.where((x) => x.category == 'SEASON_PASS' && !x.owned).firstOrNull;
        if (!c.enabled || p == null) return const SizedBox.shrink();
        final k = widget.scale;
        final mesaj = c.message;
        return Padding(
          padding: EdgeInsets.only(top: 12 * k),
          child: Container(
            key: const Key('premium-sezon-yolu'),
            padding: EdgeInsets.all(12 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * k),
              border: Border.all(color: V21Colors.ink, width: 3 * k),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB02E), Color(0xFFE5394B), Color(0xFF6A1F8A)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('PREMIUM YOL'.tr, style: V21Type.title(22 * k, shadows: V21Type.inkShadow(k))),
                SizedBox(height: 4 * k),
                Text(
                  'Elmas ve sezona özel çerçeveler; ulaştığın kademeler hemen açılır. Güç vermez.'.tr,
                  style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFFFF1E0), height: 1.35),
                ),
                SizedBox(height: 10 * k),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _BuyButton(p: p, c: c, scale: k),
                ),
                if (mesaj != null && mesaj.isNotEmpty) ...[
                  SizedBox(height: 6 * k),
                  Text(
                    mesaj,
                    style: V21Type.label(
                      12 * k,
                      weight: FontWeight.w800,
                      color: c.state == PurchaseFlowState.failed ? const Color(0xFFFFD0D6) : Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 062 — BAŞLANGIÇ PAKETİ afişi: içerik açıkça yazılır (mağazada
/// satılmayan çerçeve + ücretli elmas), maç gücü vermez, tek seferlik.
class _StarterPackBanner extends StatelessWidget {
  final ShopProduct p;
  final PurchaseController c;
  final double scale;
  const _StarterPackBanner({required this.p, required this.c, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final cerceve = p.itemSlugs.where((s) => s.startsWith('frame_')).firstOrNull;
    return Container(
      key: const Key('baslangic-paketi'),
      padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 12 * k, 12 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E8BFF), Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Row(
        children: [
          if (cerceve != null)
            SizedBox(
              width: 92 * k,
              height: 92 * k,
              child: CosmeticOfferArt(slug: cerceve, slot: 'frame', size: 92 * k),
            ),
          SizedBox(width: 10 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V21Tag(
                  text: 'TEK SEFERLİK'.tr,
                  background: const Color(0xFFFFD84A),
                  foreground: const Color(0xFF5A2A00),
                  scale: k,
                  fontSize: 10,
                ),
                SizedBox(height: 4 * k),
                Text(p.name, style: V21Type.title(20 * k, shadows: V21Type.inkShadow(k))),
                Text(
                  [
                    if (cerceve != null) 'Özel profil çerçevesi'.tr,
                    if (p.paidGems > 0) '{n} elmas'.trArgs({'n': p.paidGems}),
                  ].join(' + '),
                  style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFDCE6FF)),
                ),
                Text(
                  'Maç gücü vermez.'.tr,
                  style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
                ),
                SizedBox(height: 8 * k),
                _BuyButton(p: p, c: c, scale: k),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mağaza fiyatlı satın alma düğmesi (açık onaylı)
class _BuyButton extends StatelessWidget {
  final ShopProduct p;
  final PurchaseController c;
  final double scale;
  const _BuyButton({required this.p, required this.c, required this.scale});

  @override
  Widget build(BuildContext context) => V21GameButton(
    key: Key('satin-al-${p.id}'),
    label: p.owned ? 'ALINDI'.tr : p.price!.price,
    tone: p.owned ? V21ButtonTone.purple : V21ButtonTone.green,
    size: V21ButtonSize.small,
    scale: scale,
    status: c.busyProduct == p.id ? V21ButtonStatus.loading : V21ButtonStatus.normal,
    onPressed: p.purchasable ? () => confirmStorePurchase(context, p, c) : null,
  );
}

class _PackCard extends StatelessWidget {
  final ShopProduct p;
  final PurchaseController c;
  final double scale;
  const _PackCard({required this.p, required this.c, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      padding: EdgeInsets.fromLTRB(6 * k, 10 * k, 6 * k, 8 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Column(
        children: [
          V21GemIcon(size: 40 * k),
          SizedBox(height: 4 * k),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${p.paidGems}', style: V21Type.title(22 * k)),
          ),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V21Type.label(11 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
          ),
          SizedBox(height: 8 * k),
          _BuyButton(p: p, c: c, scale: k),
        ],
      ),
    );
  }
}

/// Satın almadan önce açık onay: içerik, fiyat ve cayma hakkı bilgisi
Future<void> confirmStorePurchase(BuildContext context, ShopProduct p, PurchaseController c) async {
  var kabul = false;
  final evet = await V21GameDialog.show<bool>(
    context,
    subtitle: 'SATIN AL'.tr,
    title: p.name,
    message: p.category == 'SEASON_PASS'
        ? 'Bu sezonun premium yolu · {price}'.trArgs({'price': p.price!.price})
        : p.itemSlugs.isEmpty
        ? '{gems} elmas · {price}'.trArgs({'gems': p.paidGems, 'price': p.price!.price})
        : '{gems} elmas + özel çerçeve · {price}'.trArgs({'gems': p.paidGems, 'price': p.price!.price}),
    content: StatefulBuilder(
      builder: (context, set) => CheckboxListTile(
        key: const Key('cayma-onayi'),
        value: kabul,
        onChanged: (v) => set(() => kabul = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Dijital içerik anında teslim edilir; teslimden sonra cayma hakkım olmadığını kabul ediyorum.'.tr,
          style: V21Type.label(12, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    ),
    actions: [
      V21DialogAction('SATIN AL'.tr, tone: V21ButtonTone.green, result: true),
      V21DialogAction('VAZGEÇ'.tr, tone: V21ButtonTone.purple, result: false),
    ],
  );
  if (evet != true || !context.mounted) return;
  if (!kabul) {
    await V21GameDialog.show<void>(
      context,
      title: 'ONAY GEREKLİ'.tr,
      message: 'Satın almak için teslim ve cayma hakkı bilgisini onaylaman gerekiyor.'.tr,
      actions: [V21DialogAction('TAMAM'.tr, tone: V21ButtonTone.blue)],
    );
    return;
  }
  await c.buy(p);
}

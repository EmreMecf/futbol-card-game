import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/store/presentation/viewmodel/store_view_model.dart';
import '../rewards/v21_pack_opening.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';
import '../home/v21_home_nav.dart';
import '../../web/web_kit.dart';
import '../../web/web_screens.dart';

/// V2.1 MAĞAZA (referans `assets/v21/screens/store.png`).
///
///   MAĞAZA                               ( ● 2.450 )
///   ┌ GÜNÜN TEKLİFİ  Altın Paket  [● 1.500]      sandık %25 ┐
///   KART PAKETLERİ   [STANDART] [PREMIUM] [KADRO]  ← fiyat düğmesi = satın al
///   ÇIKMA İHTİMALİ   (●)%20 (●)%35 …                ← seçili paketin oranları
///   [PAKETLER] [TEKLİFLER] [KOZMETİK]
///
/// VERİ: `StoreViewModel` (mevcut) → `/api/packs`, `/api/packs/open`,
/// günün teklifi `DailyLoopService`. Fiyat, oran ve indirim sunucudan; paket
/// içeriğini sunucu belirler. Açılış V2.1 `V21PackOpening` ile gösterilir
/// (mühür → kart kart açılış → özet; Faz 5).
///
/// Sekmeler (prototip hotspot'larıyla aynı hedefler): TEKLİFLER → Kart
/// Takası, KOZMETİK → Envanter. Eski mağazada ikisi "yakında" idi.
class V21StoreScreen extends StatelessWidget {
  const V21StoreScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<StoreViewModel>(
    create: (_) => getIt<StoreViewModel>()..load(),
    child: Theme(data: V21Theme.data(context), child: const _Root()),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StoreViewModel>();
    // Altın bakiyesi satın almadan sonra başlıkta anlık güncellensin
    try {
      context.watch<SessionManager>();
    } on ProviderNotFoundException {
      // test
    }
    final opening = vm.lastOpening;
    if (opening != null) {
      return V21PackOpening(result: opening, onClose: vm.clearOpening);
    }
    if (v21IsWeb(context)) {
      void hata() {
        final msg = vm.errorMessage;
        if (msg == null || !context.mounted) return;
        AppSnackBar.showError(context, msg);
        vm.clearError();
      }

      return WebStore(
        vm: vm,
        onBuy: (p) async {
          if (!await vm.openPack(p)) hata();
        },
        onBuyOffer: () async {
          if (!await vm.buyDailyOffer()) hata();
        },
      );
    }
    return V21ScreenLayout(
      background: V21Background.page,
      body: (context, sc) => _Body(scale: sc.s),
      bottomNavigation: (context, sc) => V21HomeNav(currentRoute: AppRoutes.store, scale: sc.s),
    );
  }
}

/// Referans oran daireleri (Koleksiyon ile aynı renkler)
const _tierColors = <CardTier, Color>{
  CardTier.bronze: Color(0xFFFFAB76),
  CardTier.silver: Color(0xFFE8EEF6),
  CardTier.gold: Color(0xFFFFE07A),
  CardTier.diamond: Color(0xFF7FF3FF),
  CardTier.legend: Color(0xFFE3A9FA),
};

class _Body extends StatefulWidget {
  final double scale;
  const _Body({required this.scale});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String? _selectedSlug;

  PackType? _selected(StoreViewModel vm) {
    final slug = _selectedSlug ?? vm.featuredSlug;
    return vm.packs.where((p) => p.slug == slug).firstOrNull ??
        vm.packs.where((p) => p.isPurchasable).firstOrNull ??
        vm.packs.firstOrNull;
  }

  Future<void> _buy(StoreViewModel vm, PackType p) async {
    setState(() => _selectedSlug = p.slug);
    final ok = await vm.openPack(p);
    if (ok || !mounted) return;
    final msg = vm.errorMessage;
    if (msg != null) {
      AppSnackBar.showError(context, msg);
      vm.clearError();
    }
  }

  Future<void> _buyOffer(StoreViewModel vm) async {
    final ok = await vm.buyDailyOffer();
    if (ok || !mounted) return;
    final msg = vm.errorMessage;
    if (msg != null) {
      AppSnackBar.showError(context, msg);
      vm.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    final vm = context.watch<StoreViewModel>();
    final selected = _selected(vm);

    final List<Widget> content;
    if (vm.isLoading && vm.packs.isEmpty) {
      content = [
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
        ),
      ];
    } else if (vm.packs.isEmpty) {
      content = [
        V21EmptyState(
          icon: Icons.storefront_rounded,
          title: vm.hasError ? 'BAĞLANTI SORUNU' : 'SATIŞTA PAKET YOK',
          message: vm.errorMessage ?? 'Şu an satışta paket yok. Biraz sonra tekrar bak.',
          actionLabel: 'TEKRAR DENE',
          onAction: vm.load,
          scale: k,
        ),
      ];
    } else {
      content = [
        if (vm.dailyOffer != null) ...[
          _DailyOffer(vm: vm, scale: k, onBuy: () => _buyOffer(vm)),
          SizedBox(height: 18 * k),
        ],
        Text('KART PAKETLERİ', style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k))),
        SizedBox(height: 10 * k),
        _PackGrid(
          vm: vm,
          selectedSlug: selected?.slug,
          scale: k,
          onSelect: (p) => setState(() => _selectedSlug = p.slug),
          onBuy: (p) => _buy(vm, p),
        ),
        if (selected != null) ...[SizedBox(height: 16 * k), _Odds(pack: selected, scale: k)],
        SizedBox(height: 18 * k),
        _Tabs(scale: k),
        SizedBox(height: 14 * k),
        Text(
          'Paketten çıkan kartları sunucu belirler; oranlar gerçekten uygulanan değerlerdir.',
          textAlign: TextAlign.center,
          style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textDim, height: 1.4),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16 * k, 15 * k, 8 * k, 0),
          child: V21PageTitle(
            title: 'MAĞAZA',
            scale: k,
            trailing: V21ResourcePill.coins(coins: vm.coins, scale: k),
          ),
        ),
        SizedBox(height: 12 * k),
        Expanded(
          child: RefreshIndicator(
            color: V21Colors.goldTop,
            backgroundColor: V21Colors.panel,
            onRefresh: vm.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12 * k, 0, 12 * k, 24 * k),
              children: content,
            ),
          ),
        ),
      ],
    );
  }
}

/// Günün teklifi afişi (referans: turuncu-kırmızı zemin, sarı şerit,
/// yeşil fiyat düğmesi, sağda sandık ve kırmızı indirim rozeti)
class _DailyOffer extends StatelessWidget {
  final StoreViewModel vm;
  final double scale;
  final VoidCallback onBuy;
  const _DailyOffer({required this.vm, required this.scale, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final t = vm.dailyOffer!;
    final missing = t.discountedPrice - vm.coins;
    final busy = vm.openingPackSlug == t.packSlug;
    return Semantics(
      container: true,
      label: 'Günün teklifi: ${t.name}, ${t.cardCount} kart, %${t.discountPct} indirim',
      child: Container(
        height: 168 * k,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18 * k),
          border: Border.all(color: V21Colors.ink, width: 3 * k),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A2E), Color(0xFFE5394B), Color(0xFFB0193A)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 4 * k,
              top: -8 * k,
              bottom: 8 * k,
              width: 150 * k,
              child: Image.asset(V21Assets.chestGoldLarge, fit: BoxFit.contain),
            ),
            Positioned(
              right: 18 * k,
              top: -6 * k,
              child: Container(
                width: 58 * k,
                height: 58 * k,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE5294B),
                  border: Border.all(color: V21Colors.ink, width: 3 * k),
                ),
                child: Text('%${t.discountPct}', style: V21Type.title(21 * k, shadows: V21Type.inkShadow(k * 0.7))),
              ),
            ),
            Positioned(
              left: -4 * k,
              top: 8 * k,
              child: V21Tag(
                text: 'GÜNÜN TEKLİFİ',
                background: const Color(0xFFFFD84A),
                foreground: const Color(0xFF5A2A00),
                scale: k,
                fontSize: 12,
              ),
            ),
            Positioned(
              left: 14 * k,
              top: 44 * k,
              right: 150 * k,
              bottom: 12 * k,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(t.name, style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
                  ),
                  Text(
                    '${t.cardCount} kart · ${V21Format.thousands(t.price)} yerine',
                    style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFFFE3D6)),
                  ),
                  const Spacer(),
                  if (t.boughtToday)
                    V21GameButton(
                      label: 'BUGÜN ALINDI',
                      size: V21ButtonSize.small,
                      status: V21ButtonStatus.disabled,
                      scale: k,
                      onPressed: null,
                    )
                  else
                    _PriceButton(
                      price: t.discountedPrice,
                      affordable: missing <= 0,
                      busy: busy,
                      scale: k,
                      onPressed: vm.canBuyDailyOffer ? onBuy : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paraya göre yeşil (alınabilir) ya da gri (yetmiyor) fiyat düğmesi
class _PriceButton extends StatelessWidget {
  final int price;
  final bool affordable;
  final bool busy;
  final double scale;
  final VoidCallback? onPressed;
  const _PriceButton({
    required this.price,
    required this.affordable,
    required this.busy,
    required this.scale,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = price == 0 ? 'ÜCRETSİZ' : V21Format.thousands(price);
    return V21GameButton(
      label: label,
      leading: price == 0 ? null : V21CoinIcon(size: 22 * scale),
      tone: V21ButtonTone.green,
      size: V21ButtonSize.medium,
      scale: scale,
      status: busy
          ? V21ButtonStatus.loading
          : (affordable && onPressed != null ? V21ButtonStatus.normal : V21ButtonStatus.disabled),
      semanticsLabel: price == 0 ? 'Ücretsiz al' : '$label altın ile satın al',
      onPressed: onPressed,
    );
  }
}

class _PackGrid extends StatelessWidget {
  final StoreViewModel vm;
  final String? selectedSlug;
  final double scale;
  final ValueChanged<PackType> onSelect;
  final ValueChanged<PackType> onBuy;
  const _PackGrid({
    required this.vm,
    required this.selectedSlug,
    required this.scale,
    required this.onSelect,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final packs = vm.packs;
    return LayoutBuilder(
      builder: (context, c) {
        const perRow = 3;
        final gap = 8 * k;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: 12 * k,
          children: [
            for (final p in packs)
              SizedBox(
                width: w,
                child: _PackCard(
                  pack: p,
                  selected: p.slug == selectedSlug,
                  coins: vm.coins,
                  busy: vm.openingPackSlug == p.slug,
                  locked: vm.openingPackSlug != null,
                  scale: k,
                  onSelect: () => onSelect(p),
                  onBuy: () => onBuy(p),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  final PackType pack;
  final bool selected;
  final int coins;
  final bool busy;
  final bool locked;
  final double scale;
  final VoidCallback onSelect;
  final VoidCallback onBuy;
  const _PackCard({
    required this.pack,
    required this.selected,
    required this.coins,
    required this.busy,
    required this.locked,
    required this.scale,
    required this.onSelect,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final missing = pack.priceCoins - coins;
    final purchasable = pack.isPurchasable;
    return Semantics(
      button: true,
      selected: selected,
      label: '${pack.name}, ${pack.cardCount} kart, oranları göster',
      child: GestureDetector(
        onTap: onSelect,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.fromLTRB(6 * k, 8 * k, 6 * k, 8 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * k),
            border: Border.all(color: selected ? const Color(0xFFFFC832) : V21Colors.ink, width: 3 * k),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A2BA8), Color(0xFF2A1470)],
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 124 * k,
                child: _PackArt(tier: pack.signatureTier, scale: k),
              ),
              SizedBox(height: 6 * k),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  V21Format.upper(pack.name),
                  maxLines: 1,
                  style: V21Type.title(18 * k, shadows: V21Type.inkShadow(k * 0.7)),
                ),
              ),
              Text(
                '${pack.cardCount} kart',
                style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
              ),
              SizedBox(height: 6 * k),
              if (!purchasable)
                Text(
                  'SATIŞTA DEĞİL',
                  style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textDim),
                )
              else
                _PriceButton(
                  price: pack.priceCoins,
                  affordable: missing <= 0,
                  busy: busy,
                  scale: k * 0.82,
                  onPressed: locked ? null : onBuy,
                ),
              SizedBox(
                height: 16 * k,
                child: purchasable && missing > 0
                    ? Padding(
                        padding: EdgeInsets.only(top: 3 * k),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${V21Format.thousands(missing)} altın eksik',
                            style: V21Type.label(11 * k, weight: FontWeight.w800, color: const Color(0xFFFF7A8C)),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paket görseli: eğik kart arka yüzü + paketin İMZA nadirliğinde bir kart
/// (örnek futbolcu gösterilmez: paket içeriğini sunucu belirler)
class _PackArt extends StatelessWidget {
  final CardTier tier;
  final double scale;
  const _PackArt({required this.tier, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final r = V21Rarity.of(tier);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 2 * k,
          top: 6 * k,
          child: Transform.rotate(
            angle: -0.16,
            child: V21CardBack(width: 64 * k, semanticsLabel: ''),
          ),
        ),
        Positioned(
          right: 4 * k,
          top: 14 * k,
          child: Transform.rotate(
            angle: 0.06,
            child: Container(
              width: 66 * k,
              height: 94 * k,
              padding: EdgeInsets.all(3 * k),
              decoration: BoxDecoration(
                color: V21Colors.ink,
                borderRadius: BorderRadius.circular(9 * k),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6 * k)],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7 * k),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [r.frameLight, r.frame],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    V21StarIcon(size: 30 * k, color: Colors.white),
                    SizedBox(height: 4 * k),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(r.name, style: V21Type.title(14 * k, shadows: V21Type.inkShadow(k * 0.6))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Odds extends StatelessWidget {
  final PackType pack;
  final double scale;
  const _Odds({required this.pack, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final odds = pack.odds.where((o) => o.weight > 0).toList()..sort((a, b) => a.tier.rank.compareTo(b.tier.rank));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÇIKMA İHTİMALİ · ${V21Format.upper(pack.name)}',
          style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textMuted, letterSpacing: 0.4),
        ),
        SizedBox(height: 8 * k),
        Wrap(
          spacing: 10 * k,
          runSpacing: 8 * k,
          children: [
            for (final o in odds)
              Semantics(
                label: '${V21Rarity.of(o.tier).name} ${o.displayPercent}',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30 * k,
                      height: 30 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: V21Colors.ink, width: 3 * k),
                        gradient: RadialGradient(colors: [Colors.white, _tierColors[o.tier]!], stops: const [0, 0.7]),
                      ),
                    ),
                    SizedBox(width: 4 * k),
                    Text(o.displayPercent, style: V21Type.title(17 * k)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final double scale;
  const _Tabs({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    Widget tab(String label, V21ButtonTone tone, VoidCallback? onTap, String semantics) => Expanded(
      child: V21GameButton(
        label: label,
        tone: tone,
        size: V21ButtonSize.small,
        scale: k * 1.1,
        semanticsLabel: semantics,
        onPressed: onTap ?? () {},
      ),
    );
    return Row(
      children: [
        tab('PAKETLER', V21ButtonTone.gold, null, 'Paketler, şu an açık'),
        SizedBox(width: 8 * k),
        tab('TEKLİFLER', V21ButtonTone.blue, () => context.push(AppRoutes.sbc), 'Teklifler: kart takası'),
        SizedBox(width: 8 * k),
        tab('KOZMETİK', V21ButtonTone.blue, () => context.push(AppRoutes.inventory), 'Kozmetik: envanter'),
      ],
    );
  }
}

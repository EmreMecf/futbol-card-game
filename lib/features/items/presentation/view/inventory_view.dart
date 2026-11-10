import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../chests/presentation/widgets/chest_widgets.dart';
import '../viewmodel/items_view_model.dart';

/// Item kategorisinin simgesi ve rengi (çizim; emoji değil)
(IconData, Color) itemIcon(String category) => switch (category) {
      'chest_key' => (Icons.vpn_key_rounded, Ref.gold),
      'chest_speedup' => (Icons.fast_forward_rounded, Ref.blue),
      'energy_drink' => (Icons.bolt_rounded, const Color(0xFFFFB648)),
      'mastery_book' => (Icons.menu_book_rounded, Ref.accent),
      'joker' => (Icons.extension_rounded, Ref.purple),
      'level_discount' => (Icons.sell_rounded, Ref.gold),
      'event_ticket' => (Icons.confirmation_number_rounded, Ref.blue),
      'profile_frame' => (Icons.crop_square_rounded, Ref.gold),
      'kit' => (Icons.checkroom_rounded, Ref.accent),
      'card_skin' => (Icons.style_rounded, Ref.purple),
      'arena_skin' => (Icons.stadium_rounded, Ref.accent),
      'victory_anim' => (Icons.celebration_rounded, Ref.gold),
      'character_cosmetic' => (Icons.face_rounded, Ref.blue),
      'season_badge' => (Icons.military_tech_rounded, Ref.gold),
      _ => (Icons.inventory_2_rounded, Ref.muted),
    };

/// ENVANTER (Ekonomi V2, FAZ 3) — referans dili: geri + .sectionhead,
/// .card-panel satırları. Hiçbir item dereceli maçta güç vermez.
class InventoryView extends StatelessWidget {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ItemsViewModel>(
        create: (_) => getIt<ItemsViewModel>()..load(),
        child: const AppShell(currentRoute: AppRoutes.profile, child: _Govde()),
      );
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemsViewModel>();
    final e = vm.inventory;

    final List<Widget> icerik;
    if (e == null) {
      icerik = [
        if (vm.isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else
          RefCardPanel(children: [
            Text(vm.errorMessage ?? 'Envanter yüklenemedi.', style: Ref.bodyText(12)),
            RefSecondaryButton('TEKRAR DENE', onTap: vm.load),
          ]),
      ];
    } else if (!e.enabled) {
      icerik = [const RefNote('Envanter henüz açık değil.', title: 'Yakında')];
    } else {
      List<ItemDefinition> grup(bool Function(ItemDefinition) f) =>
          e.catalog.where(f).where((d) => e.quantity(d.slug) > 0).toList();
      final tuketilen = grup((d) => d.kind == ItemKinds.consumable);
      final joker = grup((d) => d.category == 'joker');
      final sureli = grup((d) => d.isTimed);
      final kozmetik = grup((d) => d.isCosmetic);
      final bos = tuketilen.isEmpty && joker.isEmpty && sureli.isEmpty && kozmetik.isEmpty;

      icerik = [
        if (vm.lastInfo != null) ...[
          Text(vm.lastInfo!, style: Ref.bodyText(12, color: Ref.accent, weight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        if (vm.actionError != null) ...[
          Text(vm.actionError!, style: Ref.bodyText(12, color: Ref.red, weight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        if (bos)
          const RefNote('Envanterin boş. Itemler Battle Pass, görev ve etkinlik ödüllerinden gelir.', title: 'Henüz item yok'),
        if (tuketilen.isNotEmpty) _Bolum('TÜKETİLEBİLİR', [for (final d in tuketilen) _Satir(d: d, e: e, vm: vm)]),
        if (joker.isNotEmpty) _Bolum('JOKER PARÇALAR', [for (final d in joker) _Satir(d: d, e: e, vm: vm)]),
        if (sureli.isNotEmpty) _Bolum('SÜRELİ', [for (final d in sureli) _Satir(d: d, e: e, vm: vm)]),
        if (kozmetik.isNotEmpty) _Bolum('KOZMETİK', [for (final d in kozmetik) _Satir(d: d, e: e, vm: vm)]),
        const SizedBox(height: Ref.pageGap),
        const RefNote(
            'Itemler dereceli maçta güç vermez. Anahtar ve hızlandırıcı sandık ekranında, ustalık kitabı ve '
            'gelişim indirimi gelişim ekranında kullanılır. Süresi dolan item gösterilmez.',
            title: 'Nasıl kullanılır?'),
      ];
    }

    return ListView(
      padding: Ref.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefPageEnter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  RefNeutralButton(
                    padding: const EdgeInsets.all(7),
                    semanticLabel: 'Geri',
                    onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.profile),
                    child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: RefSectionHead('ENVANTER', size: 27, kicker: 'ITEMLER VE KOZMETİKLER')),
                ]),
                const SizedBox(height: Ref.pageGap),
                ...icerik,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bolum extends StatelessWidget {
  final String baslik;
  final List<Widget> satirlar;
  const _Bolum(this.baslik, this.satirlar);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Ref.pageGap),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(baslik, style: Ref.caps(Ref.muted)),
          const SizedBox(height: 8),
          for (var i = 0; i < satirlar.length; i++) ...[if (i > 0) const SizedBox(height: 8), satirlar[i]],
        ]),
      );
}

class _Satir extends StatelessWidget {
  final ItemDefinition d;
  final ItemInventory e;
  final ItemsViewModel vm;
  const _Satir({required this.d, required this.e, required this.vm});

  @override
  Widget build(BuildContext context) {
    final (ikon, renk) = itemIcon(d.category);
    final adet = e.quantity(d.slug);
    final giyili = e.isEquipped(d.slug);
    final mesgul = vm.busySlug == d.slug;

    String? alt;
    if (d.isTimed) {
      final bitis = e.items.where((i) => i.slug == d.slug && i.expiresAt != null).map((i) => i.expiresAt!).fold<DateTime?>(
          null, (a, b) => a == null || b.isBefore(a) ? b : a);
      if (bitis != null) alt = 'Bitiş: ${chestDuration(bitis.difference(e.serverTime))} sonra';
    }
    if (d.category == 'energy_drink') {
      final sinir = (d.params['daily_limit'] as num?)?.toInt() ?? 2;
      alt = 'Bugün ${e.energyDrinksToday}/$sinir kullanıldı';
    }

    Widget? eylem;
    if (mesgul) {
      eylem = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (d.usableFromInventory) {
      eylem = RefNeutralButton(label: 'KULLAN', onTap: () => vm.use(d));
    } else if (d.isCosmetic) {
      eylem = giyili
          ? RefNeutralButton(label: 'ÇIKAR', onTap: () => vm.unequip(d))
          : RefNeutralButton(label: 'GİY', onTap: () => vm.equip(d));
    }

    return RefCardPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: renk.withValues(alpha: 0.6)),
            ),
            child: Icon(ikon, size: 22, color: renk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(d.name, style: Ref.bodyText(13, weight: FontWeight.w800))),
                if (!d.isCosmetic) Text('×$adet', style: Ref.heading(16, color: renk)),
                if (giyili) const RefPill('GİYİLİ', dot: true),
              ]),
              const SizedBox(height: 2),
              Text(d.description, style: Ref.bodyText(10.5, color: Ref.muted)),
              if (alt != null) ...[
                const SizedBox(height: 2),
                Text(alt, style: Ref.tiny(Ref.gold)),
              ],
            ]),
          ),
          if (eylem != null) ...[const SizedBox(width: 8), eylem],
        ]),
      ],
    );
  }
}

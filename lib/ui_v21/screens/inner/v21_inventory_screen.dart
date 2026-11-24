import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/items/presentation/viewmodel/items_view_model.dart';
import '../../ui_v21.dart';

/// V2.1 ENVANTER (referans `assets/v21/screens/inventory.png`).
///
///   ‹ ENVANTER
///   2 sütun karo: büyük renkli daire + simge, sağ üstte "×3", ad,
///   kullanılabilir eşyada KULLAN, kozmetikte GİY / ÇIKAR
///   "Eşyaya dokun → ne işe yaradığını gör"
///
/// VERİ: `ItemsViewModel` (mevcut) → `/api/items`, kullanma/giyme
/// idempotency anahtarlı. Hiçbir eşya dereceli maçta güç vermez.
class V21InventoryScreen extends StatelessWidget {
  const V21InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<ItemsViewModel>(create: (_) => getIt<ItemsViewModel>()..load(), child: const _Body());
}

/// Kategori → (simge, daire rengi) — referans renkleri
(IconData, Color) v21ItemStyle(String category) => switch (category) {
  'chest_key' => (Icons.vpn_key_rounded, const Color(0xFFFFC832)),
  'chest_speedup' => (Icons.fast_forward_rounded, const Color(0xFF5FB4FF)),
  'energy_drink' => (Icons.bolt_rounded, const Color(0xFFFF9500)),
  'mastery_book' => (Icons.menu_book_rounded, const Color(0xFF3DD15A)),
  'joker' => (Icons.diamond_rounded, const Color(0xFFE3A9FA)),
  'level_discount' => (Icons.percent_rounded, const Color(0xFFFF5A6E)),
  'event_ticket' => (Icons.confirmation_number_rounded, const Color(0xFF5FB4FF)),
  'profile_frame' => (Icons.crop_square_rounded, const Color(0xFFFFC832)),
  'kit' => (Icons.checkroom_rounded, const Color(0xFF3DD15A)),
  'card_skin' => (Icons.style_rounded, const Color(0xFFE3A9FA)),
  'arena_skin' => (Icons.stadium_rounded, const Color(0xFF3DD15A)),
  'victory_anim' => (Icons.celebration_rounded, const Color(0xFFFFC832)),
  'character_cosmetic' => (Icons.face_rounded, const Color(0xFF5FB4FF)),
  'season_badge' => (Icons.military_tech_rounded, const Color(0xFFFFC832)),
  _ => (Icons.inventory_2_rounded, const Color(0xFF8E7FBE)),
};

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ItemsViewModel>();
    final e = vm.inventory;
    return V21InnerPage(
      title: 'ENVANTER',
      route: AppRoutes.inventory,
      fallbackRoute: AppRoutes.profile,
      state: e == null
          ? (vm.isLoading ? V21PageState.loading : V21PageState.error)
          : (e.enabled ? V21PageState.ready : V21PageState.disabled),
      errorMessage: vm.errorMessage,
      onRetry: vm.load,
      onRefresh: vm.load,
      disabledTitle: 'ENVANTER YAKINDA',
      disabledMessage: 'Envanter henüz açık değil.',
      children: (context, k) {
        final owned = e!.catalog.where((d) => e.quantity(d.slug) > 0).toList();
        return [
          if (vm.lastInfo != null || vm.actionError != null) ...[
            Text(
              vm.actionError ?? vm.lastInfo!,
              textAlign: TextAlign.center,
              style: V21Type.label(
                13 * k,
                weight: FontWeight.w800,
                color: vm.actionError != null ? V21Colors.danger : V21Colors.successText,
              ),
            ),
            SizedBox(height: 10 * k),
          ],
          if (owned.isEmpty)
            V21EmptyState(
              icon: Icons.backpack_rounded,
              title: 'HENÜZ EŞYA YOK',
              message: 'Eşyalar sezon yolu, görev ve etkinlik ödüllerinden gelir.',
              scale: k,
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final gap = 12 * k;
                // Telefonda 2 sütun; genişledikçe sütun artar
                final columns = ((c.maxWidth + gap) / (178 * k + gap)).floor().clamp(2, 4);
                final w = (c.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final d in owned)
                      SizedBox(
                        width: w,
                        child: _ItemTile(def: d, inv: e, vm: vm, scale: k),
                      ),
                  ],
                );
              },
            ),
          SizedBox(height: 14 * k),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 10 * k),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1150),
              borderRadius: BorderRadius.circular(14 * k),
              border: Border.all(color: V21Colors.ink, width: 2 * k),
            ),
            child: Text(
              'Eşyaya dokun → ne işe yaradığını gör',
              textAlign: TextAlign.center,
              style: V21Type.label(13 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
            ),
          ),
        ];
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ItemDefinition def;
  final ItemInventory inv;
  final ItemsViewModel vm;
  final double scale;
  const _ItemTile({required this.def, required this.inv, required this.vm, required this.scale});

  /// Karonun eylemi: (etiket, işlem) ya da null
  (String, Future<bool> Function())? get _action {
    if (def.usableFromInventory) return ('KULLAN', () => vm.use(def));
    if (def.isCosmetic) {
      return inv.isEquipped(def.slug) ? ('ÇIKAR', () => vm.unequip(def)) : ('GİY', () => vm.equip(def));
    }
    return null;
  }

  String? get _extra {
    if (def.isTimed) {
      final ends = inv.items
          .where((i) => i.slug == def.slug && i.expiresAt != null)
          .map((i) => i.expiresAt!)
          .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
      if (ends != null) return 'Bitiş: ${V21Format.shortDuration(ends.difference(inv.serverTime).inSeconds)} sonra';
    }
    if (def.category == 'energy_drink') {
      final limit = (def.params['daily_limit'] as num?)?.toInt() ?? 2;
      return 'Bugün ${inv.energyDrinksToday}/$limit kullanıldı';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final (icon, color) = v21ItemStyle(def.category);
    final qty = inv.quantity(def.slug);
    final equipped = inv.isEquipped(def.slug);
    final busy = vm.busySlug == def.slug;
    final action = _action;
    return Semantics(
      button: true,
      label: '${def.name}${def.isCosmetic ? (equipped ? ', giyili' : '') : ', $qty adet'}. Ayrıntı için dokun',
      child: GestureDetector(
        onTap: () => _details(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 232 * k,
          padding: EdgeInsets.fromLTRB(8 * k, 10 * k, 8 * k, 10 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * k),
            border: Border.all(color: equipped ? V21Colors.success : V21Colors.ink, width: 3 * k),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  V21ItemArt(
                    category: def.category,
                    tier: v21ItemTier(def.slug),
                    size: 112 * k,
                    fallbackIcon: icon,
                    fallbackColor: color,
                  ),
                  SizedBox(height: 8 * k),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      def.name,
                      maxLines: 1,
                      style: V21Type.title(17 * k, shadows: V21Type.inkShadow(k * 0.7)),
                    ),
                  ),
                  if (_extra != null)
                    Text(
                      _extra!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V21Type.label(10 * k, weight: FontWeight.w700, color: V21Colors.goldTop),
                    ),
                  const Spacer(),
                  if (action != null)
                    SizedBox(
                      width: 120 * k,
                      child: V21GameButton(
                        label: action.$1,
                        tone: action.$1 == 'ÇIKAR' ? V21ButtonTone.purple : V21ButtonTone.green,
                        size: V21ButtonSize.small,
                        scale: k * 0.9,
                        status: busy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
                        semanticsLabel: '${def.name}: ${action.$1}',
                        onPressed: action.$2,
                      ),
                    ),
                ],
              ),
              if (!def.isCosmetic)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 2 * k),
                    decoration: BoxDecoration(
                      color: V21Colors.ink,
                      borderRadius: BorderRadius.circular(14 * k),
                      border: Border.all(color: color, width: 2 * k),
                    ),
                    child: Text('×$qty', style: V21Type.title(15 * k, color: color)),
                  ),
                ),
              if (equipped)
                Positioned(
                  right: 0,
                  top: 0,
                  child: V21Tag(text: 'GİYİLİ', background: V21Colors.success, foreground: Colors.white, scale: k),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _details(BuildContext context) async {
    final (icon, color) = v21ItemStyle(def.category);
    final action = _action;
    final run = await V21GameDialog.show<bool>(
      context,
      subtitle: 'EŞYA',
      title: V21Format.upper(def.name),
      icon: V21ItemArt(
        category: def.category,
        tier: v21ItemTier(def.slug),
        size: 84,
        fallbackIcon: icon,
        fallbackColor: color,
      ),
      message: [def.description, ?_extra].join('\n'),
      actions: [
        if (action != null) V21DialogAction(action.$1, tone: V21ButtonTone.green, result: true),
        const V21DialogAction('KAPAT', tone: V21ButtonTone.blue, result: false),
      ],
    );
    if (run == true && action != null) await action.$2();
  }
}

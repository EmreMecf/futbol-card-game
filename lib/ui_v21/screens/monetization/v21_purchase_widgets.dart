import 'package:material_ui/material_ui.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/app_language.dart';
import '../../../features/monetization/purchase/purchase_controller.dart';
import '../../ui_v21.dart';

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
        return Column(
          key: const Key('elmas-paketleri'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                for (final p in c.products)
                  SizedBox(width: 112 * k, child: _PackCard(p: p, c: c, scale: k)),
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

class _PackCard extends StatelessWidget {
  final ShopProduct p;
  final PurchaseController c;
  final double scale;
  const _PackCard({required this.p, required this.c, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final mesgul = c.busyProduct == p.id;
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
          FittedBox(fit: BoxFit.scaleDown, child: Text('${p.paidGems}', style: V21Type.title(22 * k))),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V21Type.label(11 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
          ),
          SizedBox(height: 8 * k),
          V21GameButton(
            key: Key('satin-al-${p.id}'),
            label: p.owned ? 'ALINDI'.tr : p.price!.price,
            tone: p.owned ? V21ButtonTone.purple : V21ButtonTone.green,
            size: V21ButtonSize.small,
            scale: k,
            status: mesgul ? V21ButtonStatus.loading : V21ButtonStatus.normal,
            onPressed: p.purchasable ? () => _onay(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onay(BuildContext context) async {
    var kabul = false;
    final evet = await V21GameDialog.show<bool>(
      context,
      subtitle: 'SATIN AL'.tr,
      title: p.name,
      message: '{gems} elmas · {price}'.trArgs({'gems': p.paidGems, 'price': p.price!.price}),
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
}

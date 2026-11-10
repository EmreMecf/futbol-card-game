import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../chests/presentation/widgets/chest_widgets.dart';
import '../../domain/progress_repository.dart';
import '../viewmodel/progress_view_model.dart';

/// 10 seviye noktası; 5 ve 10 (ustalık eşikleri) altın halkalı
class LevelPips extends StatelessWidget {
  final int level;
  final int max;
  final double size;
  const LevelPips({super.key, required this.level, this.max = 10, this.size = 9});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Seviye $level / $max',
        excludeSemantics: true,
        child: Wrap(spacing: size * 0.35, children: [
          for (var i = 1; i <= max; i++)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= level ? (i >= 5 ? Ref.gold : Ref.accent) : Ref.barTrack,
                border: (i == 5 || i == 10) ? Border.all(color: Ref.gold, width: 1.2) : null,
              ),
            ),
        ]),
      );
}

/// GELİŞİM PANELİ: seviye, kopya ilerlemesi, maliyet, seviye atla /
/// jokerle atla, gönüllü kopya dönüşümü (onaylı, geri alınamaz).
class ProgressPanel extends StatelessWidget {
  final PlayerProgressItem item;
  final ProgressOverview overview;
  final ProgressViewModel vm;

  /// Kart detayında açıklamalar da gösterilir; listede kısa
  final bool detailed;

  const ProgressPanel({super.key, required this.item, required this.overview, required this.vm, this.detailed = true});

  @override
  Widget build(BuildContext context) {
    final coins = overview.coins;
    final next = item.next;
    final mesgul = vm.busyCardId == item.cardId;
    final hazir = item.canLevelUp(coins);
    // Listede jokerle atlama yalnız en az 1 kopyası olanda önerilir
    final jokerle = item.canLevelWithJokers(coins) && (detailed || item.copies > 0);

    return RefCardPanel(children: [
      Row(children: [
        Text('GELİŞİM', style: Ref.caps(Ref.accent)),
        const SizedBox(width: 8),
        // Dar satırda (liste, 320 px) küçülür, taşmaz; sağa yaslı
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text('SEVİYE ${item.level}${item.isMax ? ' · EN YÜKSEK' : ''}',
                maxLines: 1, style: Ref.heading(16, color: item.level >= 5 ? Ref.gold : Ref.text)),
          ),
        ),
      ]),
      LevelPips(level: item.level, max: overview.maxLevel),
      if (next != null) ...[
        Row(children: [
          Expanded(child: RefBar(item.progress, height: 7)),
          const SizedBox(width: 8),
          Text('${item.copies}/${next.copies} kopya', style: Ref.bodyText(11, color: Ref.muted, weight: FontWeight.w700)),
        ]),
        Row(children: [
          const CoinGlyph(size: 14),
          const SizedBox(width: 5),
          Text('${trThousands(next.coins)} altın', style: Ref.bodyText(11.5, color: coins >= next.coins ? Ref.gold : Ref.red, weight: FontWeight.w800)),
          const SizedBox(width: 6),
          const Spacer(),
          if (item.jokersAvailable > 0)
            Flexible(
              flex: 4,
              child: Text('${tierNameTr(item.tier.name)} joker: ${item.jokersAvailable}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ref.tiny(Ref.purple)),
            ),
        ]),
        if (mesgul)
          const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (hazir)
          // Dar liste satırında kısa etiket (320 px'te kesilmesin)
          RefSecondaryButton(detailed ? 'SEVİYE ${item.level + 1}\'E ATLA' : 'SEVİYE ATLA',
              leadingIcon: Icons.arrow_upward_rounded, onTap: () => vm.levelUp(item))
        else if (jokerle)
          RefSecondaryButton(detailed ? 'JOKERLE ATLA (${item.missingCopies} JOKER)' : 'JOKERLE (${item.missingCopies})',
              leadingIcon: Icons.extension_rounded, onTap: () => vm.levelUp(item, useJokers: true))
        else
          Text(
            !item.isOwned
                ? 'Bu futbolcu şu an koleksiyonunda yok; seviyesi korunuyor.'
                : item.missingCopies > 0
                    ? '${item.missingCopies} gelişim kopyası daha gerekli. Kopyalar sandıklardan gelir.'
                    : 'Yeterli altın yok.',
            style: Ref.bodyText(11, color: Ref.muted),
          ),
      ],
      if (vm.actionError != null && vm.busyCardId == null)
        Text(vm.actionError!, style: Ref.bodyText(11.5, color: Ref.red, weight: FontWeight.w700)),
      if (item.convertibleCopies > 0)
        Row(children: [
          Expanded(
            child: Text('${item.convertibleCopies} fazla kopya gelişime çevrilebilir',
                style: Ref.bodyText(11, color: Ref.text, weight: FontWeight.w700)),
          ),
          RefNeutralButton(
            label: 'ÇEVİR',
            onTap: mesgul ? null : () => _donusturOnay(context, item.convertibleCopies),
          ),
        ]),
      if (detailed)
        ChestHint('Seviye dereceli maçta kartın gücünü değiştirmez; ustalık göstergesidir. '
            '5. ve 10. seviyede tek seferlik ustalık ödülü '
            '(${_usta(5)} / ${_usta(10)} altın). Kart kaybedilse de seviye korunur.'),
    ]);
  }

  int _usta(int seviye) => overview.mastery['$seviye']?['coins'] ?? 0;

  Future<void> _donusturOnay(BuildContext context, int adet) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kopyalar gelişime çevrilsin mi?', style: Ref.h3()),
        content: Text(
          '${item.fullName}: $adet fiziksel kopya gelişim kopyasına dönüşecek ve koleksiyonundan çıkacak. '
          'Bu işlem GERİ ALINAMAZ. Koleksiyonunda en az ${overview.convertKeep} kopya kalır; '
          'destedeki ve maçtaki kartlara dokunulmaz.',
          style: Ref.bodyText(13, color: Ref.muted),
        ),
        actions: [
          RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx, false)),
          RefNeutralButton(
            onTap: () => Navigator.pop(ctx, true),
            child: Text('ÇEVİR ($adet)', style: Ref.bodyText(11, color: Ref.gold, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (onay == true) await vm.convert(item, adet);
  }
}

/// Kart detayına giren bölüm: kendi ViewModel'ini kurar. Gelişim
/// servisi kayıtlı değilse (testler) ya da ekonomi kapalıysa görünmez.
class CardProgressSection extends StatelessWidget {
  final String cardId;
  const CardProgressSection({super.key, required this.cardId});

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<ProgressRepository>()) return const SizedBox.shrink();
    return ChangeNotifierProvider<ProgressViewModel>(
      create: (_) => getIt<ProgressViewModel>()..load(),
      child: Consumer<ProgressViewModel>(builder: (context, vm, _) {
        final o = vm.overview;
        final item = o?.item(cardId);
        if (o == null || !o.enabled || item == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ProgressPanel(item: item, overview: o, vm: vm),
        );
      }),
    );
  }
}

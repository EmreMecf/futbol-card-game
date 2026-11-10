import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../viewmodel/chests_view_model.dart';
import '../widgets/chest_widgets.dart';

/// OLASILIKLAR — sunucudaki AKTİF sürümün tabloları (tasarım §1.2-1.3).
/// İstemci hiçbir oranı kendi tutmaz; ne gelirse onu gösterir.
class ChestOddsView extends StatelessWidget {
  const ChestOddsView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ChestsViewModel>(
        create: (_) => getIt<ChestsViewModel>()..loadOdds(),
        child: const AppShell(currentRoute: AppRoutes.home, child: _Govde()),
      );
}

const _sonucAd = {'win': 'Galibiyet', 'draw': 'Beraberlik', 'loss': 'Yenilgi'};
const _nadirlik = ['bronze', 'silver', 'gold', 'diamond', 'legend'];

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final o = context.watch<ChestsViewModel>().odds;
    final turler = o == null
        ? <String>[]
        : (o.types.keys.toList()..sort((a, b) => o.types[a]!.sort.compareTo(o.types[b]!.sort)));

    return ListView(
      padding: Ref.pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                RefNeutralButton(
                  padding: const EdgeInsets.all(7),
                  semanticLabel: 'Geri',
                  onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.chests),
                  child: const Icon(Icons.arrow_back_rounded, size: 16, color: Ref.neutralText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RefSectionHead('OLASILIKLAR', size: 27,
                      kicker: o == null ? 'SANDIK KURALLARI' : 'SANDIK KURALLARI · SÜRÜM ${o.version}'),
                ),
              ]),
              const SizedBox(height: Ref.pageGap),
              if (o == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else ...[
                // ---- Hangi sandık? ----
                RefCardPanel(children: [
                  Text('Maç sonunda hangi sandık?', style: Ref.bodyText(13, weight: FontWeight.w700)),
                  _Tablo(
                    basliklar: ['', for (final t in turler) o.types[t]!.name],
                    renkler: [null, for (final t in turler) chestColor(t)],
                    satirlar: [
                      for (final s in ['win', 'draw', 'loss'])
                        if (o.typeOdds[s] != null)
                          [_sonucAd[s]!, for (final t in turler) o.percent(o.typeOdds[s]![t] ?? 0)],
                    ],
                  ),
                  ChestHint('Şanssızlık koruması: ${o.pity['gold_after'] ?? 15} sandıktır Altın ya da üstü '
                      'gelmediyse sıradaki en az Altın; ${o.pity['legend_after'] ?? 60} sandıktır Efsane gelmediyse '
                      'sıradaki Efsane.'),
                ]),
                for (final t in turler) ...[
                  const SizedBox(height: Ref.pageGap),
                  _TurPaneli(odds: o, type: t),
                ],
                const SizedBox(height: Ref.pageGap),
                RefNote(
                    'Oranlar sunucuda sürümlü tutulur. Her sandık üretildiği sürümün oranlarıyla açılır; '
                    'bir oran değişirse yeni sürüm yayınlanır, eskisi değişmez.'
                    '${o.activeFrom != null ? ' Bu sürüm ${_tarih(o.activeFrom!)} tarihinden beri geçerli.' : ''}',
                    title: 'Sürüm ${o.version}'),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static String _tarih(DateTime d) {
    final y = d.toLocal();
    return '${y.day.toString().padLeft(2, '0')}.${y.month.toString().padLeft(2, '0')}.${y.year}';
  }
}

class _TurPaneli extends StatelessWidget {
  final ChestOdds odds;
  final String type;
  const _TurPaneli({required this.odds, required this.type});

  @override
  Widget build(BuildContext context) {
    final kural = odds.types[type]!;
    final yuvalar = odds.slotOdds[type] ?? const [];
    return RefCardPanel(children: [
      Row(children: [
        ChestIcon(type: type, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${kural.name.toUpperTr()} SANDIK', style: Ref.bodyText(13, color: chestColor(type), weight: FontWeight.w900)),
            Text(
              '${kural.unlockSeconds == 0 ? 'Anında açılır' : 'Kilit: ${chestDuration(Duration(seconds: kural.unlockSeconds))}'}'
              ' · ${kural.coins.first}–${kural.coins.last} altın'
              '${kural.jokers.isEmpty ? '' : ' · Joker: ${jokerSummary(kural.jokers)}'}',
              style: Ref.bodyText(10.5, color: Ref.muted),
            ),
          ]),
        ),
      ]),
      _Tablo(
        basliklar: ['Kart', for (final n in _nadirlik) tierNameTr(n)],
        renkler: [null, for (final n in _nadirlik) _nadirlikRengi(n)],
        satirlar: [
          for (var i = 0; i < yuvalar.length; i++)
            // "★" uygulamanın yazı tiplerinde yok (kutu çizilir): metin
            ['${i + 1}.${i == yuvalar.length - 1 && type != ChestTypes.bronze ? ' garanti' : ''}',
             for (final n in _nadirlik) (yuvalar[i][n] ?? 0) == 0 ? '–' : odds.percent(yuvalar[i][n]!)],
        ],
      ),
      if (type != ChestTypes.bronze) const ChestHint('Garanti yuvası: daha yüksek nadirlik verir.'),
      Text('Yuvalar dolu ve posta kutusu da doluysa: ${kural.compensation} altın telafi.',
          style: Ref.bodyText(10.5, color: Ref.muted)),
    ]);
  }

  static Color _nadirlikRengi(String n) => switch (n) {
        'bronze' => const Color(0xFFBF8766),
        'silver' => const Color(0xFFB8CEDB),
        'gold' => const Color(0xFFF3CE70),
        'diamond' => const Color(0xFF72DFFF),
        _ => const Color(0xFFD18AFF),
      };
}

/// Basit, taşmayan tablo (sütunlar eşit; metin sığmazsa küçülür)
class _Tablo extends StatelessWidget {
  final List<String> basliklar;
  final List<Color?> renkler;
  final List<List<String>> satirlar;
  const _Tablo({required this.basliklar, required this.renkler, required this.satirlar});

  @override
  Widget build(BuildContext context) {
    Widget hucre(String m, {Color? renk, bool kalin = false, bool ilk = false}) => Expanded(
          flex: ilk ? 5 : 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: ilk ? Alignment.centerLeft : Alignment.center,
              child: Text(m, maxLines: 1,
                  style: Ref.bodyText(11, color: renk ?? Ref.text, weight: kalin ? FontWeight.w900 : FontWeight.w600)),
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        for (var i = 0; i < basliklar.length; i++)
          hucre(basliklar[i], renk: renkler[i] ?? Ref.muted, kalin: true, ilk: i == 0),
      ]),
      Container(height: 1, color: Ref.cardPanelBorder),
      for (final s in satirlar)
        Row(children: [for (var i = 0; i < s.length; i++) hucre(s[i], ilk: i == 0, kalin: i == 0)]),
    ]);
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../../features/chests/domain/chest_texts.dart';
import '../../ui_v21.dart';

/// V2.1 SANDIK OLASILIKLARI (HTML referansında karşılığı yok; Sandıklar
/// ekranının dilinden).
///
///   ‹ OLASILIKLAR                                  [SÜRÜM 1]
///   MAÇ SONUNDA HANGİ SANDIK?  Galibiyet/Beraberlik/Yenilgi × tür tablosu
///   şanssızlık koruması
///   her sandık türü: kilit süresi, altın aralığı, joker; kart yuvası ×
///   nadirlik tablosu (son yuva garanti), telafi altını
///
/// VERİ: sunucudaki AKTİF sürümün tabloları (`ChestsViewModel.loadOdds` →
/// `/api/chests/odds`). İstemci hiçbir oranı kendisi tutmaz.
class V21ChestOddsScreen extends StatelessWidget {
  const V21ChestOddsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<ChestsViewModel>(
    create: (_) => getIt<ChestsViewModel>()..loadOdds(),
    child: const _Body(),
  );
}

const _outcomes = {'win': 'Galibiyet', 'draw': 'Beraberlik', 'loss': 'Yenilgi'};
const _tiers = ['bronze', 'silver', 'gold', 'diamond', 'legend'];
const _tierColor = {
  'bronze': Color(0xFFFFAB76),
  'silver': Color(0xFFE8EEF6),
  'gold': Color(0xFFFFE07A),
  'diamond': Color(0xFF7FF3FF),
  'legend': Color(0xFFE3A9FA),
};
const _tierShort = {'bronze': 'BRZ', 'silver': 'GMŞ', 'gold': 'ALT', 'diamond': 'ELM', 'legend': 'EFS'};

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChestsViewModel>();
    final o = vm.odds;
    return V21InnerPage(
      title: 'OLASILIKLAR',
      route: AppRoutes.chestOdds,
      highlightRoute: AppRoutes.home,
      fallbackRoute: AppRoutes.chests,
      state: o == null ? (vm.hasError ? V21PageState.error : V21PageState.loading) : V21PageState.ready,
      errorMessage: vm.errorMessage,
      onRetry: () => vm.loadOdds(),
      trailing: o == null
          ? null
          : (context, k) => V21Tag(
              text: 'SÜRÜM ${o.version}',
              background: V21Colors.panel,
              foreground: V21Colors.textMuted,
              scale: k,
              fontSize: 13,
            ),
      children: (context, k) {
        final odds = o!;
        final types = odds.types.keys.toList()..sort((a, b) => odds.types[a]!.sort.compareTo(odds.types[b]!.sort));
        return [
          V21SectionTitle('MAÇ SONUNDA HANGİ SANDIK?', scale: k),
          V21GamePanel(
            scale: k,
            radius: 16,
            padding: EdgeInsets.all(12 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Table(
                  header: ['', for (final t in types) V21Format.upper(odds.types[t]!.name)],
                  headerColors: [null, for (final t in types) _tierColor[t]],
                  rows: [
                    for (final s in ['win', 'draw', 'loss'])
                      if (odds.typeOdds[s] != null)
                        [_outcomes[s]!, for (final t in types) odds.percent(odds.typeOdds[s]![t] ?? 0)],
                  ],
                  scale: k,
                ),
                SizedBox(height: 8 * k),
                Text(
                  'Şanssızlık koruması: ${odds.pity['gold_after'] ?? 15} sandıktır Altın ya da üstü gelmediyse sıradaki '
                  'en az Altın; ${odds.pity['legend_after'] ?? 60} sandıktır Efsane gelmediyse sıradaki Efsane.',
                  style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          for (final t in types) ...[SizedBox(height: 14 * k), _TypePanel(odds: odds, type: t, scale: k)],
          SizedBox(height: 14 * k),
          Text(
            'Oranlar sunucuda sürümlü tutulur. Her sandık üretildiği sürümün oranlarıyla açılır; bir oran değişirse '
            'yeni sürüm yayınlanır, eskisi değişmez.'
            '${odds.activeFrom != null ? ' Bu sürüm ${_date(odds.activeFrom!)} tarihinden beri geçerli.' : ''}',
            textAlign: TextAlign.center,
            style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textDim, height: 1.4),
          ),
        ];
      },
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
  }
}

class _TypePanel extends StatelessWidget {
  final ChestOdds odds;
  final String type;
  final double scale;
  const _TypePanel({required this.odds, required this.type, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final rule = odds.types[type]!;
    final slots = odds.slotOdds[type] ?? const [];
    return V21GamePanel(
      scale: k,
      radius: 16,
      padding: EdgeInsets.all(12 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              V21ChestArt(width: 64 * k),
              SizedBox(width: 10 * k),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${V21Format.upper(rule.name)} SANDIK',
                      style: V21Type.title(20 * k, color: _tierColor[type] ?? Colors.white),
                    ),
                    Text(
                      '${rule.unlockSeconds == 0 ? 'Anında açılır' : 'Kilit: ${V21Format.shortDuration(rule.unlockSeconds)}'}'
                      ' · ${rule.coins.first}–${rule.coins.last} altın'
                      '${rule.jokers.isEmpty ? '' : ' · Joker: ${jokerSummary(rule.jokers)}'}',
                      style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * k),
          _Table(
            header: ['KART', for (final n in _tiers) _tierShort[n]!],
            headerColors: [null, for (final n in _tiers) _tierColor[n]],
            rows: [
              for (var i = 0; i < slots.length; i++)
                [
                  '${i + 1}.${i == slots.length - 1 && type != ChestTypes.bronze ? ' garanti' : ''}',
                  for (final n in _tiers) (slots[i][n] ?? 0) == 0 ? '–' : odds.percent(slots[i][n]!),
                ],
            ],
            scale: k,
          ),
          SizedBox(height: 6 * k),
          Text(
            '${type != ChestTypes.bronze ? 'Garanti yuvası daha yüksek nadirlik verir. ' : ''}'
            'Yuvalar ve posta kutusu doluysa: ${rule.compensation} altın telafi.',
            style: V21Type.label(11 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Eşit sütunlu, taşmayan tablo (sığmayan metin küçülür)
class _Table extends StatelessWidget {
  final List<String> header;
  final List<Color?> headerColors;
  final List<List<String>> rows;
  final double scale;
  const _Table({required this.header, required this.headerColors, required this.rows, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    Widget cell(String t, {Color? color, bool bold = false, bool first = false}) => Expanded(
      flex: first ? 6 : 4,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6 * k, horizontal: 2 * k),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: first ? Alignment.centerLeft : Alignment.center,
          child: Text(
            t,
            maxLines: 1,
            style: bold
                ? V21Type.title(15 * k, color: color ?? Colors.white)
                : V21Type.label(13 * k, weight: FontWeight.w700, color: color ?? Colors.white),
          ),
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < header.length; i++)
              cell(header[i], color: headerColors[i] ?? V21Colors.textMuted, bold: true, first: i == 0),
          ],
        ),
        Container(height: 2 * k, color: const Color(0x557B56C9)),
        for (var r = 0; r < rows.length; r++)
          Container(
            color: r.isOdd ? const Color(0x22120933) : null,
            child: Row(
              children: [for (var i = 0; i < rows[r].length; i++) cell(rows[r][i], bold: i == 0, first: i == 0)],
            ),
          ),
      ],
    );
  }
}

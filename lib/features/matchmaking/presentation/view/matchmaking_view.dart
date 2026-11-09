import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../match/presentation/arena/ref_stadium.dart';
import '../viewmodel/matchmaking_view_model.dart';

/// MAÇ HAZIRLIĞI — alt menüdeki "Arena" sekmesi.
///
/// Referansta ayrı bir hazırlık ekranı yok; referans arena ekranının
/// dili kullanıldı: "⚔ DERECELİ KARŞILAŞMA" başlığı, .arena-stage
/// stadyumu, .card-panel, ortak kart ızgarası ve altın .cta.
///
/// Oyun mantığı MatchmakingViewModel'de, DEĞİŞMEDİ: kadro doğrulama,
/// kart koruma (kaybedilirse korunmayan kartlardan 3'ü rakibe geçer),
/// arama, iptal, eşleşince maça geçiş.
class MatchmakingView extends StatelessWidget {
  const MatchmakingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchmakingViewModel>(
      create: (_) => getIt<MatchmakingViewModel>()..initialize(),
      child: const _Govde(),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchmakingViewModel>();

    final macId = vm.foundMatchId;
    if (macId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        vm.consumeFoundMatch();
        context.pushReplacement(AppRoutes.matchWithId(macId));
      });
    }

    final ariyor = vm.stage == MatchmakingStage.searching;
    return PopScope(
      canPop: !ariyor,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) vm.cancelSearch();
      },
      // Arama sürerken başka sekmeye geçilmesin (kuyrukta unutulmasın):
      // gezinme gizlenir, çıkış "ARAMAYI İPTAL ET" ile.
      child: AppShell(
        currentRoute: AppRoutes.matchmaking,
        showNavigation: !ariyor,
        child: LayoutBuilder(
          builder: (context, k) {
            return ListView(
              padding: Ref.pagePadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: k.maxWidth >= 900 ? 900 : 620),
                    child: RefPageEnter(
                      child: vm.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator(color: Ref.accent)),
                            )
                          : (ariyor ? _Arama(viewModel: vm) : _Hazirlik(viewModel: vm)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Widget _baslik(String baslik, Widget? sag) => Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RefGlyphIcon(RefGlyph.swords, size: 10, color: Ref.accent),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('DERECELİ KARŞILAŞMA', maxLines: 1, style: Ref.caps(Ref.accent)),
                ),
              ),
            ],
          ),
          Text(baslik, style: Ref.h2()),
        ],
      ),
    ),
    ?sag,
  ],
);

// ====================================================================
// HAZIRLIK
// ====================================================================
class _Hazirlik extends StatelessWidget {
  final MatchmakingViewModel viewModel;
  const _Hazirlik({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final dogrulama = vm.validation;
    final gecerli = dogrulama?.isValid ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik('MAÇA HAZIRLAN', RefPill('KORUMA ${vm.protectedCardIds.length}/${vm.maxProtection}')),
        const SizedBox(height: Ref.pageGap),
        RefArenaStage(stadium: RefStadium(caption: gecerli ? 'KADRO HAZIR!' : 'KADRO EKSİK', height: 200)),
        const SizedBox(height: Ref.pageGap),
        // Kadro durumu
        RefCardPanel(
          children: [
            Row(
              children: [
                Em(gecerli ? '✅' : '⚠️', size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dogrulama?.displayMessage ?? 'Kadro kontrol ediliyor...',
                    style: Ref.bodyText(12, weight: FontWeight.w700, color: gecerli ? Ref.text : Ref.red),
                  ),
                ),
              ],
            ),
            if (!gecerli && dogrulama != null)
              RefNeutralButton(label: 'KADROYU DÜZENLE', onTap: () => context.go(AppRoutes.deck)),
          ],
        ),
        const SizedBox(height: Ref.pageGap),
        RefSectionHead(
          'KARTLARINI KORU',
          trailing: RefNeutralButton(label: 'En iyileri koru', onTap: vm.autoProtectBest),
        ),
        const SizedBox(height: 6),
        Text(
          'Maçı kaybedersen korumaya ALMADIĞIN kartlardan 3 tanesi rastgele seçilip kalıcı olarak '
          'rakibe geçer. Her galibiyette 1 koruma hakkı kazanırsın.',
          style: Ref.bodyText(11, color: Ref.muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (vm.deckCards.isEmpty)
          Text('Kadronda kart yok.', style: Ref.bodyText(13, color: Ref.muted))
        else
          LayoutBuilder(
            builder: (context, k) {
              final sutun = k.maxWidth < 360 ? 3 : (k.maxWidth / 120).floor().clamp(3, 6);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: sutun,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: RefCardLayout.grid.aspectRatio,
                ),
                itemCount: vm.deckCards.length,
                itemBuilder: (context, i) {
                  final kart = vm.deckCards[i];
                  final korunuyor = vm.isProtected(kart.userCardId);
                  return LayoutBuilder(
                    builder: (context, kk) => RefPlayerCard(
                      key: ValueKey(kart.userCardId),
                      name: kart.fullName,
                      position: kart.position,
                      tier: kart.tier,
                      power: kart.power,
                      seed: kart.cardId,
                      kitSeed: kart.club ?? kart.nationality,
                      imageUrl: kart.imageUrl,
                      width: kk.maxWidth,
                      isProtected: korunuyor,
                      isSelected: korunuyor,
                      onTap: () {
                        if (!korunuyor && !vm.canProtectMore) {
                          AppSnackBar.showInfo(context, 'Koruma hakkın doldu. Her galibiyette 1 hak kazanırsın.');
                          return;
                        }
                        vm.toggleProtection(kart.userCardId);
                      },
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: Ref.pageGap),
        RefCta(
          'RAKİP BUL',
          leading: RefGlyph.swords,
          trailing: RefGlyph.play,
          onTap: vm.canSearch ? vm.startSearch : null,
        ),
      ],
    );
  }
}

// ====================================================================
// ARAMA
// ====================================================================
class _Arama extends StatelessWidget {
  final MatchmakingViewModel viewModel;
  const _Arama({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final sure = viewModel.searchDuration;
    final dk = sure.inMinutes.toString().padLeft(2, '0');
    final sn = (sure.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik('RAKİP ARANIYOR', RefPill(' $dk:$sn', dot: true)),
        const SizedBox(height: Ref.pageGap),
        const RefArenaStage(stadium: RefStadium(caption: 'RAKİP ARANIYOR...', height: 230)),
        const SizedBox(height: Ref.pageGap),
        RefCardPanel(
          children: [
            Text('Yakın puanlı bir rakip bekleniyor.', style: Ref.bodyText(12, weight: FontWeight.w700)),
            Text(
              'Bekleme süresi uzadıkça puan aralığı genişler, böylece daha hızlı eşleşirsin.',
              style: Ref.bodyText(11, color: Ref.muted, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: RefPill('${viewModel.protectedCardIds.length} kart korumada', emoji: '🛡️'),
            ),
          ],
        ),
        const SizedBox(height: Ref.pageGap),
        RefNeutralButton(label: 'ARAMAYI İPTAL ET', onTap: viewModel.cancelSearch),
      ],
    );
  }
}

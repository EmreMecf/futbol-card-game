import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/ref_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../../../shared/widgets/avatar2d/avatar_spec.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';
import '../../../../shared/widgets/ref_card/ref_player_card.dart';
import '../../../items/cosmetics/equipped_cosmetics.dart';
import '../arena/ref_stadium.dart';
import '../arena/stage2d/duel_stage.dart';
import '../viewmodel/match_view_model.dart';
import '../widgets/match_result_view.dart';
import '../widgets/tactic_widgets.dart';

/// MAÇ — referans `arena()` ekranı ("CANLI ARENA").
///
///   başlık        ⚔ DERECELİ KARŞILAŞMA / CANLI ARENA · süre · TUR n/11
///   .arena-stage  SEN · skor · RAKİP + perspektifli stadyum
///   .vs-row       SENİN KARTIN  VS  RAKİP KARTI
///   el            elindeki kartlar (referansta yok; oyunda gerçek)
///   enerji        TAKTİK ENERJİSİ ⚡ e/max + çubuk
///   .tactics      Yüksek Pres · Kontra Atak · Savunma Duvarı
///   .matchlog     durum satırı
///   .battle-actions  TAKTİĞİ SIFIRLA · KARTI OYNA
///
/// SEÇ, SONRA OYNA: kart dokununca seçilir (hafifçe büyür, SENİN KARTIN
/// panelinde gerçek gücü görünür), ayrı düğmeyle oynanır. Hamle geri
/// alınamaz.
///
/// TUR SONUCU: sunucu turu çözünce kart sahaya uçar, 2D karakterler
/// mevkiye göre kısa düello oynar (DuelStage). SONUCU SUNUCU BELİRLER;
/// animasyon yalnızca gösterir, dokununca atlanır.
class MatchView extends StatelessWidget {
  final String matchId;

  const MatchView({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchViewModel>(
      create: (_) => getIt<MatchViewModel>(param1: matchId)..initialize(),
      child: const _MatchBody(),
    );
  }
}

class _MatchBody extends StatefulWidget {
  const _MatchBody();

  @override
  State<_MatchBody> createState() => _MatchBodyState();
}

class _MatchBodyState extends State<_MatchBody> {
  String? _gosterilenHata;
  String? _seciliKartId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchViewModel>();

    final hata = vm.errorMessage;
    if (hata != null && hata != _gosterilenHata) {
      _gosterilenHata = hata;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.showError(context, hata);
        vm.clearError();
        _gosterilenHata = null;
      });
    }

    // Rakibin süresi dolduysa maçı hükmen talep et
    if (vm.canClaimTimeout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) vm.claimTimeout();
      });
    }

    if (vm.isLoading && vm.matchState == null) {
      return const Scaffold(
        backgroundColor: Ref.phoneBg,
        body: Center(child: CircularProgressIndicator(color: Ref.accent)),
      );
    }
    if (vm.matchState == null) return _HataEkrani(viewModel: vm);

    // Maç bittiyse sonuç — ama son turun sahnesi oynadıktan sonra
    if (vm.isOver && vm.currentClash == null) {
      return MatchResultView(
        result: vm.result,
        rewardDelta: vm.rewardDelta,
        onClose: () => context.go(AppRoutes.home),
        onNewMatch: () => context.go(AppRoutes.matchmaking),
      );
    }

    return PopScope(
      // Maçtan kaçış yok: geri tuşu teslim olma onayı sorar
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _teslimOnayi(context, vm);
      },
      child: Scaffold(
        backgroundColor: Ref.phoneBg,
        body: Stack(
          children: [
            Column(
              children: [
                const RefPhoneHeader(currentRoute: AppRoutes.match, locked: true),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, k) {
                      final genis = k.maxWidth >= 900;
                      return ListView(
                        padding: Ref.pagePadding,
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: genis ? 1180 : 620),
                              child: genis ? _genis(vm) : _dar(vm),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            _CatismaKatmani(viewModel: vm),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // YERLEŞİMLER
  // ------------------------------------------------------------------
  Widget _dar(MatchViewModel vm) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Baslik(viewModel: vm),
      const SizedBox(height: Ref.pageGap),
      _ArenaPaneli(viewModel: vm),
      const SizedBox(height: Ref.pageGap),
      _VsSatiri(viewModel: vm, secili: seciliKart(vm)),
      const SizedBox(height: Ref.pageGap),
      _El(state: this, viewModel: vm),
      if (vm.tacticsEnabled) ...[
        const SizedBox(height: Ref.pageGap),
        _Enerji(viewModel: vm),
        const SizedBox(height: Ref.pageGap),
        _Taktikler(viewModel: vm),
      ],
      const SizedBox(height: Ref.pageGap),
      _DurumSatiri(viewModel: vm, secili: seciliKart(vm)),
      const SizedBox(height: Ref.pageGap),
      _Aksiyonlar(state: this, viewModel: vm),
      const SizedBox(height: Ref.pageGap),
      _AltNot(state: this, viewModel: vm),
    ],
  );

  Widget _genis(MatchViewModel vm) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Baslik(viewModel: vm),
      const SizedBox(height: Ref.pageGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArenaPaneli(viewModel: vm, stadiumHeight: 300),
                const SizedBox(height: Ref.pageGap),
                _VsSatiri(viewModel: vm, secili: seciliKart(vm)),
                const SizedBox(height: Ref.pageGap),
                _El(state: this, viewModel: vm),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vm.tacticsEnabled) ...[
                  _Enerji(viewModel: vm),
                  const SizedBox(height: Ref.pageGap),
                  _Taktikler(viewModel: vm),
                  const SizedBox(height: Ref.pageGap),
                ],
                _DurumSatiri(viewModel: vm, secili: seciliKart(vm)),
                const SizedBox(height: Ref.pageGap),
                _Aksiyonlar(state: this, viewModel: vm),
                const SizedBox(height: Ref.pageGap),
                _AltNot(state: this, viewModel: vm),
                const SizedBox(height: Ref.pageGap),
                _TurGecmisi(viewModel: vm),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  // ------------------------------------------------------------------
  // SEÇİM VE HAMLE
  // ------------------------------------------------------------------
  HandCard? seciliKart(MatchViewModel vm) {
    final id = _seciliKartId;
    if (id == null) return null;
    for (final k in vm.playableCards) {
      if (k.userCardId == id) return k;
    }
    return null;
  }

  void kartSec(HandCard kart) {
    if (_seciliKartId != kart.userCardId) GameFeedback.haptic(HapticStrength.selection);
    setState(() => _seciliKartId = kart.userCardId);
  }

  Future<void> seciliyiOyna(MatchViewModel vm) async {
    final kart = seciliKart(vm);
    if (kart == null) return;
    final ok = await vm.playCard(kart);
    if (ok && mounted) setState(() => _seciliKartId = null);
  }

  Future<void> _teslimOnayi(BuildContext context, MatchViewModel vm) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ref.modalBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
          side: const BorderSide(color: Ref.modalBorder),
        ),
        title: Text('Teslim olmak istiyor musun?', style: Ref.h3()),
        content: Text(
          'Teslim olursan maçı kaybetmiş sayılırsın ve korumaya almadığın '
          '${GameRules.penaltyCardCount} kartın kalıcı olarak rakibe geçer.',
          style: Ref.bodyText(13, color: Ref.muted),
        ),
        actions: [
          RefNeutralButton(label: 'VAZGEÇ', onTap: () => Navigator.pop(ctx, false)),
          RefNeutralButton(
            onTap: () => Navigator.pop(ctx, true),
            child: Text(
              'TESLİM OL',
              style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (onay == true) await vm.surrender();
  }

  void teslimOnayiAc(BuildContext context, MatchViewModel vm) => _teslimOnayi(context, vm);
}

/// Bir kartın 2D yüzü (koleksiyondaki yüzün aynısı: cardId + kulüp)
AvatarSpec _yuz(String seed, String? kulup) => AvatarSpec.generate(seed, kitSeed: kulup);

/// Masadaki bir hamlenin 2D yüzü — koleksiyondaki kartla AYNI kimlik:
/// tohum = kartın katalog kimliği (cardId), forma = kulüp ?? uyruk.
/// Sunucu kimliği göndermiyorsa (eski sürüm) eldeki karttan, o da
/// yoksa ada düşülür.
(String, String?) _hamleKimligi(MatchMove m, HandCard? elde) => (
      m.cardId ?? elde?.cardId ?? m.fullName ?? '?',
      m.kitSeed ?? elde?.club ?? elde?.nationality,
    );

// ====================================================================
// BAŞLIK
// ====================================================================
class _Baslik extends StatelessWidget {
  final MatchViewModel viewModel;
  const _Baslik({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final d = viewModel.matchState!;
    final sn = viewModel.remainingSeconds;
    final acil = viewModel.isTimeRunningOut && GameFeedback.turnWarningEnabled;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              Text('CANLI ARENA', style: Ref.h2()),
            ],
          ),
        ),
        // Hamle süresi (oyunda gerçek; referansta yok)
        Semantics(
          label: 'Kalan süre $sn saniye',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: acil ? const Color(0x33F26479) : Ref.pillBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: acil ? Ref.red : Ref.pillBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 12, color: acil ? Ref.red : Ref.pillText),
                const SizedBox(width: 3),
                Text(
                  '$sn SN',
                  style: Ref.bodyText(10, color: acil ? Ref.red : Ref.pillText, weight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        RefPill('TUR ${d.roundNumber}/${GameRules.squadSize}'),
      ],
    );
  }
}

// ====================================================================
// ARENA PANELİ (.arena-stage)
// ====================================================================
class _ArenaPaneli extends StatelessWidget {
  final MatchViewModel viewModel;
  final double stadiumHeight;
  const _ArenaPaneli({required this.viewModel, this.stadiumHeight = 230});

  @override
  Widget build(BuildContext context) {
    final d = viewModel.matchState!;
    final masada = viewModel.myTableMove != null || viewModel.opponentTableMove != null;
    final String yazi;
    if (d.roundNumber == 1 && !masada) {
      yazi = 'İLK DÜDÜK!';
    } else if (masada) {
      yazi = 'KARTLAR SAHADA!';
    } else if (viewModel.isMyTurn) {
      yazi = 'SIRA SENDE!';
    } else {
      yazi = 'RAKİP DÜŞÜNÜYOR';
    }
    return RefArenaStage(
      head: RefArenaHead(
        myName: viewModel.myUsername ?? 'Sen',
        opponentName: d.opponent?.username ?? 'Rakip',
        myScore: d.myScore,
        opponentScore: d.opponentScore,
      ),
      stadium: RefStadium(
        caption: yazi,
        height: stadiumHeight,
        // Yeni bir tur çözüldüğünde şut + saha parlaması
        flashKey: viewModel.lastResolvedRound?.roundNumber,
        skin: EquippedCosmetics.current?.arena,
      ),
    );
  }
}

// ====================================================================
// .vs-row
// ====================================================================
class _VsSatiri extends StatelessWidget {
  final MatchViewModel viewModel;
  final HandCard? secili;
  const _VsSatiri({required this.viewModel, required this.secili});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final benimHamle = vm.myTableMove;
    final rakipHamle = vm.opponentTableMove;

    _SavasIcerigi? benim;
    if (benimHamle != null && !benimHamle.isPass) {
      final elde = vm.hand.where((k) => k.userCardId == benimHamle.userCardId).firstOrNull;
      benim = _SavasIcerigi(
        yuz: () {
          final (seed, kit) = _hamleKimligi(benimHamle, elde);
          return _yuz(seed, kit);
        }(),
        guc: benimHamle.effectivePower ?? 0,
        ad: benimHamle.fullName ?? '',
        kimya: benimHamle.chemistry,
        hamle: benimHamle,
      );
    } else if (secili != null) {
      benim = _SavasIcerigi(
        yuz: _yuz(secili!.cardId, secili!.club ?? secili!.nationality),
        guc: secili!.effectivePower,
        ad: secili!.fullName,
        kimya: secili!.chemistry,
      );
    }

    _SavasIcerigi? rakip;
    if (rakipHamle != null && !rakipHamle.isPass) {
      rakip = _SavasIcerigi(
        yuz: () {
          final (seed, kit) = _hamleKimligi(rakipHamle, null);
          return _yuz(seed, kit);
        }(),
        guc: rakipHamle.effectivePower ?? 0,
        ad: rakipHamle.fullName ?? '',
        kimya: rakipHamle.chemistry,
        hamle: rakipHamle,
      );
    }

    final zorunlu = vm.requiredPosition;
    final benimBos = !vm.isMyTurn
        ? 'Sıra rakipte'
        : vm.mustPass
        ? 'Bu mevkide kartın yok'
        : zorunlu != null
        ? '${zorunlu.label} kartı seç'
        : 'Elinden bir kart seç';

    // .vs-row { grid-template-columns:1fr 24px 1fr; gap:5px }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SavasKarti(
              baslik: 'SENİN KARTIN',
              rakip: false,
              icerik: benim,
              bosMetin: benimBos,
              secimOnizlemesi: benimHamle == null && secili != null,
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 24,
            child: Center(
              child: Text('VS', style: Ref.heading(24, color: Ref.gold)),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _SavasKarti(
              baslik: 'RAKİP KARTI',
              rakip: true,
              icerik: rakip,
              bosMetin: vm.isMyTurn && zorunlu == null ? 'Turu sen açıyorsun' : 'Bekleniyor',
            ),
          ),
        ],
      ),
    );
  }
}

class _SavasIcerigi {
  final AvatarSpec yuz;
  final int guc;
  final String ad;
  final int kimya;
  final MatchMove? hamle;
  const _SavasIcerigi({required this.yuz, required this.guc, required this.ad, required this.kimya, this.hamle});
}

/// .battle-card { background:linear-gradient(145deg,#173b62,#101a32);
///   border:2px solid #44b5ff; border-radius:12px; min-height:117px; gap:3px;
///   box-shadow:inset 0 0 35px #347cff2a, 0 0 17px #1f7dca33 }
/// .enemy { linear-gradient(145deg,#57304b,#1f1628); border-color:#ee6373 }
/// .big { 900 35px Barlow } .face { 30px } .name { 11px 900 } .plus { 9px #7effca }
class _SavasKarti extends StatelessWidget {
  final String baslik;
  final bool rakip;
  final _SavasIcerigi? icerik;
  final String bosMetin;
  final bool secimOnizlemesi;

  const _SavasKarti({
    required this.baslik,
    required this.rakip,
    required this.icerik,
    required this.bosMetin,
    this.secimOnizlemesi = false,
  });

  @override
  Widget build(BuildContext context) {
    final i = icerik;
    final cerceve = rakip ? const Color(0xFFEE6373) : const Color(0xFF44B5FF);
    return AnimatedContainer(
      duration: Ref.cardHover,
      constraints: const BoxConstraints(minHeight: 117),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cerceve, width: 2),
        gradient: LinearGradient(
          begin: const Alignment(-0.57, -0.82),
          end: const Alignment(0.57, 0.82),
          colors: rakip ? const [Color(0xFF57304B), Color(0xFF1F1628)] : const [Color(0xFF173B62), Color(0xFF101A32)],
        ),
        boxShadow: [BoxShadow(color: rakip ? const Color(0x33CA1F55) : const Color(0x331F7DCA), blurRadius: 17)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(baslik, style: Ref.caps(rakip ? Ref.red : Ref.accent)),
          const SizedBox(height: 3),
          if (i == null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cerceve.withValues(alpha: 0.6)),
              ),
              child: Text('?', style: Ref.heading(20, color: cerceve)),
            ),
            const SizedBox(height: 4),
            Text(
              bosMetin,
              textAlign: TextAlign.center,
              style: Ref.bodyText(10, color: Ref.muted, weight: FontWeight.w800),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(child: AvatarPortrait(spec: i.yuz, size: 34, headshot: true)),
                const SizedBox(width: 6),
                Text('${i.guc}', style: Ref.heading(35, weight: FontWeight.w900, height: 1.1)),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(i.ad, maxLines: 1, style: Ref.bodyText(11, weight: FontWeight.w900)),
            ),
            Text(
              '+${i.kimya} kimya${secimOnizlemesi ? ' · seçili' : ''}',
              style: Ref.bodyText(9, color: rakip ? const Color(0xFFF8A3B2) : const Color(0xFF7EFFCA)),
            ),
            if (i.hamle != null) ...[const SizedBox(height: 3), TacticBadge(move: i.hamle!, resolved: false)],
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// ELİNDEKİ KARTLAR
// ====================================================================
class _El extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;
  const _El({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final kartlar = vm.hand.where((k) => !k.isPlayed).toList();
    if (kartlar.isEmpty) return const SizedBox.shrink();
    final zorunlu = vm.requiredPosition;
    final secili = state.seciliKart(vm);
    const genislik = 92.0;
    final yukseklik = genislik / RefCardLayout.grid.aspectRatio;
    final pot = vm.matchState!.potCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('ELİNDEKİ KARTLAR', style: Ref.caps())),
            if (pot > 0) ...[RefPill('Masada $pot kart', emoji: '🃏'), const SizedBox(width: 6)],
            Text('${kartlar.length} KART', style: Ref.caps(Ref.muted)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          // Seçili kart büyüdüğünde kesilmesin diye pay
          height: yukseklik + 14,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            itemCount: kartlar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final k = kartlar[i];
              final oynanabilir = zorunlu == null || k.position == zorunlu;
              final etkin = vm.isMyTurn && oynanabilir && !vm.isSubmittingMove && vm.myTableMove == null;
              final seciliMi = secili?.userCardId == k.userCardId;
              // Kart seçimi: 200-300 ms hafif büyüme
              return AnimatedScale(
                key: ValueKey('el-${k.userCardId}'),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                scale: seciliMi ? 1.08 : 1,
                child: Opacity(
                  opacity: oynanabilir ? 1 : 0.45,
                  child: RefPlayerCard(
                    name: k.fullName,
                    skin: EquippedCosmetics.current?.cardSkin,
                    position: k.position,
                    tier: k.tier,
                    power: k.effectivePower,
                    seed: k.cardId,
                    kitSeed: k.club ?? k.nationality,
                    imageUrl: k.imageUrl,
                    width: genislik,
                    isProtected: k.isProtected,
                    isSelected: seciliMi,
                    onTap: etkin ? () => state.kartSec(k) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// ENERJİ
// ====================================================================
class _Enerji extends StatelessWidget {
  final MatchViewModel viewModel;
  const _Enerji({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final e = viewModel.myEnergy;
    final m = viewModel.maxEnergy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('TAKTİK ENERJİSİ', style: Ref.caps())),
            // .energy-meter { color:#47eebd; font-weight:900 }
            Text(
              '⚡ $e/$m',
              style: Ref.bodyText(14, color: const Color(0xFF47EEBD), weight: FontWeight.w900),
              semanticsLabel: 'Enerji $e / $m',
            ),
          ],
        ),
        const SizedBox(height: 8),
        // .energy-track { height:9px; background:#233850; border-radius:20px }
        // span { linear-gradient(90deg,#07b4cf,#38f2ee); transition:.3s }
        RefBar(
          m == 0 ? 0 : e / m,
          height: 9,
          track: const Color(0xFF233850),
          gradient: const LinearGradient(colors: [Color(0xFF07B4CF), Color(0xFF38F2EE)]),
        ),
      ],
    );
  }
}

// ====================================================================
// TAKTİKLER (.tactics) — 021_tactics.sql
// ====================================================================
class _Taktikler extends StatelessWidget {
  final MatchViewModel viewModel;
  const _Taktikler({required this.viewModel});

  static String emoji(MatchTactic t) => switch (t) {
    MatchTactic.highPress => '🛡️',
    MatchTactic.counterAttack => '⚡',
    MatchTactic.defensiveWall => '🧱',
    MatchTactic.none => '',
  };

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final kilitli = vm.isSubmittingMove || vm.myTableMove != null;
    return Row(
      children: [
        for (var i = 0; i < MatchTactic.playable.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _TaktikKarosu(
              taktik: MatchTactic.playable[i],
              secili: vm.selectedTactic == MatchTactic.playable[i],
              etkin: !kilitli && vm.canUseTactic(MatchTactic.playable[i]),
              onTap: () => vm.selectTactic(MatchTactic.playable[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// .tactic { background:linear-gradient(155deg,#182942,#0e1b30); border:1px solid #46637e;
///   border-radius:11px; min-height:88px; padding:8px 5px; gap:4px }
/// .ti 26px · b 10px · small 9px #8ddac9
/// .chosen { linear-gradient(155deg,#11543d,#103027); border-color:accent; box-shadow:0 0 16px #1ddd9955 }
class _TaktikKarosu extends StatelessWidget {
  final MatchTactic taktik;
  final bool secili;
  final bool etkin;
  final VoidCallback onTap;

  const _TaktikKarosu({required this.taktik, required this.secili, required this.etkin, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: taktik.hint,
    child: Semantics(
      button: true,
      selected: secili,
      enabled: etkin,
      label: '${taktik.label}, ${taktik.cost} enerji. ${taktik.hint}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: etkin ? onTap : null,
        child: Opacity(
          opacity: etkin || secili ? 1 : 0.42,
          child: AnimatedContainer(
            duration: Ref.cardHover,
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: secili ? Ref.accent : const Color(0xFF46637E)),
              gradient: LinearGradient(
                begin: const Alignment(-0.42, -0.9),
                end: const Alignment(0.42, 0.9),
                colors: secili
                    ? const [Color(0xFF11543D), Color(0xFF103027)]
                    : const [Color(0xFF182942), Color(0xFF0E1B30)],
              ),
              boxShadow: secili ? const [BoxShadow(color: Color(0x551DDD99), blurRadius: 16)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Em(_Taktikler.emoji(taktik), size: 26, height: 1.15),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    taktik.label,
                    maxLines: 1,
                    style: Ref.bodyText(10, color: const Color(0xFFDAE9FA), weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Text('⚡ ${taktik.cost} enerji', style: Ref.bodyText(9, color: const Color(0xFF8DDAC9))),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ====================================================================
// DURUM SATIRI (.matchlog)
// ====================================================================
class _DurumSatiri extends StatelessWidget {
  final MatchViewModel viewModel;
  final HandCard? secili;
  const _DurumSatiri({required this.viewModel, required this.secili});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final zorunlu = vm.requiredPosition;
    final tur = vm.lastResolvedRound;
    String metin;
    if (vm.mustPass && vm.isMyTurn) {
      metin = 'Bu mevkide kartın yok: pas geçmek zorundasın (tur rakibe yazılır).';
    } else if (!vm.isMyTurn) {
      metin = 'Rakip düşünüyor...';
    } else if (!vm.selectedTactic.isNone) {
      metin = '${vm.selectedTactic.label}: ${vm.selectedTactic.hint}';
    } else if (secili != null) {
      metin =
          '${secili!.fullName}: ${secili!.power}'
          '${secili!.hasChemistry ? ' + ${secili!.chemistry} kimya = ${secili!.effectivePower}' : ''}. '
          'Taktik seçip kartı oynayabilirsin.';
    } else if (zorunlu != null) {
      metin = 'Rakip ${zorunlu.label.toLowerCase()} açtı: ${zorunlu.label.toLowerCase()} kartı oynamalısın.';
    } else {
      metin = 'Taktik seçip kart oynayabilirsin.';
    }
    if (tur != null && vm.isMyTurn && secili == null && vm.selectedTactic.isNone) {
      final sonuc = tur.isDraw
          ? 'berabere'
          : tur.winnerId == vm.myUserId
          ? 'senin'
          : 'rakibin';
      metin = 'Son tur $sonuc. $metin';
    }
    // .matchlog { font-size:10px; color:#afc6dc; min-height:28px; text-align:center }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Center(
        child: Text(
          metin,
          textAlign: TextAlign.center,
          style: Ref.bodyText(10, color: const Color(0xFFAFC6DC)),
        ),
      ),
    );
  }
}

// ====================================================================
// .battle-actions { grid-template-columns:1fr 1fr; gap:8px }
// ====================================================================
class _Aksiyonlar extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;
  const _Aksiyonlar({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final secili = state.seciliKart(vm);
    final oynanabilir = secili != null && vm.isMyTurn && !vm.isSubmittingMove && vm.myTableMove == null;
    final kilitli = vm.isSubmittingMove || vm.myTableMove != null;

    final Widget sag;
    if (vm.mustPass && vm.isMyTurn) {
      sag = RefNeutralButton(
        onTap: vm.isSubmittingMove ? null : vm.pass,
        semanticLabel: 'Pas geç, turu kaybet',
        child: Text(
          'PAS GEÇ · TURU KAYBET',
          textAlign: TextAlign.center,
          style: Ref.bodyText(11, color: Ref.red, weight: FontWeight.w900),
        ),
      );
    } else {
      sag = RefSecondaryButton(
        vm.isSubmittingMove ? 'GÖNDERİLİYOR...' : 'KARTI OYNA',
        leadingGlyph: RefGlyph.swords,
        onTap: oynanabilir ? () => state.seciliyiOyna(vm) : null,
      );
    }

    // IntrinsicHeight: iki düğme eşit yükseklikte (kaydırılan listede
    // yükseklik sınırsız olduğu için tek başına "stretch" olmaz)
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefNeutralButton(
              onTap: kilitli || vm.selectedTactic.isNone || !vm.tacticsEnabled
                  ? null
                  : () => vm.selectTactic(MatchTactic.none),
              semanticLabel: 'Taktiği sıfırla',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, size: 13, color: Ref.neutralText),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'TAKTİĞİ SIFIRLA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: sag),
        ],
      ),
    );
  }
}

class _AltNot extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;
  const _AltNot({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Referans: "Bu demo, güç + kimya + taktik bonusuyla sonucu hesaplar."
      Text(
        'Sonucu sunucu hesaplar: güç + kimya + taktik bonusu.',
        textAlign: TextAlign.center,
        style: Ref.tiny(Ref.muted),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => state.teslimOnayiAc(context, viewModel),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            'Teslim ol',
            style: Ref.bodyText(
              11,
              color: Ref.red,
              weight: FontWeight.w800,
            ).copyWith(decoration: TextDecoration.underline, decorationColor: Ref.red),
          ),
        ),
      ),
    ],
  );
}

// ====================================================================
// TUR GEÇMİŞİ (masaüstü)
// ====================================================================
class _TurGecmisi extends StatelessWidget {
  final MatchViewModel viewModel;
  const _TurGecmisi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final turlar = viewModel.history.rounds;
    return RefCardPanel(
      children: [
        Text('TUR GEÇMİŞİ', style: Ref.caps()),
        if (turlar.isEmpty)
          Text('Henüz tur bitmedi.', style: Ref.tiny(Ref.muted))
        else
          for (final t in turlar)
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${t.roundNumber}', style: Ref.heading(14, color: Ref.muted)),
                ),
                Expanded(
                  child: Text(
                    t.isDraw ? 'Berabere' : (t.winnerId == viewModel.myUserId ? 'Kazandın' : 'Kaybettin'),
                    style: Ref.bodyText(
                      12,
                      weight: FontWeight.w800,
                      color: t.isDraw ? Ref.gold : (t.winnerId == viewModel.myUserId ? Ref.accent : Ref.red),
                    ),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

// ====================================================================
// TUR SONUCU: karttan sahaya 2D düello
// ====================================================================
class _CatismaKatmani extends StatelessWidget {
  final MatchViewModel viewModel;
  const _CatismaKatmani({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final olay = viewModel.currentClash;
    if (olay == null) return const SizedBox.shrink();

    DuelSide taraf(MatchMove? m, {required bool benim}) {
      if (m == null || m.isPass) {
        return DuelSide(
          spec: _yuz(benim ? 'pas-ben' : 'pas-rakip', null),
          name: 'PAS',
          tier: CardTier.bronze,
          power: 0,
          passed: true,
        );
      }
      final elde = benim ? viewModel.hand.where((k) => k.userCardId == m.userCardId).firstOrNull : null;
      final (seed, kit) = _hamleKimligi(m, elde);
      return DuelSide(
        spec: _yuz(seed, kit),
        seed: seed,
        name: m.fullName ?? '',
        tier: m.tier ?? CardTier.bronze,
        power: m.effectivePower ?? 0,
      );
    }

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xE6020810),
        child: SafeArea(
          child: DuelStageFrame(
            child: DuelStage(
              key: ValueKey('catisma-${olay.roundNumber}'),
              me: taraf(olay.myMove, benim: true),
              opponent: taraf(olay.opponentMove, benim: false),
              position: olay.position ?? CardPosition.midfielder,
              outcome: olay.outcome,
              // Çatışma 1-3 sn; kartın sahaya girişi ~500 ms
              speed: 1.8,
              skippable: true,
              headline: olay.headline,
              detail: olay.detail,
              onFinished: viewModel.finishCurrentClash,
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// HATA
// ====================================================================
class _HataEkrani extends StatelessWidget {
  final MatchViewModel viewModel;
  const _HataEkrani({required this.viewModel});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Ref.phoneBg,
    body: SafeArea(
      child: ListView(
        padding: Ref.pagePadding,
        children: [
          Text('CANLI ARENA', style: Ref.h2()),
          const SizedBox(height: Ref.pageGap),
          RefCardPanel(
            children: [
              Text(viewModel.errorMessage ?? 'Maç yüklenemedi.', style: Ref.bodyText(13)),
              RefSecondaryButton('TEKRAR DENE', onTap: viewModel.refresh),
              RefNeutralButton(label: 'ANA SAYFAYA DÖN', onTap: () => context.go(AppRoutes.home)),
            ],
          ),
        ],
      ),
    ),
  );
}

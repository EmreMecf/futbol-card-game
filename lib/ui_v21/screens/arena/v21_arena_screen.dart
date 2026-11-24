import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/match/domain/hand_order.dart';
import '../../../features/match/presentation/viewmodel/match_view_model.dart';
import '../rewards/v21_match_result.dart';
import '../../../features/match/presentation/widgets/surrender_text.dart';
import '../match/v21_tutorial_hint.dart';
import 'v21_clash_scene.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';
import '../../web/web_arena.dart';
import '../../web/web_kit.dart';

/// V2.1 CANLI ARENA (referans arena.png, hf7–hf11).
///
///   [SEN  testoyuncu]  2:2 / TUR 5/11  [RAKİP  StormFC]
///                       (11) sayaç
///          (✓)──(2)──(3)   MEVKİ · KART · TAKTİK
///   [ benim kartım ]  VS  [ rakip: ? / SEÇTİ / açık kart ]
///   mevki aşaması: KALECİ · DEFANS · ORTA SAHA · FORVET   [DEVAM ET]
///   seçim aşaması: FORVET KARTINI SEÇ (el) · PRES/KONTRA/DUVAR · ENERJİ
///   [ OYNA! ]                                     Teslim ol
///
/// V3 SÖZLEŞMESİ: kart ve taktik TEK gizli hamle olarak gönderilir.
/// Taktik yalnız yerel seçimdir (`selectTactic`); OYNA! tek bir
/// `playCard` çağrısıyla kartı ve seçili taktiği birlikte yollar
/// (referanstaki ayrı "KARTI KİLİTLE" adımı bu yüzden yok).
///
/// Bütün kurallar `MatchViewModel`'de (değişmedi): mevki, gizli seçim,
/// enerji, süre aşımı talebi, bağlantı kopunca REST yoklaması, çatışma
/// sahnesi kuyruğu, teslim olma, sonuç.
class V21ArenaScreen extends StatelessWidget {
  final String matchId;
  const V21ArenaScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<MatchViewModel>(
    create: (_) => getIt<MatchViewModel>(param1: matchId)..initialize(),
    child: const _Body(),
  );
}

/// Seçim aşamasının adımları (hf7–hf9 çizelgesi)
({List<String> labels, int current}) arenaSteps(MatchViewModel vm, {required bool cardSelected}) {
  final labels = [if (vm.isSimultaneous) 'MEVKİ', 'KART', if (vm.tacticsEnabled) 'TAKTİK'];
  int current;
  if (vm.isPositionPhase) {
    current = 1;
  } else if (vm.waitingOpponentPick || vm.myTableMove != null) {
    current = labels.length + 1; // hamle kilitlendi: hepsi tamam
  } else if (cardSelected && vm.tacticsEnabled) {
    current = labels.length;
  } else {
    current = labels.indexOf('KART') + 1;
  }
  return (labels: labels, current: current);
}

/// Durum satırı (eski ekranla aynı anlamlar)
String arenaStatus(MatchViewModel vm, HandCard? selected) {
  final d = vm.matchState;
  final need = vm.requiredPosition;
  String text;
  if (vm.isSimultaneous && d != null && vm.isPositionPhase) {
    text = d.amILead
        ? 'Mevkiyi sen seçiyorsun. İkiniz de o mevkiden kartınızı aynı anda, gizlice seçeceksiniz.'
        : 'Rakip mevkiyi seçiyor. Sonra ikiniz aynı anda gizlice kart seçeceksiniz.';
  } else if (vm.waitingOpponentPick) {
    text = 'Hamlen kilitlendi. Rakip seçince iki kart birlikte açılır.';
  } else if (vm.mustPass && vm.isMyTurn) {
    text = 'Bu mevkide kartın yok: pas geçmek zorundasın (tur rakibe yazılır).';
  } else if (!vm.isMyTurn) {
    text = 'Rakip düşünüyor…';
  } else if (!vm.selectedTactic.isNone) {
    text = '${vm.selectedTactic.label}: ${vm.selectedTactic.hint}';
  } else if (selected != null) {
    text =
        '${selected.fullName}: ${selected.power}'
        '${selected.hasChemistry ? ' + ${selected.chemistry} kimya = ${selected.effectivePower}' : ''}. '
        '${vm.tacticsEnabled ? 'İstersen taktik seç, sonra OYNA!' : 'Hazırsan OYNA!'}';
  } else if (need != null && vm.isSimultaneous) {
    text =
        'Mevki: ${need.label.toLowerCase()}. ${vm.tacticsEnabled ? 'Kartını ve taktiğini' : 'Kartını'} gizlice seç; '
        'rakip seçimini göremez.';
  } else if (need != null) {
    text = 'Rakip ${need.label.toLowerCase()} açtı: ${need.label.toLowerCase()} kartı oynamalısın.';
  } else {
    text = vm.tacticsEnabled ? 'Kart ve istersen taktik seç, sonra OYNA!' : 'Bir kart seçip oyna.';
  }
  final last = vm.lastResolvedRound;
  if (last != null && vm.isMyTurn && selected == null && vm.selectedTactic.isNone) {
    final r = last.isDraw
        ? 'Son tur berabere bitti.'
        : (last.winnerId == vm.myUserId ? 'Son turu sen kazandın.' : 'Son turu rakip kazandı.');
    text = '$r $text';
  }
  return text;
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  String? _selectedId;
  CardPosition? _pickedPosition;
  String? _shownError;
  StreamSubscription<bool>? _conn;
  Timer? _offlineDelay;

  /// Kısa kopmalar uyarı göstermez; maç REST yoklamasıyla sürer
  static const offlineNoticeDelay = Duration(seconds: 4);
  bool _showOffline = false;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<WebSocketService>()) {
      final ws = getIt<WebSocketService>();
      _setOnline(ws.isConnected);
      _conn = ws.connectionState.listen(_setOnline);
    }
  }

  void _setOnline(bool online) {
    if (online) {
      _offlineDelay?.cancel();
      _offlineDelay = null;
      if (_showOffline && mounted) setState(() => _showOffline = false);
    } else {
      _offlineDelay ??= Timer(offlineNoticeDelay, () {
        _offlineDelay = null;
        if (mounted) setState(() => _showOffline = true);
      });
    }
  }

  void _retryConnection(MatchViewModel vm) {
    if (getIt.isRegistered<WebSocketService>()) unawaited(getIt<WebSocketService>().retryNow());
    unawaited(vm.refresh());
  }

  @override
  void dispose() {
    _offlineDelay?.cancel();
    _conn?.cancel();
    super.dispose();
  }

  HandCard? _selected(MatchViewModel vm) {
    final id = _selectedId;
    if (id == null) return null;
    for (final c in vm.playableCards) {
      if (c.userCardId == id) return c;
    }
    return null;
  }

  void _select(HandCard c) {
    if (_selectedId != c.userCardId) {
      GameFeedback.haptic(HapticStrength.selection);
      GameAudio.sfx(Sfx.cardSelect);
    }
    setState(() => _selectedId = c.userCardId);
  }

  /// TEK GİZLİ HAMLE: kart + seçili taktik aynı istekte
  Future<void> _play(MatchViewModel vm) async {
    final c = _selected(vm);
    if (c == null) return;
    final ok = await vm.playCard(c);
    if (ok && mounted) setState(() => _selectedId = null);
  }

  Future<void> _confirmPosition(MatchViewModel vm) async {
    final p = _pickedPosition;
    if (p == null) return;
    final ok = await vm.choosePosition(p);
    if (ok && mounted) setState(() => _pickedPosition = null);
  }

  Future<void> _surrender(MatchViewModel vm) async {
    final d = vm.matchState;
    final free = d?.mode == 'friendly' || (d?.isTraining ?? false) || (d?.isTutorial ?? false);
    final ok = await V21GameDialog.show<bool>(
      context,
      subtitle: free ? null : 'GERİ ALINAMAZ',
      title: 'TESLİM OL?',
      message: surrenderWarning(d),
      actions: const [
        V21DialogAction('DEVAM ET', tone: V21ButtonTone.green, result: false),
        V21DialogAction('TESLİM OL', tone: V21ButtonTone.red, result: true),
      ],
    );
    if (ok == true) await vm.surrender();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchViewModel>();

    final err = vm.errorMessage;
    if (err != null && err != _shownError) {
      _shownError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.showError(context, err);
        vm.clearError();
        _shownError = null;
      });
    }
    // Rakibin süresi dolduysa maçı hükmen talep et (eskisiyle aynı)
    if (vm.canClaimTimeout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) vm.claimTimeout();
      });
    }

    if (vm.isLoading && vm.matchState == null) {
      return const Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
      );
    }
    if (vm.matchState == null) return _ErrorView(vm: vm);

    // Maç bittiyse sonuç; son turun sahnesi oynadıktan sonra
    if (vm.isOver && vm.currentClash == null) {
      return V21MatchResultView(
        newMatchLabel: vm.result == null ? 'YENİ MAÇ' : newMatchLabel(vm.result!),
        result: vm.result,
        rewardDelta: vm.rewardDelta,
        onClose: () => context.go(AppRoutes.home),
        onNewMatch: () => context.go(vm.matchState?.mode == 'friendly' ? AppRoutes.friends : AppRoutes.matchmaking),
      );
    }

    final selected = _selected(vm);
    if (v21IsWeb(context)) {
      final steps = arenaSteps(vm, cardSelected: selected != null);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _surrender(vm);
        },
        child: WebArena(
          vm: vm,
          selected: selected,
          pickedPosition: _pickedPosition,
          stepLabels: steps.labels,
          stepCurrent: steps.current,
          status: arenaStatus(vm, selected),
          onSelect: _select,
          onPickPosition: (p) => setState(() => _pickedPosition = p),
          onPlay: () => _play(vm),
          onConfirmPosition: () => _confirmPosition(vm),
          onSurrender: () => _surrender(vm),
          tutorial: vm.matchState!.isTutorial ? V21TutorialHint(state: vm.matchState!) : null,
          overlays: [
            if (_showOffline && vm.currentClash == null) _Reconnecting(onRetry: () => _retryConnection(vm)),
            _ClashLayer(vm: vm),
          ],
        ),
      );
    }
    return PopScope(
      // Maçtan kaçış yok: geri tuşu teslim olma onayı sorar
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _surrender(vm);
      },
      child: Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: Stack(
          children: [
            const Positioned.fill(child: V21Background()),
            // Üstte stadyum gece göğü + projektörler (referans arena.png)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 230,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.6, 1],
                ).createShader(r),
                child: const V21StadiumSky(),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final sc = V21Scale.forSize(box.biggest);
                final k = sc.s;
                return SafeArea(
                  child: Center(
                    child: SizedBox(
                      width: sc.contentWidth,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(10 * k, 8 * k, 10 * k, 0),
                            child: _Scoreboard(vm: vm, scale: k),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.fromLTRB(12 * k, 6 * k, 12 * k, 12 * k),
                              children: [
                                _TimerRow(vm: vm, scale: k),
                                SizedBox(height: 6 * k),
                                Builder(
                                  builder: (context) {
                                    final s = arenaSteps(vm, cardSelected: selected != null);
                                    return Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 22 * k),
                                      child: V21StepTracker(labels: s.labels, current: s.current, scale: k),
                                    );
                                  },
                                ),
                                if (vm.matchState!.isTutorial) ...[
                                  SizedBox(height: 8 * k),
                                  V21TutorialHint(state: vm.matchState!),
                                ],
                                SizedBox(height: 10 * k),
                                _VsRow(vm: vm, selected: selected, scale: k),
                                SizedBox(height: 8 * k),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    arenaStatus(vm, selected),
                                    textAlign: TextAlign.center,
                                    style: V21Type.label(
                                      12.5 * k,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFFE6DBFF),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10 * k),
                                if (vm.isPositionPhase)
                                  _PositionPicker(
                                    vm: vm,
                                    picked: _pickedPosition,
                                    scale: k,
                                    onPick: (p) => setState(() => _pickedPosition = p),
                                  )
                                else
                                  _Hand(vm: vm, selected: selected, scale: k, onSelect: _select),
                                if (vm.tacticsEnabled && !vm.isPositionPhase) ...[
                                  SizedBox(height: 12 * k),
                                  _Tactics(vm: vm, scale: k),
                                ],
                              ],
                            ),
                          ),
                          _ActionBar(
                            vm: vm,
                            selected: selected,
                            pickedPosition: _pickedPosition,
                            scale: k,
                            onPlay: () => _play(vm),
                            onConfirmPosition: () => _confirmPosition(vm),
                            onSurrender: () => _surrender(vm),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_showOffline && vm.currentClash == null) _Reconnecting(onRetry: () => _retryConnection(vm)),
            _ClashLayer(vm: vm),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// SKOR TABELASI
// ====================================================================
class _Scoreboard extends StatelessWidget {
  final MatchViewModel vm;
  final double scale;
  const _Scoreboard({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = vm.matchState!;
    final me = vm.myUsername ?? context.watch<SessionManager?>()?.user?.username ?? 'Sen';
    final opp = d.opponent?.username ?? 'Rakip';
    final round = d.isTutorial && d.earlyFinishCards != null
        ? 'TUR ${d.roundNumber} · HEDEF ${d.earlyFinishCards}'
        : 'TUR ${d.roundNumber}/${GameRules.squadSize}';
    final mode = d.mode == 'friendly' ? 'ARKADAŞ MAÇI · ÖDÜL YOK' : (d.isTutorial ? 'ÖĞRETİCİ · ÖDÜLSÜZ' : (d.isTraining ? 'ANTRENMAN · ÖDÜLSÜZ' : 'DERECELİ'));
    return Semantics(
      container: true,
      label: 'Skor: sen ${d.myScore}, $opp ${d.opponentScore}. $round. $mode',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Side(name: 'SEN', sub: me, seed: 'oyuncu-${vm.myUserId ?? me}', mine: true, scale: k),
              ),
              SizedBox(width: 6 * k),
              Container(
                width: 74 * k,
                padding: EdgeInsets.symmetric(vertical: 4 * k),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B0F45),
                  borderRadius: BorderRadius.circular(12 * k),
                  border: Border.all(color: V21Colors.goldTop, width: 2.5 * k),
                ),
                child: Column(
                  children: [
                    Text('${d.myScore}:${d.opponentScore}', style: V21Type.title(26 * k, height: 1)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        round,
                        style: V21Type.label(9 * k, weight: FontWeight.w900, color: V21Colors.goldTop),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6 * k),
              Expanded(
                child: _Side(name: 'RAKİP', sub: opp, seed: 'oyuncu-${d.opponent?.id ?? opp}', mine: false, scale: k),
              ),
            ],
          ),
          SizedBox(height: 4 * k),
          V21Tag(
            text: mode,
            background: d.mode != 'ranked' ? const Color(0xFF3B2F66) : const Color(0xCC1B0A57),
            foreground: d.mode != 'ranked' ? V21Colors.textMuted : V21Colors.goldTop,
            scale: k,
            fontSize: 10,
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final String name;
  final String sub;
  final String seed;
  final bool mine;
  final double scale;
  const _Side({required this.name, required this.sub, required this.seed, required this.mine, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final avatar = V21PlayerAvatar(
      seed: seed,
      size: 40 * k,
      semanticsLabel: sub,
      background: mine ? const Color(0xFF7FC0FF) : const Color(0xFFFF9AA8),
    );
    final text = Expanded(
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(name, style: V21Type.title(17 * k, height: 1)),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V21Type.label(10.5 * k, weight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
    return Container(
      height: 50 * k,
      padding: EdgeInsets.symmetric(horizontal: 6 * k),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: mine ? const [Color(0xFF4FA8FF), Color(0xFF1F5FD8)] : const [Color(0xFFFF6B83), Color(0xFFC21E45)],
        ),
        borderRadius: BorderRadius.circular(12 * k),
        border: Border.all(color: V21Colors.ink, width: 2 * k),
      ),
      child: Row(
        children: mine ? [avatar, SizedBox(width: 6 * k), text] : [text, SizedBox(width: 6 * k), avatar],
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  final MatchViewModel vm;
  final double scale;
  const _TimerRow({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Center(
      child: Semantics(
        label: 'Kalan süre ${vm.remainingSeconds} saniye',
        excludeSemantics: true,
        child: V21MatchTimer(
          seconds: vm.remainingSeconds,
          total: GameRules.turnDuration.inSeconds,
          size: 46 * k,
          // Ayarlardan "süre uyarısı" kapalıysa kırmızıya dönmez
          urgentAt: GameFeedback.turnWarningEnabled ? 10 : -1,
        ),
      ),
    );
  }
}

// ====================================================================
// VS SATIRI
// ====================================================================
class _VsRow extends StatelessWidget {
  final MatchViewModel vm;
  final HandCard? selected;
  final double scale;
  const _VsRow({required this.vm, required this.selected, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final w = 126 * k;
    final mine = vm.myTableMove;
    final opp = vm.opponentTableMove;
    final locked = vm.waitingOpponentPick || (mine != null && opp == null);

    Widget myCard;
    String myCaption;
    if (mine != null && !mine.isPass) {
      myCard = _MoveCard(move: mine, width: w, locked: locked);
      myCaption = locked ? 'SEÇİMİN KİLİTLENDİ' : 'SENİN KARTIN';
    } else if (selected != null) {
      myCard = V21PlayerCard(
        name: selected!.fullName,
        position: selected!.position,
        tier: selected!.tier,
        power: selected!.effectivePower,
        width: w,
        selected: true,
      );
      myCaption = 'SEÇİLİ KART';
    } else if (vm.waitingOpponentPick) {
      // Hamle gitti ama masada henüz görünmüyor: kilitli sırt (hf10)
      myCard = _Hidden(width: w, lock: true, semantics: 'Seçimin kilitlendi');
      myCaption = 'SEÇİMİN KİLİTLENDİ';
    } else {
      myCard = _Hidden(width: w, mark: '?', semantics: 'Kart seçilmedi');
      myCaption = vm.isPositionPhase
          ? (vm.matchState!.amILead ? 'Önce mevkiyi seç' : 'Rakip mevki seçiyor')
          : (!vm.isMyTurn ? 'Sıra rakipte' : (vm.mustPass ? 'Bu mevkide kartın yok' : 'Kartını gizlice seç'));
    }

    Widget oppCard;
    String oppCaption;
    if (opp != null && !opp.isPass) {
      oppCard = _MoveCard(move: opp, width: w, locked: false);
      oppCaption = 'RAKİP KARTI';
    } else if (vm.isSimultaneous && vm.matchState!.opponentHasPlayed) {
      oppCard = _Hidden(width: w, lock: true, semantics: 'Rakip seçti, kart gizli');
      oppCaption = 'Rakip seçti · gizli';
    } else {
      oppCard = _Hidden(width: w, mark: '?', semantics: 'Rakip kartı gizli');
      oppCaption = locked ? 'Rakip bekleniyor…' : 'Rakip seçiyor…';
    }

    Widget column(Widget card, String caption, Color color) => Column(
      children: [
        card,
        SizedBox(height: 4 * k),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: V21Type.label(11.5 * k, weight: FontWeight.w900, color: color),
        ),
      ],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(myCard, myCaption, locked ? V21Colors.successText : Colors.white),
        SizedBox(
          width: 48 * k,
          height: w * V21PlayerCard.baseHeight / V21PlayerCard.baseWidth,
          child: Center(
            child: Text(
              'VS',
              style: V21Type.title(36 * k, color: V21Colors.goldTop, shadows: V21Type.inkShadow(k)),
            ),
          ),
        ),
        column(oppCard, oppCaption, V21Colors.textMuted),
      ],
    );
  }
}

class _MoveCard extends StatelessWidget {
  final MatchMove move;
  final double width;
  final bool locked;
  const _MoveCard({required this.move, required this.width, required this.locked});

  @override
  Widget build(BuildContext context) {
    final card = V21PlayerCard(
      name: move.fullName ?? '',
      position: move.position ?? CardPosition.midfielder,
      tier: move.tier ?? CardTier.bronze,
      power: move.effectivePower ?? 0,
      width: width,
    );
    if (!locked) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: V21Colors.goldTop,
              shape: BoxShape.circle,
              border: Border.all(color: V21Colors.ink, width: 2),
            ),
            child: Icon(Icons.lock_rounded, size: width * 0.13, color: V21Colors.ink),
          ),
        ),
      ],
    );
  }
}

/// Gizli kart: kart sırtı + "?" ya da kilit
class _Hidden extends StatelessWidget {
  final double width;
  final String? mark;
  final bool lock;
  final String semantics;
  const _Hidden({required this.width, required this.semantics, this.mark, this.lock = false});

  @override
  Widget build(BuildContext context) {
    final s = width / V21PlayerCard.baseWidth;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          V21CardBack(width: width, semanticsLabel: semantics),
          Container(
            width: 62 * s,
            height: 62 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC1B0F45),
              border: Border.all(color: V21Colors.goldTop, width: 4 * s),
            ),
            alignment: Alignment.center,
            child: lock
                ? Icon(Icons.lock_rounded, color: V21Colors.goldTop, size: 32 * s)
                : Text(mark ?? '?', style: V21Type.title(38 * s, color: V21Colors.goldTop)),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// MEVKİ SEÇİMİ (hf7)
// ====================================================================
class _PositionPicker extends StatelessWidget {
  final MatchViewModel vm;
  final CardPosition? picked;
  final double scale;
  final ValueChanged<CardPosition> onPick;
  const _PositionPicker({required this.vm, required this.picked, required this.scale, required this.onPick});

  static IconData _icon(CardPosition p) => switch (p) {
    CardPosition.goalkeeper => Icons.sports_handball_rounded,
    CardPosition.defender => Icons.shield_rounded,
    CardPosition.midfielder => Icons.swap_horiz_rounded,
    CardPosition.forward => Icons.sports_soccer_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final counts = vm.positionCounts;
    final lead = vm.matchState!.amILead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lead ? 'Bu tur oynayacağın mevkiyi seç' : 'Rakip bu turun mevkisini seçiyor',
          textAlign: TextAlign.center,
          style: V21Type.title(17 * k, color: lead ? Colors.white : V21Colors.textMuted),
        ),
        SizedBox(height: 8 * k),
        Row(
          children: [
            for (final (i, p) in CardPosition.values.indexed) ...[
              if (i > 0) SizedBox(width: 6 * k),
              Expanded(
                child: _PositionTile(
                  label: V21Format.upper(p.label),
                  icon: _icon(p),
                  count: counts[p] ?? 0,
                  selected: picked == p,
                  enabled: lead && (counts[p] ?? 0) > 0 && !vm.isSubmittingMove,
                  scale: k,
                  onTap: () => onPick(p),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PositionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final bool enabled;
  final double scale;
  final VoidCallback onTap;
  const _PositionTile({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '$label, elinde $count kart',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled || selected ? 1 : 0.45,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 92 * k,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0xFF3FBF5A), Color(0xFF14702C)]
                    : const [Color(0xFF5B39C4), Color(0xFF2A1670)],
              ),
              borderRadius: BorderRadius.circular(12 * k),
              border: Border.all(color: selected ? V21Colors.successText : V21Colors.ink, width: 2.5 * k),
              boxShadow: selected ? [BoxShadow(color: const Color(0x8848E06A), blurRadius: 12 * k)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30 * k, color: Colors.white),
                SizedBox(height: 4 * k),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1, style: V21Type.title(14 * k)),
                ),
                Text(
                  '$count kart',
                  style: V21Type.label(10 * k, weight: FontWeight.w800, color: const Color(0xFFD9CAFB)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// EL (hf8)
// ====================================================================
class _Hand extends StatelessWidget {
  final MatchViewModel vm;
  final HandCard? selected;
  final double scale;
  final ValueChanged<HandCard> onSelect;
  const _Hand({required this.vm, required this.selected, required this.scale, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final need = vm.requiredPosition;
    final cards = handOrder(vm.hand, need);
    if (cards.isEmpty) return const SizedBox.shrink();
    final playable = cards.where((c) => need == null || c.position == need).length;
    final w = 76 * k;
    final h = w * V21PlayerCard.baseHeight / V21PlayerCard.baseWidth;
    final pot = vm.matchState!.potCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                need == null ? 'KARTINI SEÇ' : '${V21Format.upper(need.label)} KARTINI SEÇ',
                style: V21Type.title(15 * k, color: V21Colors.goldTop),
              ),
            ),
            if (pot > 0) ...[
              V21Tag(
                text: 'MASADA $pot',
                background: const Color(0xFF3B2F66),
                foreground: Colors.white,
                scale: k,
                fontSize: 10,
              ),
              SizedBox(width: 6 * k),
            ],
            Text(
              '$playable kart uygun',
              style: V21Type.label(11 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
            ),
          ],
        ),
        SizedBox(height: 6 * k),
        SizedBox(
          height: h + 14 * k,
          child: ListView.separated(
            key: ValueKey('el-${need?.name}'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(vertical: 7 * k, horizontal: 2 * k),
            itemCount: cards.length,
            separatorBuilder: (_, _) => SizedBox(width: 6 * k),
            itemBuilder: (context, i) {
              final c = cards[i];
              final ok = need == null || c.position == need;
              final enabled = vm.isMyTurn && ok && !vm.isSubmittingMove && vm.myTableMove == null;
              final isSel = selected?.userCardId == c.userCardId;
              return AnimatedScale(
                key: ValueKey('el-${c.userCardId}'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: isSel ? 1.06 : 1,
                child: Opacity(
                  opacity: ok ? 1 : 0.4,
                  child: V21PlayerCard(
                    name: c.fullName,
                    position: c.position,
                    tier: c.tier,
                    power: c.effectivePower,
                    width: w,
                    selected: isSel,
                    onTap: enabled ? () => onSelect(c) : null,
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
// TAKTİK + ENERJİ (hf9)
// ====================================================================
class _Tactics extends StatelessWidget {
  final MatchViewModel vm;
  final double scale;
  const _Tactics({required this.vm, required this.scale});

  static (String, IconData, List<Color>) _look(MatchTactic t) => switch (t) {
    MatchTactic.highPress => (
      'PRES',
      Icons.keyboard_double_arrow_up_rounded,
      const [Color(0xFFFF6B83), Color(0xFFC21E45)],
    ),
    MatchTactic.counterAttack => ('KONTRA', Icons.fast_forward_rounded, const [Color(0xFFFFD84D), Color(0xFFE89A1A)]),
    MatchTactic.defensiveWall => ('DUVAR', Icons.grid_view_rounded, const [Color(0xFF6FE4FF), Color(0xFF1F7EEB)]),
    MatchTactic.none => ('', Icons.block, const [Colors.grey, Colors.grey]),
  };

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final locked = vm.isSubmittingMove || vm.myTableMove != null;
    return Column(
      children: [
        Text('Taktiğini seç', style: V21Type.title(15 * k, color: Colors.white)),
        SizedBox(height: 6 * k),
        Row(
          children: [
            for (final t in MatchTactic.playable)
              Expanded(
                child: _TacticOrb(
                  tactic: t,
                  look: _look(t),
                  cost: vm.tacticCost(t),
                  selected: vm.selectedTactic == t,
                  enabled: !locked && vm.canUseTactic(t),
                  scale: k,
                  onTap: () => vm.selectTactic(t),
                ),
              ),
            SizedBox(
              width: 104 * k,
              child: Semantics(
                label: 'Enerji ${vm.myEnergy} / ${vm.maxEnergy}',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: V21EnergyBar(value: vm.myEnergy, max: vm.maxEnergy, scale: k * 0.9),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TacticOrb extends StatelessWidget {
  final MatchTactic tactic;
  final (String, IconData, List<Color>) look;
  final int cost;
  final bool selected;
  final bool enabled;
  final double scale;
  final VoidCallback onTap;
  const _TacticOrb({
    required this.tactic,
    required this.look,
    required this.cost,
    required this.selected,
    required this.enabled,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final (label, icon, colors) = look;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${tactic.label}, $cost enerji. ${tactic.hint}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled || selected ? onTap : null,
        child: Opacity(
          opacity: enabled || selected ? 1 : 0.4,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52 * k,
                height: 52 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                  border: Border.all(
                    color: selected ? V21Colors.successText : V21Colors.ink,
                    width: (selected ? 4 : 2.5) * k,
                  ),
                  boxShadow: selected ? [BoxShadow(color: const Color(0xAA48E06A), blurRadius: 14 * k)] : null,
                ),
                child: Icon(icon, color: Colors.white, size: 28 * k),
              ),
              SizedBox(height: 3 * k),
              Text(label, style: V21Type.title(13 * k)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7 * k, vertical: 1 * k),
                decoration: BoxDecoration(
                  color: selected ? V21Colors.success : const Color(0xFF3B2F66),
                  borderRadius: BorderRadius.circular(8 * k),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12 * k, color: V21Colors.goldTop),
                    Text(
                      '$cost',
                      style: V21Type.label(11 * k, weight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// ALT ŞERİT: OYNA! / DEVAM ET / PAS / bekleme
// ====================================================================
class _ActionBar extends StatelessWidget {
  final MatchViewModel vm;
  final HandCard? selected;
  final CardPosition? pickedPosition;
  final double scale;
  final VoidCallback onPlay;
  final VoidCallback onConfirmPosition;
  final VoidCallback onSurrender;
  const _ActionBar({
    required this.vm,
    required this.selected,
    required this.pickedPosition,
    required this.scale,
    required this.onPlay,
    required this.onConfirmPosition,
    required this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = vm.matchState!;
    Widget button;
    if (vm.isPositionPhase) {
      button = d.amILead
          ? V21GameButton(
              label: 'DEVAM ET',
              tone: V21ButtonTone.green,
              size: V21ButtonSize.large,
              scale: k,
              semanticsLabel: pickedPosition == null ? 'Devam et: önce mevki seç' : 'Mevkiyi onayla',
              status: vm.isSubmittingMove
                  ? V21ButtonStatus.loading
                  : (pickedPosition == null ? V21ButtonStatus.disabled : V21ButtonStatus.normal),
              onPressed: onConfirmPosition,
            )
          : V21GameButton(
              label: 'RAKİP MEVKİ SEÇİYOR',
              tone: V21ButtonTone.purple,
              size: V21ButtonSize.large,
              scale: k,
              status: V21ButtonStatus.disabled,
              onPressed: () {},
            );
    } else if (vm.mustPass && vm.isMyTurn) {
      button = V21GameButton(
        label: 'PAS GEÇ · TURU KAYBET',
        tone: V21ButtonTone.red,
        size: V21ButtonSize.large,
        scale: k,
        status: vm.isSubmittingMove ? V21ButtonStatus.loading : V21ButtonStatus.normal,
        onPressed: vm.pass,
      );
    } else if (vm.waitingOpponentPick || vm.myTableMove != null) {
      button = V21GameButton(
        label: 'RAKİP BEKLENİYOR',
        tone: V21ButtonTone.purple,
        size: V21ButtonSize.large,
        leadingIcon: Icons.lock_rounded,
        scale: k,
        status: V21ButtonStatus.disabled,
        onPressed: () {},
      );
    } else if (!vm.isMyTurn) {
      button = V21GameButton(
        label: 'SIRA RAKİPTE',
        tone: V21ButtonTone.purple,
        size: V21ButtonSize.large,
        scale: k,
        status: V21ButtonStatus.disabled,
        onPressed: () {},
      );
    } else {
      final tactic = vm.selectedTactic;
      button = V21GameButton(
        label: 'OYNA!',
        tone: V21ButtonTone.green,
        size: V21ButtonSize.large,
        scale: k,
        semanticsLabel: selected == null
            ? 'Oyna: önce kart seç'
            : 'Oyna: ${selected!.fullName}${tactic.isNone ? '' : ' ve ${tactic.label}'}, tek hamle',
        status: vm.isSubmittingMove
            ? V21ButtonStatus.loading
            : (selected == null ? V21ButtonStatus.disabled : V21ButtonStatus.normal),
        onPressed: onPlay,
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12 * k, 8 * k, 12 * k, 4 * k),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00120830), Color(0xEE120830)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          TextButton(
            onPressed: onSurrender,
            style: TextButton.styleFrom(
              minimumSize: Size(0, 32 * k),
              padding: EdgeInsets.symmetric(horizontal: 12 * k),
            ),
            child: Text(
              'Teslim ol',
              style: V21Type.label(12 * k, weight: FontWeight.w800, color: const Color(0xFFFF8A9B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// YENİDEN BAĞLANMA (hf11)
// ====================================================================
/// Anlık bağlantı kopuksa ekranın üstünde küçük bir şerit. Oyunu
/// KAPATMAZ: maç REST yoklamasıyla sürer, kart ve taktik seçilip
/// OYNA! ile gönderilebilir.
class _Reconnecting extends StatelessWidget {
  final VoidCallback onRetry;
  const _Reconnecting({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 0,
      right: 0,
      top: top + 64,
      child: LayoutBuilder(
        builder: (context, box) {
          final k = V21Scale.forSize(Size(box.maxWidth, 844)).s;
          return Center(
            child: Semantics(
              liveRegion: true,
              label: 'Bağlantı yeniden kuruluyor. Maç devam ediyor.',
              child: Container(
                constraints: BoxConstraints(maxWidth: 360 * k),
                margin: EdgeInsets.symmetric(horizontal: 12 * k),
                padding: EdgeInsets.fromLTRB(12 * k, 6 * k, 6 * k, 6 * k),
                decoration: BoxDecoration(
                  color: const Color(0xEE1B0F45),
                  borderRadius: BorderRadius.circular(14 * k),
                  border: Border.all(color: const Color(0xFF6FE4FF), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cell_tower_rounded, size: 20 * k, color: const Color(0xFF6FE4FF)),
                    SizedBox(width: 8 * k),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BAĞLANTI YENİDEN KURULUYOR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V21Type.label(12 * k, weight: FontWeight.w900, color: V21Colors.goldTop),
                          ),
                          Text(
                            'Maç sürüyor, hamleni yapabilirsin.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V21Type.label(11 * k, weight: FontWeight.w700, color: const Color(0xFFE6DBFF)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6 * k),
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10 * k),
                        minimumSize: Size(0, 36 * k),
                      ),
                      child: Text(
                        'TEKRAR DENE',
                        style: V21Type.label(11 * k, weight: FontWeight.w900, color: const Color(0xFF6FE4FF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tur sonucu sahnesi: sırası gelen tur varsa tam ekran
class _ClashLayer extends StatelessWidget {
  final MatchViewModel vm;
  const _ClashLayer({required this.vm});

  @override
  Widget build(BuildContext context) {
    final e = vm.currentClash;
    if (e == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: V21ClashScene(key: ValueKey('catisma-${e.roundNumber}'), event: e, onFinished: vm.finishCurrentClash),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final MatchViewModel vm;
  const _ErrorView({required this.vm});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: V21Colors.inkDeep,
    body: Stack(
      children: [
        const Positioned.fill(child: V21Background()),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: V21EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'MAÇ YÜKLENEMEDİ',
                message: vm.errorMessage ?? 'Bağlantını kontrol edip tekrar dene.',
                actionLabel: 'TEKRAR DENE',
                onAction: vm.refresh,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(
                'ANA SAYFAYA DÖN',
                style: V21Type.label(13, weight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

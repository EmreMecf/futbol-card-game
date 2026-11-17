import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import '../../../shared/widgets/error_snackbar.dart';
import '../../ui_v21.dart';
import '../home/v21_home_nav.dart';

/// V2.1 MAÇA HAZIRLAN + RAKİP ARAMA (referans matchPrep, hf3–hf6).
///
///   MAÇA HAZIRLAN            Takımın hazır mı?   [KART KAYBI YOK]
///   (öğretici kartı, yeni oyuncuya)
///   [ RAKİP BUL ] [ BOTLA ANTRENMAN ] [ KADROYU DÜZENLE ]
///   KARTLARINI KORU n/max (kart kaybı açıksa)
///
///   arama:  RAKİP ARANIYOR · radar · ⏱ 00:08 · [ARAMAYI İPTAL ET]
///     20 sn+  ARAMA DEVAM EDİYOR (aralık genişliyor) + BOTLA ANTRENMAN
///     60 sn+  HENÜZ RAKİP BULUNAMADI (arama SÜRER; sunucu kuyruğu tutar)
///     bağlantı kopuk: BAĞLANTI KONTROL EDİLİYOR (yoklama REST'ten sürer)
///
/// VERİ VE KURALLAR: `MatchmakingViewModel` (değişmedi). Kadro doğrulaması,
/// koruma, arama, iptal, antrenman, öğretici ve eşleşince maça geçiş
/// eskisiyle aynı. "ARKADAŞINLA OYNA" PR #6 birleşince eklenecek.
class V21MatchmakingScreen extends StatelessWidget {
  const V21MatchmakingScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<MatchmakingViewModel>(
    create: (_) => getIt<MatchmakingViewModel>()..initialize(),
    child: const _Body(),
  );
}

/// Arama aşaması (süreye ve bağlantıya göre)
enum V21SearchPhase { searching, widened, notFound, offline }

/// hf3 (<20 sn) → hf4 (20–60 sn) → hf5 (60 sn+); bağlantı kopuksa hf6
V21SearchPhase searchPhaseFor(Duration d, {required bool online}) {
  if (!online) return V21SearchPhase.offline;
  if (d >= const Duration(seconds: 60)) return V21SearchPhase.notFound;
  if (d >= const Duration(seconds: 20)) return V21SearchPhase.widened;
  return V21SearchPhase.searching;
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Sayaç her saniye ilerlesin (VM yalnız yoklamada bildirir)
  Timer? _tick;
  StreamSubscription<bool>? _conn;
  bool _online = true;
  String? _shownError;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<WebSocketService>()) {
      final ws = getIt<WebSocketService>();
      _online = ws.isConnected;
      _conn = ws.connectionState.listen((v) {
        if (mounted) setState(() => _online = v);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _conn?.cancel();
    super.dispose();
  }

  void _syncTicker(bool searching) {
    if (searching && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!searching && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  Future<void> _findOpponent(MatchmakingViewModel vm) async {
    final v = vm.validation;
    if (v != null && !v.isValid) {
      // hf17: kadro geçersizse maç aranmaz → aynı uyarı
      final edit = await V21SquadWarning.show(context, missing: const {}, message: v.displayMessage);
      if (edit && mounted) context.go(AppRoutes.deck);
      return;
    }
    if (vm.canSearch) await vm.startSearch();
  }

  /// Aramayı bırakıp bota karşı antrenman (iptal sırasında eşleşme
  /// gelirse maça gidilir, antrenman başlatılmaz)
  Future<void> _trainInstead(MatchmakingViewModel vm) async {
    await vm.cancelSearch();
    if (!mounted || vm.foundMatchId != null) return;
    await vm.startTraining();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchmakingViewModel>();

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

    final id = vm.foundMatchId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        vm.consumeFoundMatch();
        context.pushReplacement(AppRoutes.matchWithId(id));
      });
    }

    final searching = vm.stage == MatchmakingStage.searching;
    _syncTicker(searching);

    return PopScope(
      // Aramadayken çıkış "iptal" demektir (kuyrukta unutulmasın)
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) vm.cancelSearch();
      },
      child: V21ScreenLayout(
        // Arama sürerken menü gizli: çıkış yalnız ARAMAYI İPTAL ET
        bottomNavigation: searching
            ? null
            : (context, sc) =>
                  V21HomeNav(currentRoute: AppRoutes.matchmaking, highlightRoute: AppRoutes.home, scale: sc.s),
        body: (context, sc) {
          final k = sc.s;
          if (vm.isLoading && vm.selectedDeck == null) {
            return const Center(child: CircularProgressIndicator(color: V21Colors.goldTop));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(14 * k, 10 * k, 14 * k, 24 * k),
            children: [
              const _Header(),
              SizedBox(height: 10 * k),
              if (searching)
                _Search(
                  vm: vm,
                  phase: searchPhaseFor(vm.searchDuration, online: _online),
                  scale: k,
                  onTrain: () => _trainInstead(vm),
                )
              else
                _Prep(vm: vm, scale: k, onFind: () => _findOpponent(vm)),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final k = V21Scale.of(context).s;
    final user = context.watch<SessionManager>().user;
    return V21GameHeader(
      scale: k,
      username: user?.username ?? '',
      onProfileTap: () => context.push(AppRoutes.profile),
      trailing: [V21ResourcePill.coins(scale: k, coins: user?.coins)],
    );
  }
}

// ====================================================================
// MAÇA HAZIRLAN
// ====================================================================
class _Prep extends StatelessWidget {
  final MatchmakingViewModel vm;
  final double scale;
  final VoidCallback onFind;
  const _Prep({required this.vm, required this.scale, required this.onFind});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final v = vm.validation;
    final valid = v?.isValid ?? false;
    final checking = vm.selectedDeck != null && v == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V21PageTitle(title: 'MAÇA HAZIRLAN', scale: k, onBack: () => context.go(AppRoutes.home)),
        SizedBox(height: 10 * k),
        _Hero(
          scale: k,
          status: checking ? 'Kadro kontrol ediliyor…' : (v?.displayMessage ?? 'Kadro bulunamadı'),
          valid: valid,
          tag: vm.cardLossEnabled ? 'KORUMA ${vm.protectedCardIds.length}/${vm.maxProtection}' : 'KART KAYBI YOK',
        ),
        if (vm.tutorial?.shouldOffer ?? false) ...[SizedBox(height: 12 * k), _TutorialOffer(vm: vm, scale: k)],
        SizedBox(height: 14 * k),
        V21GameButton(
          label: 'RAKİP BUL',
          size: V21ButtonSize.large,
          leadingIcon: Icons.sports_soccer_rounded,
          scale: k,
          semanticsLabel: valid ? 'Rakip bul: dereceli maç' : 'Rakip bul: önce kadroyu düzelt',
          status: checking || v == null ? V21ButtonStatus.disabled : V21ButtonStatus.normal,
          onPressed: onFind,
        ),
        if (vm.trainingEnabled) ...[
          SizedBox(height: 10 * k),
          V21GameButton(
            label: 'BOTLA ANTRENMAN',
            tone: V21ButtonTone.green,
            leadingIcon: Icons.smart_toy_rounded,
            scale: k,
            semanticsLabel: 'Botla antrenman: ödülsüz ve puansız',
            status: vm.canSearch ? V21ButtonStatus.normal : V21ButtonStatus.disabled,
            onPressed: vm.startTraining,
          ),
        ],
        SizedBox(height: 10 * k),
        V21GameButton(
          label: 'KADROYU DÜZENLE',
          tone: V21ButtonTone.purple,
          leadingIcon: Icons.groups_rounded,
          scale: k,
          onPressed: () => context.go(AppRoutes.deck),
        ),
        SizedBox(height: 18 * k),
        if (vm.cardLossEnabled)
          _Protection(vm: vm, scale: k)
        else
          Text(
            'Dereceli maçta kart kaybı yok: kartların sende kalır. Kazanırsan kadrondaki bir futbolcu +1 gelişim '
            'kopyası alır.',
            textAlign: TextAlign.center,
            style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.4),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final double scale;
  final String status;
  final bool valid;
  final String tag;
  const _Hero({required this.scale, required this.status, required this.valid, required this.tag});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return V21GamePanel(
      scale: k,
      radius: 18,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16 * k),
        child: SizedBox(
          height: 170 * k,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF241A8C), Color(0xFF3A1C8E), Color(0xFF1B0F55)],
                  ),
                ),
              ),
              const Positioned.fill(child: V21RaysBackground(rayColor: Color(0x14FFFFFF))),
              Positioned(
                right: -6 * k,
                bottom: 0,
                top: 6 * k,
                child: Image.asset(V21Assets.victoryMascot, fit: BoxFit.fitHeight),
              ),
              Positioned(
                left: 14 * k,
                top: 14 * k,
                right: 150 * k,
                bottom: 12 * k,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    V21Tag(
                      text: tag,
                      background: const Color(0xCC1B0A57),
                      foreground: Colors.white,
                      scale: k,
                      fontSize: 11,
                    ),
                    SizedBox(height: 8 * k),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Takımın hazır mı?', style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k))),
                    ),
                    const Spacer(),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          Icon(
                            valid ? Icons.check_circle_rounded : Icons.error_rounded,
                            size: 18 * k,
                            color: valid ? V21Colors.successText : const Color(0xFFFF8A9B),
                          ),
                          SizedBox(width: 6 * k),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 2,
                              style: V21Type.label(12.5 * k, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
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

class _TutorialOffer extends StatelessWidget {
  final MatchmakingViewModel vm;
  final double scale;
  const _TutorialOffer({required this.vm, required this.scale});

  static const _steps = ['MEVKİ', 'KART', 'TAKTİK'];

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final step = (vm.tutorial?.nextStep ?? 1).clamp(1, 3);
    return V21GamePanel(
      scale: k,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12 * k, 10 * k, 12 * k, 12 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ÖĞRETİCİ · $step/3',
            textAlign: TextAlign.center,
            style: V21Type.title(22 * k, color: V21Colors.goldTop, shadows: V21Type.inkShadow(k)),
          ),
          SizedBox(height: 8 * k),
          V21StepTracker(labels: _steps, current: step, scale: k),
          SizedBox(height: 6 * k),
          Text(
            'Bota karşı kısa maç (6 kart), puan ve ödül yok. 3 adımı bitirince Gümüş sandık kazanırsın.',
            textAlign: TextAlign.center,
            style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.35),
          ),
          SizedBox(height: 10 * k),
          V21GameButton(
            label: 'ÖĞRETİCİYİ BAŞLAT',
            tone: V21ButtonTone.blue,
            scale: k,
            status: vm.canSearch ? V21ButtonStatus.normal : V21ButtonStatus.disabled,
            onPressed: vm.startTutorial,
          ),
        ],
      ),
    );
  }
}

class _Protection extends StatelessWidget {
  final MatchmakingViewModel vm;
  final double scale;
  const _Protection({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: V21SectionTitle('KARTLARINI KORU ${vm.protectedCardIds.length}/${vm.maxProtection}', scale: k),
            ),
            SizedBox(
              width: 132 * k,
              child: V21GameButton(
                label: 'EN İYİLERİ KORU',
                tone: V21ButtonTone.blue,
                size: V21ButtonSize.small,
                scale: k,
                onPressed: vm.autoProtectBest,
              ),
            ),
          ],
        ),
        SizedBox(height: 6 * k),
        Text(
          'Maçı kaybedersen korumaya ALMADIĞIN kartlardan ${GameRules.penaltyCardCount} tanesi rastgele seçilip '
          'kalıcı olarak rakibe geçer. Her galibiyette 1 koruma hakkı kazanırsın.',
          style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted, height: 1.4),
        ),
        SizedBox(height: 10 * k),
        LayoutBuilder(
          builder: (context, box) {
            const cols = 4;
            final gap = 8 * k;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final c in vm.deckCards)
                  _ProtectCard(
                    card: c,
                    width: w,
                    protected: vm.isProtected(c.userCardId),
                    onTap: () {
                      if (!vm.isProtected(c.userCardId) && !vm.canProtectMore) {
                        AppSnackBar.showInfo(context, 'Koruma hakkın doldu. Her galibiyette 1 hak kazanırsın.');
                        return;
                      }
                      vm.toggleProtection(c.userCardId);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProtectCard extends StatelessWidget {
  final InventoryCard card;
  final double width;
  final bool protected;
  final VoidCallback onTap;
  const _ProtectCard({required this.card, required this.width, required this.protected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: protected,
      label: '${card.fullName}, ${card.power} güç, ${protected ? 'korumada' : 'korumasız'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: protected ? 1 : 0.8,
              child: V21PlayerCard(
                name: card.fullName,
                position: card.position,
                tier: card.tier,
                power: card.power,
                seed: card.cardId,
                kitSeed: card.club ?? card.nationality,
                imageUrl: card.imageUrl,
                width: width,
                selected: protected,
              ),
            ),
            if (protected)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: EdgeInsets.all(width * 0.04),
                  decoration: const BoxDecoration(color: V21Colors.success, shape: BoxShape.circle),
                  child: Icon(Icons.shield_rounded, size: width * 0.16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// RAKİP ARAMA (hf3–hf6)
// ====================================================================
class _Search extends StatelessWidget {
  final MatchmakingViewModel vm;
  final V21SearchPhase phase;
  final double scale;
  final VoidCallback onTrain;
  const _Search({required this.vm, required this.phase, required this.scale, required this.onTrain});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = vm.searchDuration;
    final clock = '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final (title, text) = switch (phase) {
      V21SearchPhase.searching => ('RAKİP ARANIYOR', 'Benzer güçte rakip aranıyor'),
      V21SearchPhase.widened => ('ARAMA DEVAM EDİYOR', 'Arama aralığı genişletiliyor'),
      V21SearchPhase.notFound => (
        'HENÜZ RAKİP BULUNAMADI',
        'Şu anda uygun rakip yok. Arama sürüyor; istersen botla antrenman yap.',
      ),
      V21SearchPhase.offline => (
        'BAĞLANTI KONTROL EDİLİYOR',
        'Bağlantın yeniden deneniyor. Rakip arama otomatik sürüyor.',
      ),
    };
    final offerTraining = vm.trainingEnabled && phase != V21SearchPhase.searching && phase != V21SearchPhase.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _Ribbon(text: title, scale: k),
        ),
        SizedBox(height: 16 * k),
        Center(
          child: SizedBox.square(
            dimension: 230 * k,
            child: phase == V21SearchPhase.offline
                ? _OfflineBadge(scale: k)
                : _Radar(scale: k, sweeping: phase != V21SearchPhase.notFound),
          ),
        ),
        SizedBox(height: 16 * k),
        Center(
          child: Semantics(
            label: 'Arama süresi ${d.inSeconds} saniye',
            excludeSemantics: true,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18 * k, vertical: 6 * k),
              decoration: BoxDecoration(
                color: const Color(0xFF1B0F45),
                borderRadius: BorderRadius.circular(20 * k),
                border: Border.all(color: V21Colors.goldTop, width: 2 * k),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: V21Colors.goldTop, size: 22 * k),
                  SizedBox(width: 8 * k),
                  Text(clock, style: V21Type.title(26 * k)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 10 * k),
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: V21Type.label(14 * k, weight: FontWeight.w800, color: const Color(0xFFE6DBFF), height: 1.35),
          ),
        ),
        SizedBox(height: 6 * k),
        Text(
          vm.cardLossEnabled ? '${vm.protectedCardIds.length} kart korumada' : 'Kart kaybı yok',
          textAlign: TextAlign.center,
          style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.textMuted),
        ),
        SizedBox(height: 18 * k),
        if (offerTraining) ...[
          V21GameButton(
            label: 'BOTLA ANTRENMAN',
            tone: V21ButtonTone.green,
            leadingIcon: Icons.smart_toy_rounded,
            scale: k,
            semanticsLabel: 'Aramayı bırak, botla antrenman yap',
            onPressed: onTrain,
          ),
          SizedBox(height: 10 * k),
        ],
        V21GameButton(
          label: 'ARAMAYI İPTAL ET',
          tone: phase == V21SearchPhase.searching ? V21ButtonTone.blue : V21ButtonTone.red,
          size: V21ButtonSize.large,
          scale: k,
          onPressed: vm.cancelSearch,
        ),
      ],
    );
  }
}

class _Ribbon extends StatelessWidget {
  final String text;
  final double scale;
  const _Ribbon({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22 * k, vertical: 8 * k),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4B2A9E), Color(0xFF241056)],
        ),
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: V21Colors.goldTop, width: 3 * k),
        boxShadow: [BoxShadow(color: const Color(0x66FFC832), blurRadius: 14 * k)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
      ),
    );
  }
}

/// Radar: halkalar + dönen tarama kolu; ortada maskot kalkanı.
/// Animasyon azaltılmışsa kol durur.
class _Radar extends StatefulWidget {
  final double scale;
  final bool sweeping;
  const _Radar({required this.scale, required this.sweeping});

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Radar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.sweeping && !V21Motion.reduced(context) && !V21Motion.lowPower;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.scale;
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _RadarPainter(angle: _c.value * 2 * math.pi)),
            ),
          ),
          Center(
            child: SizedBox(
              width: 92 * k,
              height: 104 * k,
              child: ClipPath(
                clipper: const V21ShieldClipper(),
                child: ColoredBox(
                  color: V21Colors.goldTop,
                  child: Padding(
                    padding: EdgeInsets.all(4 * k),
                    child: ClipPath(
                      clipper: const V21ShieldClipper(),
                      child: ColoredBox(
                        color: const Color(0xFF4B23A8),
                        child: Image.asset(
                          V21Assets.victoryMascot,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.1, -0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double angle;
  _RadarPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF123A7A), Color(0xFF0B1E4A), Color(0xFF070F2E)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xAA4FC3FF)
      ..strokeWidth = 1.6;
    for (final f in [0.35, 0.62, 0.9]) {
      canvas.drawCircle(c, r * f, ring);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);
    // Tarama kolu: açık mavi yelpaze
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.9,
        endAngle: angle,
        colors: const [Color(0x0035E0FF), Color(0xAA35E0FF)],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.98), angle - 0.9, 0.9, true, sweep);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF35E0FF),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.angle != angle;
}

class _OfflineBadge extends StatelessWidget {
  final double scale;
  const _OfflineBadge({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: 150 * k,
          height: 150 * k,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF5B39C4), Color(0xFF241056)]),
            border: Border.all(color: V21Colors.goldTop, width: 4 * k),
            boxShadow: [BoxShadow(color: const Color(0x8835E0FF), blurRadius: 22 * k)],
          ),
          child: Icon(Icons.wifi_rounded, size: 80 * k, color: Colors.white),
        ),
      ),
    );
  }
}

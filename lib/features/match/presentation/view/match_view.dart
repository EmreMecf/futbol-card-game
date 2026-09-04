import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/error_snackbar.dart';
import '../viewmodel/match_view_model.dart';
import '../widgets/match_result_view.dart';
import '../widgets/match_widgets.dart';

/// Maç ekranı — oyunun kalbi.
///
/// ===================================================================
/// SEÇ, SONRA OYNA
/// ===================================================================
/// Kart dokunulur dokunulmaz oynanmıyor: önce SEÇİLİYOR, sonra ayrı
/// bir butonla onaylanıyor. Bir hamle geri alınamaz ve yanlış kart
/// oynamak maçı kaybettirebilir. Tek dokunuşla oynatmak, telefonda
/// listeyi kaydırırken yanlışlıkla kart oynanmasına yol açıyordu.
///
/// Onay adımı ayrıca kimyayı göstermek için yer açıyor: seçili kartın
/// altında "83 + 3 = 86" yazıyor, oyuncu gerçek gücü görerek karar
/// veriyor.
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

  /// Seçili kartın kimliği. Onaydan önce burada tutuluyor.
  String? _seciliKartId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MatchViewModel>();

    // Hata mesajını SnackBar ile göster (aynı hatayı iki kez gösterme)
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
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (vm.matchState == null) {
      return _HataEkrani(viewModel: vm);
    }

    if (vm.isOver) {
      return MatchResultView(
        result: vm.result,
        onClose: () => context.go(AppRoutes.home),
      );
    }

    return PopScope(
      // Maçtan kaçış yok: geri tuşu teslim olma onayı sorar
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _teslimOnayi(context, vm);
      },
      child: Scaffold(
        body: ResponsiveBuilder(
          builder: (context, boyut) => boyut.usesWideLayout
              ? _GenisMasa(state: this, viewModel: vm)
              : _DarMasa(state: this, viewModel: vm),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // SEÇİM VE HAMLE
  // ------------------------------------------------------------------

  /// Şu an seçili olan kart (hâlâ elde ve oynanabilir ise).
  HandCard? seciliKart(MatchViewModel vm) {
    final id = _seciliKartId;
    if (id == null) return null;
    for (final k in vm.playableCards) {
      if (k.userCardId == id) return k;
    }
    return null;
  }

  void kartSec(HandCard kart) {
    setState(() => _seciliKartId = kart.userCardId);
  }

  Future<void> seciliyiOyna(MatchViewModel vm) async {
    final kart = seciliKart(vm);
    if (kart == null) return;

    final basarili = await vm.playCard(kart);
    if (basarili && mounted) {
      setState(() => _seciliKartId = null);
    }
  }

  Future<void> _teslimOnayi(BuildContext context, MatchViewModel vm) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Teslim olmak istiyor musun?'),
        content: Text(
          'Teslim olursan maçı kaybetmiş sayılırsın ve korumaya '
          'almadığın ${GameRules.penaltyCardCount} kartın kalıcı olarak '
          'rakibe geçer.',
          style: AppTypography.bodyS,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Teslim ol',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (onay == true) await vm.surrender();
  }

  void teslimOnayiAc(BuildContext context, MatchViewModel vm) =>
      _teslimOnayi(context, vm);
}

// ====================================================================
// TELEFON YERLEŞİMİ
// ====================================================================
class _DarMasa extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;

  const _DarMasa({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _SahaZemini()),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, kisitlar) {
              // ==========================================================
              // NEDEN ÖLÇÜLER HESAPLANIYOR, SABİT YAZILMIYOR?
              // ==========================================================
              // Masada üst üste üç sıra var: rakibin kartı, sayaç,
              // benim yuvam. Sabit 108px kart genişliği verildiğinde bu
              // üçü 408px yer kaplıyor ve kısa ekranlarda (tarayıcı
              // penceresi, küçük telefonlar, yatay klavye açıkken)
              // taşıyordu.
              //
              // Maç ekranı KAYDIRILAMAZ olmalı: oyuncu 45 saniye içinde
              // karar verirken kaydırma yapmak zorunda kalmamalı. Bu
              // yüzden ölçüler ekrana uyduruluyor, ekran ölçülere değil.
              final yukseklik = kisitlar.maxHeight;

              // Üst bant + tur şeridi + aksiyon çubuğu için ayrılan pay
              const sabitler = 64.0 + 10 + 44 + 68 + 8;
              final kalan = (yukseklik - sabitler).clamp(240.0, 2000.0);

              // Kalanın yarısı ele, yarısı masaya
              final elYuksekligi = (kalan * 0.42).clamp(120.0, 210.0);
              final masaYuksekligi = kalan - elYuksekligi;

              // Masada iki kart + sayaç dikey sığmalı
              final masaKartYuksekligi =
                  ((masaYuksekligi - 92) / 2).clamp(72.0, 180.0);
              final masaKartGenisligi = masaKartYuksekligi / 1.5;
              final sayacBoyutu =
                  (masaYuksekligi * 0.24).clamp(64.0, 100.0);

              // Eldeki kart: rozet ve seçili kartın yükselmesi için
              // 34px pay bırakılıyor (bkz. _Elim).
              final elKartGenisligi =
                  ((elYuksekligi - 34) / 1.5).clamp(72.0, 116.0);

              return Column(
                children: [
                  _UstBant(viewModel: viewModel, compact: true),
                  const SizedBox(height: 10),
                  _TurSeridi(viewModel: viewModel),

                  // ---- MASA ----
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RakipYuvasi(
                            viewModel: viewModel,
                            width: masaKartGenisligi,
                          ),
                          _MasaOrtasi(
                            viewModel: viewModel,
                            ringSize: sayacBoyutu,
                          ),
                          _BenimYuvam(
                            state: state,
                            viewModel: viewModel,
                            width: masaKartGenisligi,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---- ELİM ----
                  _Elim(
                    state: state,
                    viewModel: viewModel,
                    cardWidth: elKartGenisligi,
                  ),
                  _AksiyonCubugu(state: state, viewModel: viewModel),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// MASAÜSTÜ YERLEŞİMİ
// ====================================================================
class _GenisMasa extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;

  const _GenisMasa({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _SahaZemini()),
        SafeArea(
          child: Column(
            children: [
              _UstBant(viewModel: viewModel, compact: false),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- SOL: TUR GEÇMİŞİ ----
                    SizedBox(
                      width: 300,
                      child: _TurGecmisi(viewModel: viewModel),
                    ),

                    // ---- ORTA: MASA ----
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _TurSeridi(viewModel: viewModel),
                          ),
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _RakipYuvasi(
                                    viewModel: viewModel,
                                    width: 150,
                                  ),
                                  const SizedBox(width: 36),
                                  _MasaOrtasi(
                                    viewModel: viewModel,
                                    ringSize: 108,
                                    vertical: true,
                                  ),
                                  const SizedBox(width: 36),
                                  _BenimYuvam(
                                    state: state,
                                    viewModel: viewModel,
                                    width: 150,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _Elim(
                            state: state,
                            viewModel: viewModel,
                            cardWidth: 120,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // ---- SAĞ: DURUM VE AKSİYON ----
                    SizedBox(
                      width: 300,
                      child: _YanPanel(state: state, viewModel: viewModel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// SAHA ZEMİNİ
// ====================================================================
class _SahaZemini extends StatelessWidget {
  const _SahaZemini();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.9,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.42),
            AppColors.background,
          ],
        ),
      ),
      child: const CustomPaint(
        painter: _MasaCizgileriPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _MasaCizgileriPainter extends CustomPainter {
  const _MasaCizgileriPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final firca = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Orta çizgi ve santra: masanın iki yarısı görsel olarak ayrılsın
    canvas.drawLine(
      Offset(size.width * 0.06, size.height / 2),
      Offset(size.width * 0.94, size.height / 2),
      firca,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.16,
      firca,
    );
  }

  @override
  bool shouldRepaint(_MasaCizgileriPainter oldDelegate) => false;
}

// ====================================================================
// ÜST BANT
// ====================================================================
class _UstBant extends StatelessWidget {
  final MatchViewModel viewModel;
  final bool compact;

  const _UstBant({required this.viewModel, required this.compact});

  @override
  Widget build(BuildContext context) {
    final durum = viewModel.matchState!;
    final rakip = durum.opponent;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 32, 12, compact ? 16 : 32, 12),
      decoration: BoxDecoration(
        color: AppColors.sidebar.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceLight),
        ),
      ),
      child: Row(
        children: [
          _OyuncuRozeti(
            name: rakip?.username ?? 'Rakip',
            detail: '${durum.opponentCardsLeft} kart · '
                '${rakip?.mmr ?? 0} puan',
            color: AppColors.danger,
          ),
          const Spacer(),

          // ---- SKOR ----
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              children: [
                Text(
                  '${durum.opponentScore}',
                  style: AppTypography.display(
                    size: compact ? 24 : 32,
                    weight: FontWeight.w900,
                    color: AppColors.danger,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '–',
                    style: AppTypography.display(
                      size: compact ? 16 : 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${durum.myScore}',
                  style: AppTypography.display(
                    size: compact ? 24 : 32,
                    weight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          if (!compact) ...[
            const Spacer(),
            _OyuncuRozeti(
              name: 'Sen',
              detail: '${durum.myCardsLeft} kart',
              color: AppColors.primary,
              reversed: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _OyuncuRozeti extends StatelessWidget {
  final String name;
  final String detail;
  final Color color;
  final bool reversed;

  const _OyuncuRozeti({
    required this.name,
    required this.detail,
    required this.color,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: AppTypography.display(size: 18, weight: FontWeight.w900),
        ),
      ),
    );

    final metin = Column(
      crossAxisAlignment:
          reversed ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(size: 14, weight: FontWeight.w800),
        ),
        Text(detail, style: AppTypography.bodyXS),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: reversed
          ? [Flexible(child: metin), const SizedBox(width: 10), avatar]
          : [avatar, const SizedBox(width: 10), Flexible(child: metin)],
    );
  }
}

// ====================================================================
// TUR ŞERİDİ
// ====================================================================
class _TurSeridi extends StatelessWidget {
  final MatchViewModel viewModel;

  const _TurSeridi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final durum = viewModel.matchState!;
    final zorunlu = viewModel.requiredPosition;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Text(
            'TUR ${durum.roundNumber}',
            style: AppTypography.display(size: 16, weight: FontWeight.w800),
          ),
          Text(
            '/${GameRules.squadSize}',
            style: AppTypography.display(
              size: 16,
              weight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: AppColors.surfaceLight),
          const SizedBox(width: 12),

          if (zorunlu != null)
            _PozisyonRozeti(position: zorunlu)
          else
            Flexible(
              child: Text(
                viewModel.isMyTurn ? 'Pozisyonu sen seçiyorsun' : 'Tur açılıyor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 12.5, weight: FontWeight.w800),
              ),
            ),

          const Spacer(),
          _SiraGostergesi(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _PozisyonRozeti extends StatelessWidget {
  final CardPosition position;

  const _PozisyonRozeti({required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        position.label.toUpperCase(),
        style: AppTypography.display(
          size: 12,
          weight: FontWeight.w900,
          color: AppColors.background,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SiraGostergesi extends StatelessWidget {
  final MatchViewModel viewModel;

  const _SiraGostergesi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final benim = viewModel.isMyTurn;
    final renk = benim ? AppColors.success : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: renk,
            shape: BoxShape.circle,
            boxShadow: benim
                ? [BoxShadow(color: renk.withValues(alpha: 0.8), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          benim ? 'Sıra sende' : 'Rakip düşünüyor',
          style: AppTypography.body(
            size: 11.5,
            weight: FontWeight.w800,
            color: renk,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// MASA PARÇALARI
// ====================================================================
class _RakipYuvasi extends StatelessWidget {
  final MatchViewModel viewModel;
  final double width;

  const _RakipYuvasi({required this.viewModel, required this.width});

  @override
  Widget build(BuildContext context) {
    final hamle = viewModel.opponentTableMove;
    final tur = viewModel.lastResolvedRound;

    if (hamle == null) {
      return FaceDownCard(width: width, label: 'Bekleniyor');
    }

    return PlayedMoveCard(
      move: hamle,
      width: width,
      isWinner: tur != null &&
          tur.roundNumber == hamle.roundNumber &&
          tur.winnerId != null &&
          tur.winnerId != viewModel.myUserId,
    );
  }
}

class _BenimYuvam extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;
  final double width;

  const _BenimYuvam({
    required this.state,
    required this.viewModel,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hamle = viewModel.myTableMove;
    final tur = viewModel.lastResolvedRound;

    if (hamle != null) {
      return PlayedMoveCard(
        move: hamle,
        width: width,
        isWinner: tur != null &&
            tur.roundNumber == hamle.roundNumber &&
            tur.winnerId == viewModel.myUserId,
      );
    }

    final zorunlu = viewModel.requiredPosition;
    final mesaj = !viewModel.isMyTurn
        ? 'Sıra rakipte'
        : viewModel.mustPass
            ? 'Bu pozisyonda kartın yok'
            : zorunlu != null
                ? '${zorunlu.label} kartı seç'
                : 'Bir kart seç';

    return EmptyPlaySlot(
      width: width,
      message: mesaj,
      isActive: viewModel.isMyTurn && !viewModel.mustPass,
    );
  }
}

/// Masanın ortası: sayaç, VS ve biriken kart sayısı.
class _MasaOrtasi extends StatelessWidget {
  final MatchViewModel viewModel;
  final double ringSize;
  final bool vertical;

  const _MasaOrtasi({
    required this.viewModel,
    required this.ringSize,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final durum = viewModel.matchState!;

    final sayac = TurnRing(
      remaining: viewModel.remainingTime,
      isMyTurn: viewModel.isMyTurn,
      isUrgent: viewModel.isTimeRunningOut,
      size: ringSize,
    );

    final pot = durum.potCount > 0
        ? _PotRozeti(count: durum.potCount)
        : const SizedBox.shrink();

    if (!vertical) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: _SonTurOzeti(viewModel: viewModel)),
          const SizedBox(width: 16),
          sayac,
          const SizedBox(width: 16),
          Flexible(child: Center(child: pot)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sayac,
        const SizedBox(height: 12),
        Text(
          'VS',
          style: AppTypography.display(
            size: 24,
            weight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        pot,
      ],
    );
  }
}

/// Beraberlikten masada biriken kartlar.
class _PotRozeti extends StatelessWidget {
  final int count;

  const _PotRozeti({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Masada $count kart',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Biten son turun sonucu.
class _SonTurOzeti extends StatelessWidget {
  final MatchViewModel viewModel;

  const _SonTurOzeti({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final tur = viewModel.lastResolvedRound;
    if (tur == null) return const SizedBox.shrink();

    final (metin, renk) = tur.isDraw
        ? ('Berabere', AppColors.warning)
        : tur.winnerId == viewModel.myUserId
            ? ('Turu kazandın', AppColors.success)
            : ('Turu kaybettin', AppColors.danger);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SON TUR', style: AppTypography.label),
        const SizedBox(height: 2),
        Text(
          metin,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w800,
            color: renk,
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// ELİM
// ====================================================================
class _Elim extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;
  final double cardWidth;

  const _Elim({
    required this.state,
    required this.viewModel,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final kartlar = viewModel.hand.where((k) => !k.isPlayed).toList();
    if (kartlar.isEmpty) return const SizedBox.shrink();

    final zorunlu = viewModel.requiredPosition;
    final secili = state.seciliKart(viewModel);

    return SizedBox(
      // Seçili kart 14px yukarı kalkıyor ve rozet 9px taşıyor;
      // yükseklik bunlara yer bırakacak kadar fazla verilmeli.
      height: cardWidth * 1.5 + 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: kartlar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final kart = kartlar[index];
          final oynanabilir = zorunlu == null || kart.position == zorunlu;
          final etkin = viewModel.isMyTurn &&
              oynanabilir &&
              !viewModel.isSubmittingMove &&
              viewModel.myTableMove == null;

          return HandCardTile(
            key: ValueKey(kart.userCardId),
            card: kart,
            width: cardWidth,
            isPlayable: oynanabilir,
            isSelected: secili?.userCardId == kart.userCardId,
            isEnabled: etkin,
            onTap: etkin ? () => state.kartSec(kart) : null,
          );
        },
      ),
    );
  }
}

// ====================================================================
// AKSİYON ÇUBUĞU (telefon)
// ====================================================================
class _AksiyonCubugu extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;

  const _AksiyonCubugu({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    // Pas geçmek zorundaysa tek ve net bir buton kalır
    if (viewModel.mustPass && viewModel.isMyTurn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ElevatedButton.icon(
          onPressed: viewModel.isSubmittingMove ? null : viewModel.pass,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('PAS GEÇ · TURU KAYBET'),
        ),
      );
    }

    final secili = state.seciliKart(viewModel);
    final oynanabilir = secili != null &&
        viewModel.isMyTurn &&
        !viewModel.isSubmittingMove &&
        viewModel.myTableMove == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: oynanabilir ? () => state.seciliyiOyna(viewModel) : null,
              child: viewModel.isSubmittingMove
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      secili == null
                          ? 'BİR KART SEÇ'
                          : '${secili.fullName.toUpperCase()} · '
                              '${secili.effectivePower}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            height: 52,
            child: OutlinedButton(
              onPressed: () => state.teslimOnayiAc(context, viewModel),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: AppColors.danger,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// MASAÜSTÜ SAĞ PANEL
// ====================================================================
class _YanPanel extends StatelessWidget {
  final _MatchBodyState state;
  final MatchViewModel viewModel;

  const _YanPanel({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final secili = state.seciliKart(viewModel);
    final durum = viewModel.matchState!;
    final oynanabilir = secili != null &&
        viewModel.isMyTurn &&
        !viewModel.isSubmittingMove &&
        viewModel.myTableMove == null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SEÇİLİ KART', style: AppTypography.label),
          const SizedBox(height: 10),
          _SeciliKartPaneli(card: secili),

          const SizedBox(height: 16),
          Text('MAÇ DURUMU', style: AppTypography.label),
          const SizedBox(height: 10),
          _DurumPaneli(state: durum, viewModel: viewModel),

          const Spacer(),

          if (viewModel.mustPass && viewModel.isMyTurn)
            ElevatedButton.icon(
              onPressed: viewModel.isSubmittingMove ? null : viewModel.pass,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('PAS GEÇ'),
            )
          else
            ElevatedButton(
              onPressed: oynanabilir ? () => state.seciliyiOyna(viewModel) : null,
              child: viewModel.isSubmittingMove
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Text('KARTI OYNA'),
            ),

          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => state.teslimOnayiAc(context, viewModel),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
            ),
            icon: const Icon(Icons.flag_rounded, size: 18, color: AppColors.danger),
            label: const Text(
              'TESLİM OL',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seçili kartın güç dökümü: "83 + 3 kimya = 86".
class _SeciliKartPaneli extends StatelessWidget {
  final HandCard? card;

  const _SeciliKartPaneli({required this.card});

  @override
  Widget build(BuildContext context) {
    final kart = card;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: kart == null
          ? Text(
              'Elinden bir kart seç. Seçtiğin kartın maçtaki gerçek '
              'gücü burada görünür.',
              style: AppTypography.bodyS,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kart.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: 26,
                    weight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${kart.tier.label} · ${kart.position.label}'
                  '${kart.club != null ? ' · ${kart.club}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXS,
                ),
                const SizedBox(height: 12),

                // ---- GÜÇ DÖKÜMÜ ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${kart.power}',
                      style: AppTypography.display(
                        size: 24,
                        weight: FontWeight.w900,
                      ),
                    ),
                    if (kart.hasChemistry) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+ ${kart.chemistry}',
                        style: AppTypography.display(
                          size: 18,
                          weight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '=',
                        style: AppTypography.display(
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${kart.effectivePower}',
                        style: AppTypography.display(
                          size: 30,
                          weight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),

                if (kart.isLegend) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Legend: gücüne bakılmaksızın alt dört seviyeyi yener.',
                    style: AppTypography.body(
                      size: 11.5,
                      color: AppColors.tierLegend,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DurumPaneli extends StatelessWidget {
  final MatchState state;
  final MatchViewModel viewModel;

  const _DurumPaneli({required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          _satir('Kalan tur', '${GameRules.squadSize - state.roundNumber + 1}'),
          const SizedBox(height: 8),
          _satir('Elindeki kart', '${state.myCardsLeft}'),
          const SizedBox(height: 8),
          _satir('Rakibin kartı', '${state.opponentCardsLeft}'),
          if (state.potCount > 0) ...[
            const Divider(height: 20),
            Text(
              'Beraberlikten masada ${state.potCount} kart birikti. '
              'Sıradaki turu kazanan hepsini alır.',
              style: AppTypography.body(size: 11.5, color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _satir(String etiket, String deger) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiket, style: AppTypography.bodyS),
        Text(
          deger,
          style: AppTypography.display(size: 17, weight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ====================================================================
// TUR GEÇMİŞİ (masaüstü sol sütun)
// ====================================================================
class _TurGecmisi extends StatelessWidget {
  final MatchViewModel viewModel;

  const _TurGecmisi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final turlar = viewModel.history.rounds;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TUR GEÇMİŞİ', style: AppTypography.label),
          const SizedBox(height: 10),
          Expanded(
            child: turlar.isEmpty
                ? Text('Henüz tur bitmedi.', style: AppTypography.bodyS)
                : ListView.separated(
                    itemCount: turlar.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _TurSatiri(
                      round: turlar[i],
                      myUserId: viewModel.myUserId,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TurSatiri extends StatelessWidget {
  final MatchRound round;
  final String? myUserId;

  const _TurSatiri({required this.round, required this.myUserId});

  @override
  Widget build(BuildContext context) {
    final renk = round.isDraw
        ? AppColors.warning
        : round.winnerId == myUserId
            ? AppColors.success
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${round.roundNumber}',
              style: AppTypography.display(
                size: 14,
                weight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              round.isDraw
                  ? 'Berabere'
                  : round.winnerId == myUserId
                      ? 'Kazandın'
                      : 'Kaybettin',
              style: AppTypography.body(
                size: 12.5,
                weight: FontWeight.w800,
                color: renk,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
        ],
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maç')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(
                  viewModel.errorMessage ?? 'Maç yüklenemedi.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyM,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: viewModel.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('TEKRAR DENE'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Ana sayfaya dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

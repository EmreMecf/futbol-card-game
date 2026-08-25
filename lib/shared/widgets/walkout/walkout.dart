/// WALKOUT — görkemli paket açılış sahnesi ve kademeli kart açılışları.
///
/// Kullanım:
/// ```dart
/// // Diamond/Legend
/// WalkoutScreen(card: kart, onContinue: viewModel.next)
///
/// // Bronz/Gümüş/Altın
/// CardFlipReveal(card: kart, style: viewModel.currentStyle)
/// ```
///
/// PERFORMANS NOTU:
/// Bu klasördeki her görsel efekt tek bir `CustomPainter` üzerinde
/// çalışır; parçacık başına widget YOKTUR. Konfeti 120 parçacığı tek
/// painter'da çizer, ışık huzmeleri degrade ile yapılır (blur yok).
/// Böylece sahne orta seviye telefonlarda da 60 FPS'te akar.
library;

export 'card_flip_reveal.dart';
export 'club_crest.dart';
export 'confetti_overlay.dart';
export 'nation_flag.dart';
export 'spotlight_backdrop.dart';
export 'walkout_screen.dart';

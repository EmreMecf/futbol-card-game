/// FAZ 5 — Taktik ve enerji sistemi PROTOTİPİ.
///
/// GERÇEK MAÇLARA BAĞLI DEĞİL. Ne Flutter uygulaması ne Dart sunucusu
/// bu paketi kullanıyor. Amaç: taktik fikrinin dengesini binlerce
/// simüle maçla ölçmek ve kullanıcıya rapor sunmak (MD bölüm 7:
/// "Önce ayrı bir prototipte test et ve sonuçlarını bana sun").
///
/// Rapor üretmek için:
///   cd packages/tactics_prototype
///   dart run bin/simulate.dart
library;

export 'src/balance.dart';
export 'src/comparisons.dart';
export 'src/economy.dart';
export 'src/matchmaking.dart';
export 'src/simulation.dart';
export 'src/tactics.dart';

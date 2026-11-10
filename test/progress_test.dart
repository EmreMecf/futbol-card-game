import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/progress/domain/progress_repository.dart';
import 'package:futbol_card/features/progress/presentation/viewmodel/progress_view_model.dart';
import 'package:shared_models/shared_models.dart';

import 'goldens/sahte_veri.dart';

/// Ekonomi V2 FAZ 2: futbolcu seviyesi ViewModel'i.
class _Depo extends GoldenProgressRepo {
  final anahtarlar = <String>[];
  final hatalar = <AppException>[];

  @override
  Future<Result<LevelUpResult>> levelUp(String cardId,
      {required bool useJokers, bool useDiscount = false, required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    if (hatalar.isNotEmpty) return Failure(hatalar.removeAt(0));
    return Success(LevelUpResult(cardId: cardId, level: 4, coinsSpent: 250, coinsAfter: 2200));
  }

  @override
  Future<Result<ConvertCopiesResult>> convert(String cardId, int count, {required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    return Success(ConvertCopiesResult(cardId: cardId, converted: count, copies: count, ownedCopies: 2));
  }
}

void main() {
  late _Depo depo;
  late ProgressViewModel vm;

  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));
  setUp(() async {
    depo = _Depo();
    vm = ProgressViewModel(depo);
    await vm.load();
  });

  test('hazır olanlar listenin başında', () {
    final ilk = vm.visibleItems.take(2).map((i) => i.level).toList();
    expect(ilk, [4, 3], reason: 'jokerle (4) ve kopyayla (3) hazır olanlar önce');
    vm.setOnlyReady(true);
    expect(vm.visibleItems.length, 2);
  });

  test('ağ hatasında aynı hedef seviye AYNI anahtarla tekrar (altın iki kez düşmez)', () async {
    final item = kGoldenProgress.items.first;
    depo.hatalar.add(const AppException.network());
    expect(await vm.levelUp(item), isFalse);
    expect(await vm.levelUp(item), isTrue);
    expect(depo.anahtarlar[0], depo.anahtarlar[1]);
    expect(vm.lastLevelUp?.level, 4);
  });

  test('kural reddi: yeni anahtar + Türkçe mesaj', () async {
    final item = kGoldenProgress.items.first;
    depo.hatalar.add(const AppException(message: 'x', technicalDetail: 'not_enough_coins'));
    expect(await vm.levelUp(item), isFalse);
    expect(vm.actionError, 'Yeterli altın yok.');
    await vm.levelUp(item);
    expect(depo.anahtarlar[0], isNot(depo.anahtarlar[1]));
  });

  test('model: kopya/joker/altın koşulları', () {
    final o = kGoldenProgress;
    final kopyali = o.items[0], jokerli = o.items[1], eksik = o.items[3], tavan = o.items[4];
    expect(kopyali.canLevelUp(o.coins), isTrue);
    expect(jokerli.canLevelUp(o.coins), isFalse);
    expect(jokerli.canLevelWithJokers(o.coins), isTrue);
    expect(eksik.canLevelUp(o.coins), isFalse);
    expect(tavan.isMax, isTrue);
    expect(kopyali.canLevelUp(100), isFalse, reason: 'altın yetmezse olmaz');
  });

  test('hata kodları Türkçe', () {
    expect(progressErrorMessage('max_level', 'x'), 'Futbolcu en yüksek seviyede.');
    expect(progressErrorMessage('bilinmeyen', 'sunucu'), 'sunucu');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/chests/domain/chest_messages.dart';
import 'package:futbol_card/features/chests/domain/chest_repository.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/ui_v21/screens/deck/v21_emergency_banner.dart';
import 'package:shared_models/shared_models.dart';

import 'goldens/sahte_veri.dart';

/// Ekonomi V2 FAZ 1: sandık ViewModel'i ve acil kadro.
class _KayitliDepo extends GoldenChestRepo {
  final anahtarlar = <String>[];
  final hatalar = <AppException>[];
  int acmaSayisi = 0;

  @override
  Future<Result<ChestOpenResult>> open(String chestId, {required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    acmaSayisi++;
    if (hatalar.isNotEmpty) return Failure(hatalar.removeAt(0));
    return Success(kGoldenChestOpen);
  }

  @override
  Future<Result<Chest>> startUnlock(String chestId, {required String idempotencyKey}) async {
    anahtarlar.add(idempotencyKey);
    return Success(goldenChest(chestId, ChestTypes.gold, status: 'unlocking', slot: 2));
  }

  int talep = 0;
  @override
  Future<Result<EmergencySquadClaim>> claimEmergencySquad({required String idempotencyKey}) async {
    talep++;
    anahtarlar.add(idempotencyKey);
    return Success(EmergencySquadClaim(
      cards: [goldenChestCard(3, 'new')],
      status: EmergencySquadStatus(enabled: true, serverTime: kGoldenServerTime),
    ));
  }
}

void main() {
  late _KayitliDepo depo;
  late ChestsViewModel vm;

  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  setUp(() {
    depo = _KayitliDepo();
    vm = ChestsViewModel(depo);
  });
  tearDown(() => vm.dispose());

  test('yükler; sayaç sunucu saatine göre (cihaz saati değil)', () async {
    await vm.load();
    expect(vm.isEnabled, isTrue);
    final c = vm.inventory!.slot(1)!;
    final kalan = vm.remaining(c)!;
    // 1:23:45 (+0,5 sn) kaldı; test birkaç ms sürer
    expect(kalan.inSeconds, inInclusiveRange(5024, 5025));
  });

  test('açma: sonuç saklanır, aynı eylem ağ hatasında AYNI anahtarla tekrar', () async {
    await vm.load();
    final c = vm.inventory!.instant.first;
    depo.hatalar.add(const AppException.network());
    expect(await vm.open(c), isFalse);
    expect(await vm.open(c), isTrue);
    expect(depo.anahtarlar[0], depo.anahtarlar[1], reason: 'ağ hatası sonrası aynı anahtar: ödül iki kez verilmez');
    expect(vm.lastOpening, kGoldenChestOpen);
  });

  test('kural reddinden sonra yeni eylem YENİ anahtar alır; mesaj Türkçe', () async {
    await vm.load();
    final c = vm.inventory!.instant.first;
    depo.hatalar.add(const AppException(message: 'chest x', type: AppErrorType.unknown, technicalDetail: 'chest_not_ready'));
    expect(await vm.open(c), isFalse);
    expect(vm.actionError, 'Sandık henüz hazır değil.');
    await vm.open(c);
    expect(depo.anahtarlar[0], isNot(depo.anahtarlar[1]));
  });

  test('başarılı eylemden sonra aynı sandığın sonraki eylemi yeni anahtar', () async {
    await vm.load();
    final c = vm.inventory!.slot(2)!;
    await vm.startUnlock(c);
    await vm.startUnlock(c);
    expect(depo.anahtarlar.toSet().length, 2);
  });

  test('hata kodları Türkçe mesaja çevrilir', () {
    AppException e(String kod) => AppException(message: 'x', technicalDetail: kod);
    expect(chestErrorMessage(e('slots_full')), 'Boş yuva yok. Önce bir sandık aç.');
    expect(chestErrorMessage(e('chest_already_unlocking')), contains('yalnız bir'));
    expect(chestErrorMessage(e('bilinmeyen')), 'x', reason: 'bilinmeyen kod: sunucu mesajı');
  });


}

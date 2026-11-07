import 'package:shared_models/shared_models.dart';

import '../../../core/base/base_view_model.dart';
import '../../../core/base/view_state.dart';
import '../../match/domain/clash_event.dart';
import '../../match/presentation/arena/character_stage/character_stage.dart';
import '../data/character_repository.dart';

/// Tek karakter prototipi (Aşama A1) önizlemesinin beyni.
class CharacterPreviewViewModel extends BaseViewModel {
  final CharacterRepository _repo;

  /// Önizlenen karakter (Aşama A1 örnek forveti)
  static const prototypeSlug = 'kaelen-brisvoy';

  CharacterPreviewViewModel(this._repo);

  CharacterCardData? _veri;
  CharacterCardData? get data => _veri;

  Future<void> load([String slug = prototypeSlug]) async {
    final v = await run(() => _repo.fetchCard(slug), loadingState: ViewState.loading);
    if (v != null) _veri = v;
    safeNotify();
  }

  /// Arenada hangi katman kullanılacak (gerekçeleriyle)
  RendererDecision? get renderer =>
      _veri == null ? null : selectRenderer(_veri!.presentation);

  /// Önizleme çatışması: karakter, aynı mevkiden bir RAKİP YER TUTUCU
  /// karta karşı kazanır. Sonuç burada SABİT bir gösterimdir; gerçek
  /// maçta sonucu her zaman sunucu belirler.
  ClashEvent? get demoClash {
    final v = _veri;
    final p = v?.proposal;
    if (v == null || p == null) return null;
    final mevki = v.character.primaryPosition;
    return ClashEvent(
      roundNumber: 1,
      outcome: ClashOutcome.win,
      position: mevki,
      cardsCollected: 2,
      myMove: MatchMove(
        roundNumber: 1,
        userId: 'onizleme',
        isMine: true,
        isLead: true,
        position: mevki,
        tier: p.tier,
        power: p.power,
        fullName: v.character.displayName,
      ),
      opponentMove: MatchMove(
        roundNumber: 1,
        userId: 'rakip',
        position: mevki,
        tier: CardTier.silver,
        power: 70,
        fullName: 'Rakip (yer tutucu)',
      ),
    );
  }

  Choreography? get choreography {
    final e = demoClash;
    return e == null ? null : choreographFor(e);
  }
}

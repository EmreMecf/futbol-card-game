import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../domain/repositories/sbc_repository.dart';

/// Gorev listesi ekraninin beyni.
class SbcListViewModel extends BaseViewModel {
  final SbcRepository _repository;

  SbcListViewModel(this._repository);

  List<SbcChallenge> _gorevler = [];
  List<SbcChallenge> get challenges => _gorevler;

  /// Kategoriye gore gruplanmis gorevler (ekranda basliklarla gosterilir)
  Map<String, List<SbcChallenge>> get grouped {
    final gruplar = <String, List<SbcChallenge>>{};
    for (final g in _gorevler) {
      gruplar.putIfAbsent(g.categoryLabel, () => []).add(g);
    }
    return gruplar;
  }

  int get completedCount => _gorevler.where((g) => g.isCompleted).length;
  int get availableCount => _gorevler.where((g) => !g.isCompleted).length;

  Future<void> load() async {
    final liste = await run(
      () => _repository.fetchChallenges(),
      loadingState: ViewState.loading,
    );

    if (liste != null) {
      _gorevler = liste;
      safeNotify();
    }
  }
}

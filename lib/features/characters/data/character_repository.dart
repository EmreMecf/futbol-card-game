import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';

/// `GET /api/characters/SLUG` cevabı
class CharacterCardData {
  final Character character;

  /// Denge Motoru önerisi (oyuna girmemiş). Yoksa kart çizilemez.
  final CharacterCardProposal? proposal;
  final CharacterPresentation presentation;
  final String? clubName;
  final String? regionName;

  const CharacterCardData({
    required this.character,
    required this.proposal,
    required this.presentation,
    this.clubName,
    this.regionName,
  });

  factory CharacterCardData.fromJson(Map<String, dynamic> j) => CharacterCardData(
        character: Character.fromJson(j['character'] as Map<String, dynamic>),
        proposal: j['proposal'] == null
            ? null
            : CharacterCardProposal.fromJson(j['proposal'] as Map<String, dynamic>),
        presentation:
            CharacterPresentation.fromJson(j['presentation'] as Map<String, dynamic>),
        clubName: j['club_name'] as String?,
        regionName: j['region_name'] as String?,
      );
}

abstract class CharacterRepository {
  Future<Result<CharacterCardData>> fetchCard(String slug);
}

class CharacterRepositoryImpl implements CharacterRepository {
  final ApiClient _api;
  CharacterRepositoryImpl(this._api);

  @override
  Future<Result<CharacterCardData>> fetchCard(String slug) => Result.guard(
        () async => CharacterCardData.fromJson(await _api.get('/characters/$slug')),
      );
}

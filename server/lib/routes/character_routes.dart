import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Özgün karakter uçları (Aşama A1 prototipi).
///
///   GET /api/characters/SLUG  -> karakter + Denge Motoru önerisi +
///                                  sunum durumu (eksik varlıklar dahil)
///
/// TASLAK karakterler sadece GELİŞTİRME ortamında döner. Üretimde
/// yalnızca yayınlanmış (insan onaylı) karakterler görünür.
Router characterRoutes(Database db) {
  final router = Router();

  router.get('/<slug>', (Request request, String slug) async {
    requireUserId(request);
    final ham = await db.scalar(
      'select get_character_card(@slug, @taslak)',
      params: {'slug': slug, 'taslak': !Env.isProduction},
    );
    final m = RowMappers.asMap(ham);

    // Modellerden geçirerek doğrula: eksik/yanlış alan burada yakalanır
    final karakter = Character.fromJson(RowMappers.asMap(m['character']));
    final oneri = m['proposal'] == null
        ? null
        : CharacterCardProposal.fromJson(RowMappers.asMap(m['proposal']));
    final sunum = CharacterPresentation.fromJson(RowMappers.asMap(m['presentation']));

    return jsonOk({
      'character': karakter.toJson(),
      'proposal': oneri?.toJson(),
      'presentation': sunum.toJson(),
      'club_name': m['club_name'],
      'region_name': m['region_name'],
    });
  });

  return router;
}

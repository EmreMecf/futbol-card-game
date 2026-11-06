import 'dart:convert';
import 'dart:io';

import 'package:content_pipeline/content_pipeline.dart';
import 'package:shared_models/shared_models.dart';

/// Karakter üretim aracı.
///
/// ÇEVRİMDIŞI (ücretsiz): hazır bir kimlik JSON'unu hattan geçirir.
///   dart run bin/uret.dart --girdi ornekler/kaelen_brisvoy.json \
///       --kimlik UUID --sql ../../database/migrations/026_ornek.sql
///
/// CANLI (ÜCRETLİ, Claude API): yeni kimlik üretir.
///   ANTHROPIC_API_KEY ortam değişkeni VE --onay bayrağı gerekir.
///   dart run bin/uret.dart --canli --onay --sira 2
///
/// Her iki yolda da çıktı TASLAK'tır; insan onayı olmadan yayınlanmaz.
Future<void> main(List<String> args) async {
  String? arg(String ad) {
    final i = args.indexOf(ad);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  const dunya = FictionalWorld(
    regionCode: 'SLV',
    regionName: 'Selvarra Kıyıları',
    leagueCode: 'SLV_L',
    leagueName: 'Selvarra Ligi',
    clubCode: 'LRF',
    clubName: 'Liman Rüzgârı FK',
    primaryColor: '#22D3EE',
    secondaryColor: '#0F172A',
  );
  final yuva = CatalogSlot(
    CardPosition.fromCode(arg('--mevki') ?? 'FWD'),
    CardTier.fromCode(arg('--seviye') ?? 'gold'),
    int.parse(arg('--sira') ?? '1'),
  );

  Map<String, dynamic> ham;
  String uretici, olusturan;
  String? model;

  if (args.contains('--canli')) {
    final ag = HttpClaudeTransport.fromEnvironment();
    if (ag == null) {
      stderr.writeln('ANTHROPIC_API_KEY ortam değişkeni yok. Anahtar diske yazılmaz; '
          'sadece ortam değişkeninden okunur.');
      exitCode = 2;
      return;
    }
    // Kaba maliyet: ~1.5K girdi + ~3K çıktı jetonu (düşünme dahil) / karakter
    stdout.writeln('Tahmini maliyet: ~0,07 USD / karakter '
        '(${CharacterGenerator.model}: 4 USD girdi, 20 USD çıktı / milyon jeton).');
    if (!args.contains('--onay')) {
      stderr.writeln('ÜCRETLİ işlem. Devam etmek için --onay ekleyin.');
      exitCode = 2;
      return;
    }
    ham = await CharacterGenerator(ag).generate(yuva, dunya);
    uretici = 'claude-api';
    olusturan = 'ai';
    model = CharacterGenerator.model;
  } else {
    final girdi = arg('--girdi');
    if (girdi == null) {
      stderr.writeln('Kullanım: --girdi <kimlik.json>  ya da  --canli --onay');
      exitCode = 2;
      return;
    }
    ham = jsonDecode(File(girdi).readAsStringSync()) as Map<String, dynamic>;
    uretici = arg('--uretici') ?? 'elle';
    olusturan = arg('--olusturan') ?? 'human';
    model = arg('--model');
  }

  final sonuc = CharacterPipeline().process(
    ham,
    slot: yuva,
    world: dunya,
    characterId: arg('--kimlik') ?? _uuid(),
    catalogVersion: 'v2-ozgun',
    createdBy: olusturan,
    generator: uretici,
    generatorModel: model,
  );

  for (final u in sonuc.validation.warnings) {
    stdout.writeln('UYARI: $u');
  }
  if (!sonuc.ok) {
    for (final h in sonuc.validation.errors) {
      stderr.writeln('HATA: $h');
    }
    stderr.writeln('Doğrulama geçmedi; hiçbir şey yazılmadı.');
    exitCode = 1;
    return;
  }

  final p = sonuc.proposal!;
  final a = p.attributes;
  stdout.writeln('GEÇTİ: ${sonuc.character!.displayName} (${sonuc.character!.slug})');
  stdout.writeln('Denge Motoru (${p.balanceEngineVersion}): ${p.tier.label} ${p.power} | '
      'ŞUT ${a.shooting} HIZ ${a.pace} FİZ ${a.physical} DEF ${a.defending} '
      'DRİ ${a.dribbling} HZL ${a.acceleration}');

  final hedef = arg('--sql');
  if (hedef != null) {
    File(hedef).writeAsStringSync(CharacterPipeline.toSql(sonuc, dunya,
        note: '026: ÖRNEK ÖZGÜN FORVET (tek karakter prototipi, Aşama A1)'));
    stdout.writeln('SQL yazıldı: $hedef');
  }
}

String _uuid() {
  final r = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch % 256);
  r[6] = (r[6] & 0x0f) | 0x40;
  r[8] = (r[8] & 0x3f) | 0x80;
  final h = r.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

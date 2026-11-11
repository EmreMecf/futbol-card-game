import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/ref_tokens.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../../shared/widgets/ref/ref_ui.dart';

/// Sandık türünün rengi (referans nadirlik paleti: .collectible)
Color chestColor(String type) => switch (type) {
      ChestTypes.bronze => const Color(0xFFBF8766),
      ChestTypes.silver => const Color(0xFFB8CEDB),
      ChestTypes.gold => const Color(0xFFF3CE70),
      ChestTypes.legend => const Color(0xFFD18AFF),
      _ => Ref.muted,
    };

/// Süreyi kısa Türkçe metne çevirir: 2 sa, 45 dk, 1:05:09
String chestDuration(Duration d, {bool clock = false}) {
  if (clock) {
    final s = d.inHours, dk = d.inMinutes % 60, sn = d.inSeconds % 60;
    String iki(int n) => n.toString().padLeft(2, '0');
    return s > 0 ? '$s:${iki(dk)}:${iki(sn)}' : '${iki(dk)}:${iki(sn)}';
  }
  if (d.inSeconds <= 0) return 'Anında';
  if (d.inHours >= 1 && d.inMinutes % 60 == 0) return '${d.inHours} sa';
  if (d.inHours >= 1) return '${d.inHours} sa ${d.inMinutes % 60} dk';
  return '${math.max(1, d.inMinutes)} dk';
}

/// KODLA ÇİZİLEN 2D SANDIK (emoji değil: her platformda aynı, kutu
/// olmaz). Gövde + kapak + metal kuşaklar + kilit; [open] 0..1 kapak açılır.
class ChestIcon extends StatelessWidget {
  final String type;
  final double size;
  final double open;
  final bool glow;

  const ChestIcon({super.key, required this.type, this.size = 56, this.open = 0, this.glow = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SandikRessami(chestColor(type), open, glow, type == ChestTypes.legend)),
      );
}

class _SandikRessami extends CustomPainter {
  final Color renk;
  final double acik;
  final bool isik;
  final bool efsane;
  const _SandikRessami(this.renk, this.acik, this.isik, this.efsane);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final govde = Rect.fromLTWH(w * 0.1, h * 0.42, w * 0.8, h * 0.46);
    final koyu = Color.lerp(renk, Colors.black, 0.45)!;
    final acikRenk = Color.lerp(renk, Colors.white, 0.25)!;

    if (isik) {
      c.drawCircle(Offset(w / 2, h * 0.55), w * 0.5,
          Paint()..shader = RadialGradient(colors: [renk.withValues(alpha: 0.45), renk.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.55), radius: w * 0.5)));
    }
    // Gölge
    c.drawOval(Rect.fromCenter(center: Offset(w / 2, h * 0.92), width: w * 0.8, height: h * 0.08),
        Paint()..color = Colors.black.withValues(alpha: 0.35));

    // Gövde
    final rr = RRect.fromRectAndRadius(govde, Radius.circular(w * 0.06));
    c.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [renk, koyu]).createShader(govde));
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.035..color = Color.lerp(koyu, Colors.black, 0.3)!);
    // Dikey kuşaklar
    final kusak = Paint()..color = Color.lerp(koyu, Colors.black, 0.25)!;
    for (final x in [0.27, 0.73]) {
      c.drawRect(Rect.fromLTWH(w * x - w * 0.04, govde.top, w * 0.08, govde.height), kusak);
    }

    // Kapak: açılınca yukarı kalkar ve hafifçe arkaya eğilir (önden
    // bakışta menteşe arkada; tam dönüş yerine kalkış daha okunaklı)
    c.save();
    c.translate(w / 2 - w * 0.06 * acik, h * 0.42 - h * 0.2 * acik);
    c.rotate(-acik * 0.28);
    final kapak = Rect.fromLTWH(-w * 0.42, -h * 0.26, w * 0.84, h * 0.28);
    final kapakYol = Path()
      ..moveTo(kapak.left, kapak.bottom)
      ..lineTo(kapak.left, kapak.top + kapak.height * 0.45)
      ..quadraticBezierTo(0, kapak.top - kapak.height * 0.25, kapak.right, kapak.top + kapak.height * 0.45)
      ..lineTo(kapak.right, kapak.bottom)
      ..close();
    c.drawPath(kapakYol, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [acikRenk, renk]).createShader(kapak));
    c.drawPath(kapakYol, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.035..color = Color.lerp(koyu, Colors.black, 0.3)!);
    for (final x in [-0.23, 0.23]) {
      c.drawRect(Rect.fromLTWH(w * x - w * 0.04, kapak.top + kapak.height * 0.05, w * 0.08, kapak.height * 0.95), kusak);
    }
    c.restore();

    // İçinden çıkan ışık
    if (acik > 0) {
      c.drawOval(Rect.fromCenter(center: Offset(w / 2, h * 0.44), width: w * 0.7 * acik, height: h * 0.12 * acik),
          Paint()..color = Color.lerp(renk, Colors.white, 0.7)!.withValues(alpha: 0.9 * acik));
    }

    // Kilit
    if (acik < 0.3) {
      final kilit = Rect.fromCenter(center: Offset(w / 2, h * 0.5), width: w * 0.16, height: h * 0.16);
      c.drawRRect(RRect.fromRectAndRadius(kilit, Radius.circular(w * 0.03)), Paint()..color = const Color(0xFFF8C665));
      c.drawRRect(RRect.fromRectAndRadius(kilit, Radius.circular(w * 0.03)),
          Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.02..color = const Color(0xFF7A4E10));
      c.drawCircle(Offset(w / 2, h * 0.49), w * 0.025, Paint()..color = const Color(0xFF7A4E10));
    }
    // Efsane: yıldız
    if (efsane) {
      final m = Offset(w / 2, h * 0.73);
      final yol = Path();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? w * 0.08 : w * 0.035;
        final a = -math.pi / 2 + i * math.pi / 5;
        final p = m + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? yol.moveTo(p.dx, p.dy) : yol.lineTo(p.dx, p.dy);
      }
      c.drawPath(yol..close(), Paint()..color = const Color(0xFFF8C665));
    }
  }

  @override
  bool shouldRepaint(_SandikRessami o) => o.renk != renk || o.acik != acik || o.isik != isik;
}

/// Ödül enerjisi hapı (maç içi TAKTİK enerjisinden farklı simge ve renk)
class RewardEnergyPill extends StatelessWidget {
  final RewardEnergy energy;
  const RewardEnergyPill(this.energy, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Ödül enerjisi ${energy.energy} / ${energy.max}',
        excludeSemantics: true,
        child: RefPill('${energy.energy}/${energy.max}',
            leading: const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFFFB648)),
            textColor: energy.isEmpty ? Ref.red : null),
      );
}

/// Sandık yuvası (.tile dilinde). Boş yuva da gösterilir.
class ChestSlotTile extends StatelessWidget {
  final Chest? chest;
  final int slotNo;
  final Duration? remaining;
  final bool busy;
  final VoidCallback? onTap;
  final bool compact;

  const ChestSlotTile({
    super.key,
    required this.chest,
    required this.slotNo,
    this.remaining,
    this.busy = false,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = chest;
    if (c == null) {
      return Semantics(
        label: 'Boş yuva $slotNo',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 16, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Ref.tileBorder.withValues(alpha: 0.7)),
            color: const Color(0x33101B30),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, size: compact ? 22 : 30, color: Ref.muted.withValues(alpha: 0.5)),
            SizedBox(height: compact ? 4 : 8),
            Text('BOŞ', style: Ref.tiny(Ref.muted.withValues(alpha: 0.7))),
          ]),
        ),
      );
    }

    final renk = chestColor(c.chestType);
    final (String alt, Color altRenk) = switch (c) {
      _ when c.isReady => ('AÇ!', Ref.accent),
      _ when c.isUnlocking => (chestDuration(remaining ?? Duration.zero, clock: true), Ref.gold),
      _ => (chestDuration(Duration(seconds: c.unlockSeconds)), Ref.muted),
    };

    return Semantics(
      button: onTap != null,
      label: '${c.typeName} sandık, ${c.isReady ? 'açılmaya hazır' : c.isUnlocking ? 'kilit açılıyor, kalan $alt' : 'kilitli, $alt'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: Ref.tileGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.isReady ? Ref.accent : renk.withValues(alpha: 0.65), width: c.isReady ? 1.6 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ChestIcon(type: c.chestType, size: compact ? 36 : 52, glow: c.isReady),
            SizedBox(height: compact ? 2 : 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(c.typeName.toUpperTr(), maxLines: 1, style: Ref.bodyText(compact ? 9.5 : 11, color: renk, weight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            busy
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (c.isSealed) ...[
                        Icon(Icons.lock_rounded, size: compact ? 10 : 11, color: altRenk),
                        const SizedBox(width: 3),
                      ],
                      Text(alt, maxLines: 1, style: Ref.bodyText(compact ? 10 : 11.5, color: altRenk, weight: FontWeight.w900)),
                    ]),
                  ),
          ]),
        ),
      ),
    );
  }
}

/// Sandıktan çıkan kartın sonucu rozeti
class ChestOutcomePill extends StatelessWidget {
  final String outcome;
  const ChestOutcomePill(this.outcome, {super.key});

  @override
  Widget build(BuildContext context) {
    final (metin, renk) = switch (outcome) {
      ChestCardOutcome.isNew => ('YENİ', Ref.accent),
      ChestCardOutcome.copy => ('+1 GELİŞİM', Ref.gold),
      ChestCardOutcome.squadGuard => ('KADRO KORUMASI', Ref.blue),
      ChestCardOutcome.joker => ('JOKER', Ref.purple),
      _ => (outcome.toUpperTr(), Ref.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.7)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(metin, maxLines: 1, style: Ref.bodyText(9.5, color: renk, weight: FontWeight.w900))),
    );
  }
}

/// Kart nadirliğinin Türkçe adı (joker parça metinleri için)
String tierNameTr(String tier) => switch (tier) {
      'bronze' => 'Bronz',
      'silver' => 'Gümüş',
      'gold' => 'Altın',
      'diamond' => 'Elmas',
      'legend' => 'Efsane',
      _ => tier,
    };

/// Joker parça özeti: "Bronz ×2 · Gümüş ×1"
String jokerSummary(Map<String, int> jokers) =>
    jokers.entries.where((e) => e.value > 0).map((e) => '${tierNameTr(e.key)} ×${e.value}').join(' · ');

/// 038: ek item özeti: "Sandık anahtarı · Ustalık kitabı (Elmas)"
String extrasSummary(Map<String, int> extras) => extras.entries.where((e) => e.value > 0).map((e) {
      final ad = switch (e.key) {
        'chest_key' => 'Sandık anahtarı',
        final k when k.startsWith('mastery_book_') => 'Ustalık kitabı (${tierNameTr(k.substring(13))})',
        final k => k,
      };
      return e.value > 1 ? '$ad ×${e.value}' : ad;
    }).join(' · ');

/// Kısa açıklama satırı (referans .note dili)
class ChestHint extends StatelessWidget {
  final String text;
  const ChestHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: Ref.bodyText(11, color: Ref.muted));
}

/// Ekonomi kapalıyken ya da yüklenemediğinde gösterilmeyen sarmalayıcı
class ChestSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ChestSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => RefSectionHead(title, trailing: trailing);
}

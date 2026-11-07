import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/ref_tokens.dart';
import 'ref_glyphs.dart';

export 'ref_glyphs.dart';

// =====================================================================
// REFERANS BİLEŞENLERİ — design-reference/futbol-card-arena.html
// =====================================================================
// Her widget referanstaki bir CSS sınıfının karşılığıdır; ölçüler o
// sınıftan birebir alındı (sınıf adı her widget'ın yorumunda).

/// .pill { border-radius:999px; padding:5px 10px; background:#1d3144;
/// border:1px solid #365062; font-size:10px; font-weight:900; color:#bfd3e7 }
class RefPill extends StatelessWidget {
  final String text;

  /// Metnin önündeki renkli emoji (🏆, 🔥 ...)
  final String? emoji;

  /// Metnin önündeki nokta (.status .dot)
  final bool dot;
  final Color? textColor;

  const RefPill(this.text, {super.key, this.emoji, this.dot = false, this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Ref.pillBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Ref.pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Ref.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Ref.accent, blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (emoji != null) ...[Em(emoji!, size: 10), const SizedBox(width: 4)],
            Text(text, style: Ref.bodyText(10, color: textColor ?? Ref.pillText, weight: FontWeight.w900)),
          ],
        ),
      );
}

/// Basılınca 3px aşağı inen buton davranışı (.cta:active)
class _Basilabilir extends StatefulWidget {
  final Widget Function(bool basili) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const _Basilabilir({required this.builder, this.onTap, this.semanticLabel});

  @override
  State<_Basilabilir> createState() => _BasilabilirState();
}

class _BasilabilirState extends State<_Basilabilir> {
  bool _basili = false;

  void _ayarla(bool b) {
    if (widget.onTap == null) return;
    setState(() => _basili = b);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: widget.onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _ayarla(true),
          onTapCancel: () => _ayarla(false),
          onTapUp: (_) => _ayarla(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: Opacity(
            // button:disabled { opacity:.42 }
            opacity: widget.onTap == null ? 0.42 : 1,
            child: widget.builder(_basili),
          ),
        ),
      ),
    );
  }
}

/// .cta — altın birincil buton.
/// background: linear-gradient(180deg,#ffe9a8,#f9c76b 45%,#ac6e20);
/// box-shadow: 0 3px 0 #70400e, 0 8px 28px #ffbf4c44; font: Barlow 23/900;
/// letter-spacing:.04em; border-radius:10px; padding:12px 16px
class RefCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final RefGlyph? leading;
  final RefGlyph? trailing;
  final double fontSize;

  const RefCta(this.label, {super.key, this.onTap, this.leading, this.trailing, this.fontSize = 23});

  @override
  Widget build(BuildContext context) {
    final yazi = Ref.heading(fontSize, color: Ref.ctaText, weight: FontWeight.w900, height: 1.2).copyWith(
      letterSpacing: fontSize * 0.04,
      shadows: const [Shadow(color: Color(0x77FFFFFF), offset: Offset(0, 1))],
    );
    return _Basilabilir(
      onTap: onTap,
      semanticLabel: label,
      builder: (basili) => AnimatedContainer(
        duration: Ref.press,
        transform: Matrix4.translationValues(0, basili ? 3 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: Ref.ctaGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Ref.ctaShadow, offset: Offset(0, basili ? 1 : 3)),
            if (!basili) const BoxShadow(color: Ref.ctaGlow, offset: Offset(0, 8), blurRadius: 28),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              RefGlyphIcon(leading!, size: fontSize * 0.8, color: Ref.ctaText),
              SizedBox(width: fontSize * 0.25),
            ],
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: yazi)),
            ),
            if (trailing != null) ...[
              SizedBox(width: fontSize * 0.25),
              RefGlyphIcon(trailing!, size: fontSize * 0.85, color: Ref.ctaText),
            ],
          ],
        ),
      ),
    );
  }
}

/// .secondary-button { border:1px solid #248c75; background:
/// linear-gradient(#135541,#08352d); border-radius:10px; padding:11px;
/// color:#d1ffeb; font-weight:900; font-size:12px }
class RefSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final RefGlyph? trailing;
  final IconData? leadingIcon;
  final bool expand;

  const RefSecondaryButton(this.label,
      {super.key, this.onTap, this.trailing, this.leadingIcon, this.expand = true});

  @override
  Widget build(BuildContext context) => _Basilabilir(
        onTap: onTap,
        semanticLabel: label,
        builder: (basili) => AnimatedContainer(
          duration: Ref.press,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: Ref.secondaryGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: basili ? Ref.accent : Ref.secondaryBorder),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 14, color: Ref.secondaryText),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ref.bodyText(12, color: Ref.secondaryText, weight: FontWeight.w900)),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                RefGlyphIcon(trailing!, size: 12, color: Ref.secondaryText),
              ],
            ],
          ),
        ),
      );
}

/// .neutral-button { border:1px solid #435b76; background:#14243a;
/// border-radius:10px; padding:9px 11px; color:#f1f5ff; font-weight:800;
/// font-size:11px }
class RefNeutralButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final String? semanticLabel;

  const RefNeutralButton({
    super.key,
    this.label,
    this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => _Basilabilir(
        onTap: onTap,
        semanticLabel: semanticLabel ?? label,
        builder: (basili) => AnimatedContainer(
          duration: Ref.press,
          padding: padding,
          decoration: BoxDecoration(
            color: Ref.neutralBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: basili ? Ref.accent : Ref.neutralBorder),
          ),
          child: child ??
              Text(label ?? '',
                  textAlign: TextAlign.center,
                  style: Ref.bodyText(11, color: Ref.neutralText, weight: FontWeight.w800)),
        ),
      );
}

/// .card-panel { background:linear-gradient(160deg,#15253c,#101a2d);
/// border:1px solid #344960; border-radius:13px; padding:13px; gap:10px }
class RefCardPanel extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;
  final VoidCallback? onTap;

  const RefCardPanel({super.key, required this.children, this.padding = const EdgeInsets.all(13), this.gap = 10, this.onTap});

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: Ref.cardPanelGradient,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Ref.cardPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );
    if (onTap == null) return govde;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: govde);
  }
}

/// .tile { border:1px solid #2b4662; border-radius:12px; padding:12px 6px;
/// background:linear-gradient(165deg,#1a304a,#101b30); text-align:center }
/// .tile .em { font-size:27px; margin:4px } strong 11px, small #9eb0c8
class RefTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const RefTile({super.key, required this.emoji, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => _Basilabilir(
        onTap: onTap,
        semanticLabel: title,
        builder: (basili) => AnimatedContainer(
          duration: Ref.press,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            gradient: Ref.tileGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: basili ? Ref.accent : Ref.tileBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // .em { display:block; margin:4px } satır yüksekliği ~1.36
              Padding(padding: const EdgeInsets.all(4), child: Em(emoji, size: 27, height: 1.36)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Ref.bodyText(11, color: Ref.tileText, weight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Ref.bodyText(10, color: Ref.tileSmall)),
            ],
          ),
        ),
      );
}

/// .bar { height:7px; background:#273a50; border-radius:8px }
/// .bar>span { background:linear-gradient(90deg,#0bbf88,#62ffd2) }
class RefBar extends StatelessWidget {
  final double value;
  final double height;
  final Gradient gradient;
  final Color track;

  const RefBar(this.value,
      {super.key, this.height = 7, this.gradient = Ref.barFill, this.track = Ref.barTrack});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                // .bar>span { transition:.4s }
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, t, _) => Opacity(
                    opacity: t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// .sectionhead { display:flex; justify-content:space-between }
/// .sectionhead h3 { font-size:23px } (h2 varyantı 27px)
class RefSectionHead extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double size;
  final String? kicker;

  const RefSectionHead(this.title, {super.key, this.trailing, this.size = 23, this.kicker});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) Text(kicker!, style: Ref.caps(Ref.accent)),
                Text(title, maxLines: 2, style: Ref.heading(size)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 5), trailing!],
        ],
      );
}

/// .hero — ana sayfa arena paneli.
/// border:1px solid #3b6f65; border-radius:17px; padding:18px 16px;
/// background: radial-gradient(circle at 82% 33%,#245c63 0%,transparent 45%),
///             linear-gradient(145deg,#142a43,#0c172a)
/// :before — sağ üstte 164x165 halka (5px #2de5a91f + 16px/32px gölge halkaları)
class RefHero extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  /// Sağ üstteki büyük emoji (.crest-mini, 75px, right:20 top:40)
  final String? crest;

  const RefHero({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18), this.crest});

  /// Dar telefonda (hero < 330px) referansın @media(max-width:420px)
  /// kuralı: başlık 32px; kalkan da orantılı küçülür, yazının üstüne binmez
  static bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < 360;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: CustomPaint(
          painter: const _HeroZemin(),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Ref.heroBorder),
            ),
            child: Stack(
              children: [
                if (crest != null)
                  Positioned(
                    right: isNarrow(context) ? 12 : 20,
                    top: isNarrow(context) ? 30 : 40,
                    // filter: drop-shadow(0 6px 16px #edbf5e77)
                    child: RefDropShadow(
                      color: const Color(0x77EDBF5E),
                      offset: const Offset(0, 6),
                      blur: 16,
                      child: Em(crest!, size: isNarrow(context) ? 52 : 75),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      );
}

class _HeroZemin extends CustomPainter {
  const _HeroZemin();

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    // linear-gradient(145deg,#142a43,#0c172a)
    c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.57, -0.82),
            end: Alignment(0.57, 0.82),
            colors: [Color(0xFF142A43), Color(0xFF0C172A)],
          ).createShader(r));
    // radial-gradient(circle at 82% 33%, #245c63 0%, transparent 45%)
    // circle + farthest-corner: yarıçap en uzak köşeye uzaklık
    final m = Offset(s.width * 0.82, s.height * 0.33);
    final enUzak = [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)]
        .map((k) => (k - m).distance)
        .reduce(math.max);
    final yr = enUzak * 0.45;
    c.drawCircle(
        m,
        yr,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFF245C63), Color(0x00245C63)])
              .createShader(Rect.fromCircle(center: m, radius: yr)));
    // :before halkası — right:-28px; top:7px; 164x165; border 5px #2de5a91f;
    // box-shadow: 0 0 0 16px #27dda911, 0 0 0 32px #27dda909
    final halka = Rect.fromLTWH(s.width + 28 - 164, 7, 164, 165);
    final hm = halka.center;
    final hr = halka.width / 2;
    c.drawCircle(hm, hr + 24, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = const Color(0x0927DDA9));
    c.drawCircle(hm, hr + 8, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = const Color(0x1127DDA9));
    c.drawCircle(hm, hr - 2.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0x1F2DE5A9));
  }

  @override
  bool shouldRepaint(_HeroZemin old) => false;
}

/// .filter-row button { border:1px solid #304763; border-radius:8px;
/// background:#142237; color:#adbdce; padding:7px 9px; font-size:10px;
/// font-weight:900 } .active { background:#185c48; border-color:#29d99c;
/// color:#d5fff0 }
class RefFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const RefFilterChip(this.label, {super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: active,
        child: _Basilabilir(
          onTap: onTap,
          semanticLabel: label,
          builder: (_) => AnimatedContainer(
            duration: Ref.cardHover,
            // padding:7px 9px — yatayda 8.5: Flutter'da yazı genişliği
            // tarayıcıdan ~1px fazla; referanstaki 6 çip 390px'te tek satıra
            // sığıyor, burada da sığsın
            padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 7),
            decoration: BoxDecoration(
              color: active ? Ref.filterActiveBg : Ref.filterBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? Ref.filterActiveBorder : Ref.filterBorder),
            ),
            child: Text(label,
                style: Ref.bodyText(10,
                    color: active ? Ref.filterActiveText : Ref.filterText, weight: FontWeight.w900)),
          ),
        ),
      );
}

/// .searchfield { border:1px solid #344a65; border-radius:9px;
/// background:#111e31; padding:12px; color:white } :focus border accent
class RefSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const RefSearchField({super.key, this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder kenar(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Ref.bodyText(14, color: Colors.white),
      cursorColor: Ref.accent,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Ref.searchBg,
        hintText: hint,
        hintStyle: Ref.bodyText(14, color: const Color(0xFF757575)),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 6),
          child: Em('🔍', size: 13),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.all(12),
        border: kenar(Ref.searchBorder),
        enabledBorder: kenar(Ref.searchBorder),
        focusedBorder: kenar(Ref.accent),
      ),
    );
  }
}

/// .stat { background:#14263b; border:1px solid #314b62; border-radius:9px;
/// padding:9px 3px } b { font:800 25px Barlow; color:#6affc8 } small 10px #adbfd3
class RefStat extends StatelessWidget {
  final String value;
  final String label;
  final double valueSize;

  const RefStat(this.value, this.label, {super.key, this.valueSize = 25});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
        decoration: BoxDecoration(
          color: Ref.statBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Ref.statBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1, style: Ref.heading(valueSize, color: Ref.statValue, height: 1.2)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ref.bodyText(10, color: Ref.statLabel)),
          ],
        ),
      );
}

/// .statrow { grid-template-columns:repeat(3,1fr); gap:7px }
class RefStatRow extends StatelessWidget {
  final List<RefStat> stats;
  const RefStatRow(this.stats, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(child: stats[i]),
          ],
        ],
      );
}

/// Sayfa açılış hareketi: @keyframes fadeSlide (opacity .15→1,
/// translateY 8px→0), .28s
class RefPageEnter extends StatelessWidget {
  final Widget child;
  const RefPageEnter({super.key, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Ref.pageTransition,
        curve: Curves.ease,
        child: child,
        builder: (_, t, c) => Opacity(
          opacity: 0.15 + 0.85 * t,
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c),
        ),
      );
}

/// CSS `filter: drop-shadow(...)`: gölge kutu değil, içeriğin ŞEKLİNİ izler
class RefDropShadow extends StatelessWidget {
  final Widget child;
  final Color color;
  final Offset offset;
  final double blur;

  const RefDropShadow({super.key, required this.child, required this.color, required this.offset, required this.blur});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: offset,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2, tileMode: TileMode.decal),
              child: ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: child),
            ),
          ),
          child,
        ],
      );
}

/// .note { background:#152840; border:1px solid #2a5270; border-radius:12px;
/// padding:13px; color:#a9c5dd; font-size:11px; line-height:1.65 }
class RefNote extends StatelessWidget {
  final String text;
  final String? title;
  const RefNote(this.text, {super.key, this.title});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF152840),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A5270)),
        ),
        child: Text.rich(
          TextSpan(children: [
            if (title != null)
              TextSpan(
                  text: '$title\n',
                  style: Ref.bodyText(11, color: const Color(0xFFECF7FF), weight: FontWeight.w700, height: 1.65)),
            TextSpan(text: text),
          ]),
          style: Ref.bodyText(11, color: const Color(0xFFA9C5DD), height: 1.65),
        ),
      );
}

/// Türkçe binlik ayraç: 2450 -> "2.450" (toLocaleString('tr'))
String trThousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

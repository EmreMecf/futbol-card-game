import 'package:flutter/material.dart';

import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_game_button.dart';
import 'v21_game_panel.dart';
import 'v21_tap.dart';

/// Diyalog düğmesi tanımı
@immutable
class V21DialogAction {
  final String label;
  final V21ButtonTone tone;

  /// Düğmeye basılınca diyalog bu değerle kapanır
  final Object? result;
  const V21DialogAction(this.label, {this.tone = V21ButtonTone.gold, this.result});
}

/// V2.1 OYUN DİYALOĞU (referans HTML demo modalları: altın alt başlık,
/// büyük beyaz başlık, simge, açıklama paneli, tam genişlik oyun düğmeleri).
///
/// Geri dönüşü olmayan işlemler (kart takası, satın alma) için açık onay
/// burada istenir; ilk düğme vurgulu, "VAZGEÇ" ikinci sırada.
class V21GameDialog extends StatelessWidget {
  final String? subtitle;
  final String title;
  final String message;
  final Widget? icon;

  /// Mesajın altında isteğe bağlı içerik (ör. eksik mevkiler)
  final Widget? content;
  final List<V21DialogAction> actions;

  const V21GameDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    this.subtitle,
    this.icon,
    this.content,
  });

  /// Diyaloğu açar; seçilen düğmenin [V21DialogAction.result] değerini
  /// döndürür (dışarı dokunup kapatılırsa null).
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<V21DialogAction> actions,
    String? subtitle,
    Widget? icon,
    Widget? content,
    bool barrierDismissible = true,
  }) {
    final reduced = V21Motion.reduced(context);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Kapat',
      barrierColor: const Color(0xB3120933),
      transitionDuration: reduced ? Duration.zero : V21Motion.enter,
      pageBuilder: (context, _, _) => V21GameDialog(
        title: title,
        message: message,
        actions: actions,
        subtitle: subtitle,
        icon: icon,
        content: content,
      ),
      transitionBuilder: (context, a, _, child) {
        final t = V21Motion.bounce.transform(a.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: a.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      // Kısa pencerede diyalog kesilmez, kaydırılır
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: title,
              child: V21GamePanel(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: V21Type.label(
                          13,
                          weight: FontWeight.w900,
                          color: const Color(0xFFFEDB70),
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: V21Type.title(
                        31,
                        shadows: [const Shadow(color: Color(0xFF1B0A57), offset: Offset(0, 4))],
                      ),
                    ),
                    if (icon != null) ...[const SizedBox(height: 14), Center(child: icon)],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x66120933),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: V21Type.label(14, weight: FontWeight.w600, color: const Color(0xFFD9CAFB), height: 1.5),
                      ),
                    ),
                    if (content != null) ...[const SizedBox(height: 10), content!],
                    const SizedBox(height: 10),
                    for (final a in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: V21GameButton(
                          label: a.label,
                          tone: a.tone,
                          size: V21ButtonSize.medium,
                          onPressed: () => Navigator.of(context).pop(a.result),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// V2.1 YÜKLEME KATMANI: [child]'ın üstüne koyu örtü + panel içinde
/// gösterge ve isteğe bağlı mesaj. Örtü açıkken alttaki dokunmalar kapalı.
class V21LoadingOverlay extends StatelessWidget {
  final bool loading;
  final String? message;
  final Widget child;

  const V21LoadingOverlay({super.key, required this.loading, required this.child, this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: Semantics(
              label: message ?? 'Yükleniyor',
              liveRegion: true,
              child: ColoredBox(
                color: const Color(0x99120933),
                child: Center(
                  child: V21GamePanel(
                    style: V21PanelStyle.slot,
                    accent: V21Colors.panelHigh,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 34,
                          child: CircularProgressIndicator(strokeWidth: 4, color: V21Colors.goldTop),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 12),
                          Text(message!, style: V21Type.label(14, weight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bağlantı durumu
enum V21Connection {
  online('Bağlı', Color(0xFF3DD15A)),
  connecting('Bağlanıyor…', Color(0xFFFFC832)),
  reconnecting('Yeniden bağlanıyor…', Color(0xFFFFC832)),
  offline('Bağlantı yok', Color(0xFFFF5A6E));

  final String label;
  final Color dot;
  const V21Connection(this.label, this.dot);
}

/// V2.1 AĞ DURUMU hapı (referans HTML `.connection`: koyu yarı saydam hap,
/// renkli nokta, 10–11 px yazı). [V21Connection.online] iken [hideWhenOnline]
/// true ise hiç yer kaplamaz.
class V21NetworkStatus extends StatelessWidget {
  final V21Connection status;
  final bool hideWhenOnline;
  final VoidCallback? onRetry;

  const V21NetworkStatus({super.key, required this.status, this.hideWhenOnline = true, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (status == V21Connection.online && hideWhenOnline) return const SizedBox.shrink();
    final busy = status == V21Connection.connecting || status == V21Connection.reconnecting;
    Widget dot(double t) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.dot.withValues(alpha: busy ? 0.45 + 0.55 * t : 1),
      ),
    );
    return Semantics(
      liveRegion: true,
      button: onRetry != null,
      label: onRetry == null ? status.label : '${status.label}. Yeniden denemek için dokun',
      excludeSemantics: true,
      child: V21Tap(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xBB1B084C), borderRadius: BorderRadius.circular(9)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) V21Pulse(builder: (context, t) => dot(t)) else dot(1),
              const SizedBox(width: 7),
              Text(
                status.label,
                style: V21Type.label(11, weight: FontWeight.w800, color: const Color(0xFFCFBFFC)),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFCFBFFC)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// V2.1 BOŞ DURUM: parlak daire içinde simge, başlık, açıklama ve isteğe
/// bağlı eylem düğmesi (HTML demo `.heroIcon` + `.gameCard`).
class V21EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double scale;

  const V21EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 120 * k,
            height: 120 * k,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x8C8C65FF), Color(0x384F2AB9), Color(0x004F2AB9)],
                stops: [0, 0.55, 1],
              ),
            ),
            child: Icon(icon, size: 58 * k, color: const Color(0xFFE3D6FF)),
          ),
        ),
        SizedBox(height: 6 * k),
        Text(
          title,
          textAlign: TextAlign.center,
          style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k)),
        ),
        SizedBox(height: 10 * k),
        V21GamePanel(
          scale: k,
          padding: EdgeInsets.all(14 * k),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: V21Type.label(14 * k, weight: FontWeight.w600, color: const Color(0xFFD9CAFB), height: 1.45),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: 14 * k),
          V21GameButton(label: actionLabel!, size: V21ButtonSize.medium, scale: k, onPressed: onAction),
        ],
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// Dokunulabilir alan: web ve masaüstünde fare imleci el olur.
///
/// KLAVYE: dokunma eylemi ([onTap]) varsa alan Tab ile odaklanabilir ve
/// Enter / Boşluk ile çalışır. Odak halkası yalnız klavyeyle gezinirken
/// çizilir; dokunmatik ve fare kullanımında görünmez.
class V21Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final HitTestBehavior? behavior;
  final Widget? child;

  /// Odak halkasının köşe yuvarlaklığı
  final double focusRadius;

  const V21Tap({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.behavior,
    this.child,
    this.focusRadius = 14,
  });

  @override
  State<V21Tap> createState() => _V21TapState();
}

class _V21TapState extends State<V21Tap> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    Widget child = GestureDetector(
      onTap: w.onTap,
      onLongPress: w.onLongPress,
      onLongPressStart: w.onLongPressStart,
      onLongPressEnd: w.onLongPressEnd,
      onTapDown: w.onTapDown,
      onTapUp: w.onTapUp,
      onTapCancel: w.onTapCancel,
      behavior: w.behavior,
      child: w.child,
    );
    if (_focused) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            left: -3,
            top: -3,
            right: -3,
            bottom: -3,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('v21-odak-halkasi'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w.focusRadius),
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return FocusableActionDetector(
      enabled: w.onTap != null,
      mouseCursor: w.onTap == null && w.onLongPress == null ? MouseCursor.defer : SystemMouseCursors.click,
      onShowFocusHighlight: (v) {
        if (_focused != v) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          w.onTap?.call();
          return null;
        }),
      },
      child: child,
    );
  }
}

import 'package:material_ui/material_ui.dart';

/// Dokunulabilir alan: web ve masaüstünde fare imleci el olur.
class V21Tap extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final HitTestBehavior? behavior;
  final Widget? child;

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
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null && onLongPress == null ? MouseCursor.defer : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      behavior: behavior,
      child: child,
    ),
  );
}

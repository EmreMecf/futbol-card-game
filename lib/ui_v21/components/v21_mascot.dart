import 'package:material_ui/material_ui.dart';

import '../foundation/v21_assets.dart';

/// Oyunun maskotu Efsane Kaptan'ın yuvarlak baş kırpımı (öğretici koçu,
/// alt menüdeki KADRO simgesi). Maskot kart karakteri değildir.
class V21MascotHead extends StatelessWidget {
  final double size;
  const V21MascotHead({super.key, required this.size});

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: const Color(0xFF4B23A8),
        child: Transform.scale(
          scale: 2.1,
          alignment: const Alignment(0.18, -0.55),
          child: Image.asset(V21Assets.victoryMascot, fit: BoxFit.cover, excludeFromSemantics: true),
        ),
      ),
    ),
  );
}

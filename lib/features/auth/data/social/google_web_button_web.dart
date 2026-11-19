import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google, web'de kimlik jetonunu yalnız kendi çizdiği düğmeyle veriyor.
Widget buildGoogleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    type: web.GSIButtonType.standard,
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    text: web.GSIButtonText.continueWith,
    shape: web.GSIButtonShape.pill,
    locale: 'tr',
    minimumWidth: 320,
  ),
);

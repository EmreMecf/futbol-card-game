import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Arkadaş odası uçları. Oyuncu kimliği her zaman doğrulanmış JWT'den alınır.
Router friendRoutes(Database db) {
  final router = Router();
  final codePattern = RegExp(r'^[0-9a-f]{30}$');

  String validatedCode(String code) {
    if (!codePattern.hasMatch(code)) {
      throw const ApiException('Geçersiz davet bağlantısı.', status: 400);
    }
    return code;
  }

  router.post('/create', (Request request) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_create(@actor::uuid)',
      params: {'actor': actor},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.post('/join', (Request request) async {
    final actor = requireUserId(request);
    final body = await readJsonBody(request);
    final code = validatedCode(requireString(body, 'code', label: 'Davet kodu'));
    final result = await db.scalar(
      'select friend_room_join(@actor::uuid,@code)',
      params: {'actor': actor, 'code': code},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.get('/<code>', (Request request, String code) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_info(@actor::uuid,@code)',
      params: {'actor': actor, 'code': validatedCode(code)},
    );
    final data = RowMappers.asMap(result);
    if (data['status'] == 'not_found' || data['status'] == 'not_member') {
      throw const ApiException.notFound('Davet bulunamadı veya odaya katılmadın.');
    }
    return jsonOk(data);
  });

  router.post('/<code>/ready', (Request request, String code) async {
    final actor = requireUserId(request);
    final body = await readJsonBody(request);
    // null: hazır değil. Kadro verilirse oyuncuya ait olduğu veritabanında denetlenir.
    final deckId = body['deck_id'];
    if (deckId != null && (deckId is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(deckId))) {
      throw const ApiException('Geçersiz kadro kimliği.');
    }
    final result = await db.scalar(
      'select friend_room_ready(@actor::uuid,@code,@deck::uuid)',
      params: {'actor': actor, 'code': validatedCode(code), 'deck': deckId},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  router.post('/<code>/leave', (Request request, String code) async {
    final actor = requireUserId(request);
    final result = await db.scalar(
      'select friend_room_leave(@actor::uuid,@code)',
      params: {'actor': actor, 'code': validatedCode(code)},
    );
    return jsonOk(RowMappers.asMap(result));
  });

  return router;
}

/// Paylaşılan HTTPS davet bağlantısının açtığı sayfa: oyunu açmayı dener,
/// olmazsa düğme ve elle girilecek kodu gösterir. [code] çağıran tarafından
/// 30 karakterlik küçük harf onaltılık olarak doğrulanmış olmalıdır.
///
/// Android'de `intent://` adresi kullanılır: Chrome ve WhatsApp'ın iç
/// tarayıcısı çıplak `futbolcard://` yönlendirmesini sessizce engeller,
/// intent adresini ise uygulamaya iletir. Uygulama yüklü değilse sayfa
/// açık kalır ve kod elle girilebilir.
String inviteLandingPage(String code) {
  final deepLink = 'futbolcard://davet/$code';
  final androidLink = 'intent://davet/$code#Intent;scheme=futbolcard;'
      'package=$androidPackage;end';
  return '<!doctype html><html lang="tr"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<meta name="robots" content="noindex">'
      '<title>Futbol Card Arena daveti</title>'
      '<style>'
      'body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;'
      'background:#1b0f45;color:#fff;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif}'
      'main{width:100%;max-width:380px;padding:24px 16px;text-align:center}'
      'h1{margin:0 0 6px;font-size:26px;color:#ffd75e}'
      'p{margin:8px 0;color:#e6dbff;line-height:1.4}'
      'a.btn,button{display:block;width:100%;box-sizing:border-box;margin:14px 0 0;padding:15px;'
      'border:0;border-radius:14px;font-size:17px;font-weight:800;text-decoration:none;cursor:pointer}'
      'a.btn{background:#22d6a5;color:#0b1020}'
      'button{background:transparent;color:#6fe4ff;border:1.5px solid #6fe4ff}'
      'code{display:block;margin:10px 0 0;padding:10px;border-radius:10px;background:#0b0726;'
      'color:#fff;font-size:15px;word-break:break-all;user-select:all}'
      '</style></head><body><main>'
      '<h1>Futbol Card Arena</h1>'
      '<p>Arkadaşın seni özel maça davet ediyor.</p>'
      '<a class="btn" id="ac" href="$deepLink">OYUNDA AÇ</a>'
      '<p style="margin-top:22px">Oyun açılmazsa oyunda <b>Arkadaşınla Oyna</b> ekranına bu kodu gir:</p>'
      '<code id="kod">$code</code>'
      '<button id="kopyala" type="button">KODU KOPYALA</button>'
      '<script>'
      'var a=document.getElementById("ac");'
      'if(/android/i.test(navigator.userAgent))a.href="$androidLink";'
      'document.getElementById("kopyala").onclick=function(){'
      'var b=this;function ok(){b.textContent="KOPYALANDI";}'
      'if(navigator.clipboard){navigator.clipboard.writeText("$code").then(ok,function(){});}'
      'else{var r=document.createRange();r.selectNodeContents(document.getElementById("kod"));'
      'var s=getSelection();s.removeAllRanges();s.addRange(r);document.execCommand("copy");ok();}};'
      'window.location.href=a.href;'
      '</script></main></body></html>';
}

/// Android uygulama kimliği (android/app/build.gradle applicationId)
const androidPackage = 'com.futbolcard.futbol_card';

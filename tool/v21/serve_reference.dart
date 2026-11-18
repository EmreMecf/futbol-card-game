// design/reference klasörünü yerelde sunar (yalnız 127.0.0.1).
// V2.1 HTML prototipini tarayıcıda 390×844 incelemek için.
//
//   dart run tool/v21/serve_reference.dart [port]
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 5591;
  final root = Directory('design/reference').absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('V2.1 referansı: http://127.0.0.1:$port/');
  await for (final req in server) {
    var path = Uri.decodeComponent(req.uri.path);
    if (path == '/') path = '/FutbolCard_V21_Telefon_HTML_Prototip.html';
    final file = File('${root.path}$path');
    final inside = file.absolute.path.startsWith(root.path);
    if (!inside || !file.existsSync()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      continue;
    }
    req.response.headers.contentType = path.endsWith('.html')
        ? ContentType.html
        : path.endsWith('.png')
        ? ContentType('image', 'png')
        : path.endsWith('.json')
        ? ContentType.json
        : ContentType.binary;
    await req.response.addStream(file.openRead());
    await req.response.close();
  }
}

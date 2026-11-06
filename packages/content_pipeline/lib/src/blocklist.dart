/// Gerçek kişi ve marka KARA LİSTESİ.
///
/// Amaç: yapay zekânın (bilerek ya da bilmeyerek) gerçek bir futbolcuya,
/// kulübe, lige ya da markaya benzeyen ad üretmesini yakalamak.
///
/// SINIR: Bu liste tam değildir; dünyadaki her futbolcuyu içeremez.
/// Bu yüzden hat üç katmanlıdır: (1) bu kara liste + benzerlik,
/// (2) ikinci bir yapay zekâ yargısı (isteğe bağlı), (3) İNSAN ONAYI.
/// Hiçbir karakter insan onayı olmadan yayınlanamaz (025 review_character).
library;

/// Tam adlar (normalize edilmiş: küçük harf, aksansız)
const kRealPeopleFullNames = <String>[
  // Mevcut katalogdaki gerçek Legend adları (geçiş bekliyor)
  'diego maradona', 'johan cruyff', 'franz beckenbauer', 'lev yashin',
  'ferenc puskas',
  // Tarihin en bilinenleri
  'alfredo di stefano', 'bobby charlton', 'eusebio da silva ferreira',
  'garrincha', 'gerd muller', 'george best', 'michel platini',
  'marco van basten', 'zinedine zidane', 'ronaldo nazario',
  'ronaldinho gaucho', 'roberto baggio', 'paolo maldini', 'franco baresi',
  'thierry henry', 'dennis bergkamp', 'andrea pirlo', 'xavi hernandez',
  'andres iniesta', 'iker casillas', 'gianluigi buffon', 'kaka',
  'luis figo', 'rivaldo', 'romario', 'hristo stoichkov', 'gheorghe hagi',
  'hakan sukur', 'rustu recber', 'lothar matthaus', 'oliver kahn',
  'philipp lahm', 'manuel neuer', 'thomas muller', 'miroslav klose',
  // Günümüzün en bilinenleri
  'lionel messi', 'cristiano ronaldo', 'neymar junior', 'kylian mbappe',
  'erling haaland', 'mohamed salah', 'kevin de bruyne', 'robert lewandowski',
  'luka modric', 'harry kane', 'vinicius junior', 'jude bellingham',
  'karim benzema', 'virgil van dijk', 'sergio ramos', 'antoine griezmann',
  'son heung min', 'arda guler', 'kenan yildiz', 'hakan calhanoglu',
  'lamine yamal', 'pedri gonzalez', 'rodri hernandez', 'bukayo saka',
];

/// Tek başına bile tanınan adlar/soyadlar (ad içinde geçmesi yeter)
const kRealPeopleMononyms = <String>[
  'maradona', 'pele', 'cruyff', 'beckenbauer', 'yashin', 'puskas',
  'messi', 'ronaldo', 'ronaldinho', 'neymar', 'mbappe', 'haaland',
  'zidane', 'platini', 'eusebio', 'garrincha', 'zico', 'socrates',
  'figo', 'kaka', 'rivaldo', 'romario', 'buffon', 'casillas', 'maldini',
  'baresi', 'pirlo', 'iniesta', 'xavi', 'henry', 'bergkamp', 'beckham',
  'lewandowski', 'modric', 'benzema', 'salah', 'bellingham', 'yamal',
  'hagi', 'stoichkov', 'matthaus', 'muller', 'klose', 'kahn',
];

/// Kulüp, lig, organizasyon ve marka adları (yasak)
const kBrandNames = <String>[
  'real madrid', 'barcelona', 'barca', 'atletico', 'manchester',
  'liverpool', 'chelsea', 'arsenal', 'tottenham', 'juventus', 'inter',
  'milan', 'napoli', 'roma', 'bayern', 'dortmund', 'psg',
  'paris saint', 'ajax', 'psv', 'feyenoord', 'benfica', 'porto',
  'galatasaray', 'fenerbahce', 'besiktas', 'trabzonspor', 'celtic',
  'bundesliga', 'premier league', 'premier lig', 'la liga', 'laliga',
  'serie a', 'ligue 1', 'eredivisie', 'super lig', 'champions league',
  'sampiyonlar ligi', 'fifa', 'uefa', 'conmebol',
  'nike', 'adidas', 'puma', 'umbro', 'kappa', 'hummel', 'new balance',
  'mizuno', 'joma', 'macron', 'lotto',
];

/// Karşılaştırma için normalize: küçük harf, Türkçe ve Latin aksanları
/// sökülür, harf/rakam dışı tek boşluğa iner.
String normalizeName(String s) {
  const harita = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ñ': 'n', 'ß': 'ss', 'ć': 'c', 'č': 'c',
    'š': 's', 'ž': 'z', 'ł': 'l', 'ń': 'n', 'ý': 'y',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final kucuk = ch == 'İ' ? 'i' : ch.toLowerCase();
    b.write(harita[kucuk] ?? kucuk);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Levenshtein benzerliği (0..1)
double similarity(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  var onceki = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final simdi = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final m = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      simdi[j] = [onceki[j] + 1, simdi[j - 1] + 1, onceki[j - 1] + m]
          .reduce((x, y) => x < y ? x : y);
    }
    onceki = simdi;
  }
  final uz = a.length > b.length ? a.length : b.length;
  return 1 - onceki[b.length] / uz;
}

/// Metinde (normalize edilmiş) kelime sınırında geçen yasaklı ifadeler
List<String> findBlockedTerms(String text) {
  final n = ' ${normalizeName(text)} ';
  return [
    for (final t in [...kRealPeopleFullNames, ...kRealPeopleMononyms, ...kBrandNames])
      if (n.contains(' $t ')) t,
  ];
}

/// Ad gerçek bir kişiye çok mu benziyor? (bulanık)
String? closestRealPerson(String displayName, {double threshold = 0.82}) {
  final n = normalizeName(displayName);
  for (final g in kRealPeopleFullNames) {
    if (similarity(n, g) >= threshold) return g;
  }
  // Soyad tek başına bilinen bir adla bulanık eşleşiyor mu?
  final parcalar = n.split(' ');
  for (final p in parcalar.where((p) => p.length >= 4)) {
    for (final m in kRealPeopleMononyms.where((m) => m.length >= 4)) {
      if (similarity(p, m) >= 0.84) return m;
    }
  }
  return null;
}

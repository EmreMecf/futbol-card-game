/// V2.1 geçiş anahtarları.
///
/// Ekranlar V2.1'e tek tek taşınır. Bir ekranda sorun çıkarsa anahtar
/// false yapılarak eski Ref ekranına dönülür; eski kod silinmedi.
///
/// Derleme anında da kapatılabilir:
///   flutter run --dart-define=V21_HOME=false
const bool kV21Home = bool.fromEnvironment('V21_HOME', defaultValue: true);

/// V2.1 Koleksiyon ("KARTLARIM"). Kapatmak: --dart-define=V21_COLLECTION=false
const bool kV21Collection = bool.fromEnvironment('V21_COLLECTION', defaultValue: true);

/// V2.1 Kadrom. Kapatmak: --dart-define=V21_DECK=false
/// (Rota satırına dokunulmadı: PR #6 aynı bölgeyi değiştiriyor. Geçiş
/// DeckView içinde yapılır.)
const bool kV21Deck = bool.fromEnvironment('V21_DECK', defaultValue: true);

/// V2.1 Mağaza. Kapatmak: --dart-define=V21_STORE=false
const bool kV21Store = bool.fromEnvironment('V21_STORE', defaultValue: true);

/// V2.1 Sezon Yolu. Kapatmak: --dart-define=V21_SEASON=false
const bool kV21Season = bool.fromEnvironment('V21_SEASON', defaultValue: true);

/// V2.1 ekran geçişi (220 ms solma + kayma) bütün rotalarda.
/// Kapatmak: --dart-define=V21_TRANSITIONS=false
const bool kV21Transitions = bool.fromEnvironment('V21_TRANSITIONS', defaultValue: true);

/// V2.1 iç ekranlar: Sandıklar, Lig Yolu, Gelişim, Envanter, Profil,
/// Ayarlar, Kart Takası. Kapatmak: --dart-define=V21_INNER=false
const bool kV21Inner = bool.fromEnvironment('V21_INNER', defaultValue: true);

/// V2.1 maç sonucu (Zafer). Kapatmak: --dart-define=V21_RESULT=false
/// (Geçiş MatchResultView içinde: PR #6 match_view.dart'ta o satırı değiştiriyor.)
const bool kV21MatchResult = bool.fromEnvironment('V21_RESULT', defaultValue: true);

/// V2.1 öğretici ipucu (hf12–hf14: adım çizelgesi + koç balonu).
/// Kapatmak: --dart-define=V21_TUTORIAL=false
/// (Geçiş TutorialHint içinde: maç ekranı PR #6'da değişiyor, ona dokunulmadı.)
const bool kV21Tutorial = bool.fromEnvironment('V21_TUTORIAL', defaultValue: true);

/// V2.1 açılış ekranı (logo + kahramanlar). Yönlendirme SplashView'de
/// değişmedi. Kapatmak: --dart-define=V21_SPLASH=false
const bool kV21Splash = bool.fromEnvironment('V21_SPLASH', defaultValue: true);

/// V2.1 Maça Hazırlan + rakip arama (hf3–hf6) ve canlı arena (hf7–hf11).
/// Geçiş rota düzeyinde (app_router): eşleştirme ve maç ekranları PR #5
/// ve PR #6'da değiştiği için onlara dokunulmadı.
/// Kapatmak: --dart-define=V21_ARENA=false
const bool kV21Arena = bool.fromEnvironment('V21_ARENA', defaultValue: true);

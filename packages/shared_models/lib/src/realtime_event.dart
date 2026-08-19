import 'package:freezed_annotation/freezed_annotation.dart';

part 'realtime_event.freezed.dart';
part 'realtime_event.g.dart';

/// Sunucudan WebSocket ile gelen olay turleri
@JsonEnum()
enum RealtimeEventType {
  /// Baglanti kuruldu
  @JsonValue('connected')
  connected,

  /// Eslestirme kuyrugunda bir sey degisti (rakip bulundu vb.)
  @JsonValue('queue_updated')
  queueUpdated,

  /// Macin durumu degisti (sira gecti, skor degisti)
  @JsonValue('match_updated')
  matchUpdated,

  /// Rakip kart oynadi
  @JsonValue('move_played')
  movePlayed,

  /// Tur sonuclandi (kartlar toplandi veya masada kaldi)
  @JsonValue('round_resolved')
  roundResolved,

  /// Mac bitti
  @JsonValue('match_finished')
  matchFinished,

  /// Baglanti canli tutma cevabi
  @JsonValue('pong')
  pong,

  /// Taninmayan olay (ileride sunucuya yeni olay eklenirse
  /// eski uygulama surumleri cokmesin diye)
  @JsonValue('unknown')
  unknown;
}

/// Sunucudan gelen gercek zamanli olay.
///
/// TASARIM NOTU - NEDEN ICERIK YOK?
/// Bu mesajlar kasitli olarak KUCUKTUR; sadece "hangi macta ne oldu"
/// bilgisini tasir. Detayi uygulama ayrica REST ile ceker. Iki sebebi var:
///   1. PostgreSQL'in pg_notify mesaji 8000 bayt ile sinirli.
///   2. Daha onemlisi: bildirim kanalindan yanlislikla gizli veri
///      (rakibin eli gibi) sizmasi IMKANSIZ hale geliyor.
@freezed
abstract class RealtimeEvent with _$RealtimeEvent {
  const RealtimeEvent._();

  const factory RealtimeEvent({
    @JsonKey(unknownEnumValue: RealtimeEventType.unknown)
    required RealtimeEventType type,
    String? matchId,
    String? userId,
    String? status,
    DateTime? at,
  }) = _RealtimeEvent;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) =>
      _$RealtimeEventFromJson(json);

  /// Eslesme bulundu mu? (kuyrukta beklerken oyun ekranina gecmek icin)
  bool get isMatchFound =>
      type == RealtimeEventType.queueUpdated && matchId != null;

  /// Mac ekraninin tazelenmesi gerekiyor mu?
  bool get requiresMatchRefresh =>
      type == RealtimeEventType.matchUpdated ||
      type == RealtimeEventType.movePlayed ||
      type == RealtimeEventType.roundResolved ||
      type == RealtimeEventType.matchFinished;

  /// Mac bitis olayi mi?
  bool get isMatchFinished => type == RealtimeEventType.matchFinished;

  /// Ekrani ilgilendirmeyen teknik mesaj mi?
  bool get isNoise =>
      type == RealtimeEventType.pong || type == RealtimeEventType.connected;
}

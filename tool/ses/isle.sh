#!/usr/bin/env bash
# =====================================================================
# SES DOSYALARINI OYUNA HAZIRLAR
# =====================================================================
# Kullanım:
#   bash tool/ses/isle.sh                 # ~/Desktop/sesler klasöründen
#   bash tool/ses/isle.sh /bir/klasor     # başka bir klasörden
#
# Kaynak klasördeki her dosya ADINA göre işlenir (docs/SES_LISTESI.md):
#   muzik_*, ambiyans_*  → dikişsiz döngü: sondaki sönme kesilir, son
#                          1,5 sn başa geçişle bağlanır, -16 LUFS, stereo
#   jingle_*             → baş/son sessizlik kesilir, -15 LUFS, stereo
#   diğerleri (efekt)    → baş/son sessizlik kesilir, mono, tepe -1 dB
# Çıktı: assets/audio/music/ ve assets/audio/sfx/ (MP3, 44,1 kHz).
# Kaynak dosyalara dokunulmaz. Listede olmayan adlar atlanır ve yazılır.
#
# Gerekli: ffmpeg  (macOS: brew install ffmpeg)
# =====================================================================
set -euo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
KAYNAK="${1:-$HOME/Desktop/sesler}"
MUZIK="$KOK/assets/audio/music"
EFEKT="$KOK/assets/audio/sfx"
LISTE="$KOK/docs/SES_LISTESI.md"
GECIS=1.5   # döngü dikişindeki geçiş (sn)

command -v ffmpeg >/dev/null || { echo "ffmpeg yok: brew install ffmpeg"; exit 1; }
[ -d "$KAYNAK" ] || { echo "Klasör yok: $KAYNAK"; exit 1; }
mkdir -p "$MUZIK" "$EFEKT"
GECICI="$(mktemp -d)"; trap 'rm -rf "$GECICI"' EXIT

sure() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

# Müziğin gerçekten bittiği an: 0,1 sn pencerelerde -24 dB üstündeki son nokta
muzik_sonu() {
  ffmpeg -hide_banner -nostats -i "$1" \
    -af "aresample=8000,asetnsamples=800,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level" \
    -f null - 2>&1 | grep -oE 'RMS_level=(-?[0-9.]+|-inf)' | sed 's/RMS_level=//' |
    awk '{ if ($1 != "-inf" && $1 + 0 > -24) son = NR } END { printf "%.1f", (son - 3) * 0.1 }'
}

sessizlik_kes() { # $1 giriş → $2 wav
  ffmpeg -hide_banner -loglevel error -y -i "$1" -af \
    "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse" "$2"
}

dongu() { # $1 kaynak, $2 hedef
  local E S
  E="$(muzik_sonu "$1")"; S="$(echo "$E - $GECIS" | bc)"
  ffmpeg -hide_banner -loglevel error -y -i "$1" -filter_complex \
    "[0]atrim=${GECIS}:${S},asetpts=PTS-STARTPTS[govde];\
[0]atrim=${S}:${E},asetpts=PTS-STARTPTS,afade=t=out:st=0:d=${GECIS}:curve=qsin[kuyruk];\
[0]atrim=0:${GECIS},asetpts=PTS-STARTPTS,afade=t=in:st=0:d=${GECIS}:curve=qsin[bas];\
[kuyruk][bas]amix=inputs=2:normalize=0[dikis];\
[govde][dikis]concat=n=2:v=0:a=1,loudnorm=I=-16:TP=-3:LRA=11,aresample=44100" \
    -ac 2 -b:a 160k "$2"
}

jingle() {
  local w="$GECICI/j.wav" d st
  sessizlik_kes "$1" "$w"; d="$(sure "$w")"; st="$(echo "$d - 0.08" | bc)"
  ffmpeg -hide_banner -loglevel error -y -i "$w" \
    -af "afade=t=out:st=${st}:d=0.08,loudnorm=I=-15:TP=-3:LRA=11,aresample=44100" -ac 2 -b:a 160k "$2"
}

efekt() {
  local w="$GECICI/e.wav" d st
  sessizlik_kes "$1" "$w"; d="$(sure "$w")"; st="$(echo "$d - 0.03" | bc)"
  # Tepe -1 dB'ye çek (seviye eşitleme), sona 30 ms yumuşak bitiş
  local tepe; tepe="$(ffmpeg -hide_banner -nostats -i "$w" -af volumedetect -f null - 2>&1 | grep -oE 'max_volume: -?[0-9.]+' | awk '{print $2}')"
  local kazanc; kazanc="$(echo "-1 - (${tepe:-0})" | bc)"
  ffmpeg -hide_banner -loglevel error -y -i "$w" \
    -af "volume=${kazanc}dB,afade=t=out:st=${st}:d=0.03,aresample=44100" -ac 1 -b:a 128k "$2"
}

islenen=0; atlanan=()
shopt -s nullglob nocaseglob
for f in "$KAYNAK"/*.{mp3,wav,m4a,ogg,flac,aac}; do
  ad="$(basename "${f%.*}")"
  if ! grep -q "\`${ad}.mp3\`" "$LISTE"; then atlanan+=("$(basename "$f")"); continue; fi
  case "$ad" in
    muzik_*|ambiyans_*) dongu "$f" "$MUZIK/$ad.mp3" ;;
    jingle_*) jingle "$f" "$MUZIK/$ad.mp3" ;;
    *) efekt "$f" "$EFEKT/$ad.mp3" ;;
  esac
  printf "  ✓ %-28s %5.1f sn\n" "$ad" "$(sure "$( [ -f "$MUZIK/$ad.mp3" ] && echo "$MUZIK/$ad.mp3" || echo "$EFEKT/$ad.mp3")")"
  islenen=$((islenen + 1))
done

echo "İşlenen: $islenen"
if [ ${#atlanan[@]} -gt 0 ]; then
  echo "Listede adı olmayan (atlandı, adını docs/SES_LISTESI.md'ye göre düzelt):"
  printf '  - %s\n' "${atlanan[@]}"
fi

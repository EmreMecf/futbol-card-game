#!/usr/bin/env bash
# Yerel şifre ve imza dosyaları yanlışlıkla git'e girerse CI'ı durdurur.
set -euo pipefail

blocked=0
while IFS= read -r path; do
  case "$path" in
    database/.yerel_*|.env|.env.local|server/.env|server/.env.local|android/key.properties|*.keystore|*.jks|*.p12)
      printf 'HATA: git takibinde gizli yerel dosya: %s\n' "$path" >&2
      blocked=1
      ;;
  esac
done < <(git ls-files)

if (( blocked )); then
  printf 'Bu dosyaları git takibinden çıkar, sızan şifreleri değiştir ve geçmişi incele.\n' >&2
  exit 1
fi
printf 'Takipte bilinen yerel gizli dosya yok.\n'

#!/usr/bin/env bash
# Verifica se todas as bibliotecas nativas (.so) de um AAB/APK estão alinhadas
# a 16 KB — exigência da Play Store desde 1/11/2025 (sem isto as atualizações
# são rejeitadas). Corra depois de `flutter build appbundle`:
#
#   tool/check_16kb.sh [build/app/outputs/bundle/release/app-release.aab]
#
# Precisa de `llvm-readelf` (vem no NDK) no PATH ou em $READELF.
set -euo pipefail

PKG="${1:-build/app/outputs/bundle/release/app-release.aab}"
READELF="${READELF:-llvm-readelf}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q -o "$PKG" -d "$TMP"
fail=0
while IFS= read -r so; do
  # Menor alinhamento entre os segmentos LOAD (ex.: 0x1000 = 4 KB).
  align=$("$READELF" -lW "$so" | awk '$1=="LOAD"{print $NF}' | sort -u | head -1)
  if (( align < 0x4000 )); then
    echo "FALHA  $align  ${so#"$TMP"/}"
    fail=1
  else
    echo "ok     $align  ${so#"$TMP"/}"
  fi
done < <(find "$TMP" -name '*.so')

if (( fail )); then
  echo "Há bibliotecas abaixo de 16 KB: a Play Store vai rejeitar a atualização." >&2
  exit 1
fi
echo "Todas as bibliotecas estão alinhadas a 16 KB."

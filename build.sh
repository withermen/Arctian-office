#!/bin/bash
# Arctian Office - bes ofis uygulamasini .wlf paketi olarak derler.
#
#   bash build.sh
#   WOLF_LOAD=0x06800000 bash build.sh      # yeni bellek haritali imajlar
#   WOLF_KEY=/yol/dev_rsa2048.txt bash build.sh   # imzali paket
#
# Cikti: build/<ad>.wlf  +  build/catalog.txt
#
# Not: .wlf yukleme adresi hedef imajin WLF_BASE degeriyle AYNI olmali.
# 0.9 ilk ISO (arctian08.iso) 0x03000000 kullanir; 13 Kasim sonrasi
# bellek haritasi 0x06800000. Yanlis adresle derlenen paket "gecerli
# .wlf degil" diye reddedilir.
set -e
ROOT=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$ROOT/build}
LOAD=${WOLF_LOAD:-0x03000000}
BASE_URL=${BASE_URL:-https://github.com/withermen/Arctian-office/releases/download/apps-v1}

CC=${CC:-gcc}
LD=${LD:-ld}
OBJCOPY=${OBJCOPY:-objcopy}
NM=${NM:-nm}
READELF=${READELF:-readelf}
PY=${PYTHON:-python3}

for t in "$CC" "$LD" "$OBJCOPY" "$NM" "$READELF" "$PY"; do
    command -v "$t" >/dev/null 2>&1 || { echo "[hata] eksik arac: $t" >&2; exit 1; }
done

mkdir -p "$OUT"

CFLAGS="-std=gnu11 -m64 -ffreestanding -nostdlib -nostartfiles -nodefaultlibs \
 -O2 -fno-pic -fno-stack-protector -fno-asynchronous-unwind-tables \
 -mno-red-zone -fno-pie -mstackrealign -Wall -Wextra"

cat > "$OUT/link.ld" <<LDS
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(wolf_main)
SECTIONS
{
    . = $LOAD;
    .text : ALIGN(16) { *(.text.entry) *(.text) *(.text.*) }
    .rodata : ALIGN(16) { *(.rodata) *(.rodata.*) }
    .data : ALIGN(16) { *(.data) *(.data.*) *(.got) *(.got.plt) }
    .bss : ALIGN(16) { *(.bss) *(.bss.*) *(COMMON) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
LDS

: > "$OUT/catalog.txt"
echo "# Arctian Office - .wlf katalogu (wf install <ad> bunu okur)" >> "$OUT/catalog.txt"

ok=0
for d in "$ROOT"/apps/*/; do
    [ -f "$d/main.c" ] || continue
    [ -f "$d/wolf.json" ] || continue
    name=$($PY -c "import json,sys;print(json.load(open(sys.argv[1]))['name'])" "$d/wolf.json")
    echo "== $name =="

    $CC $CFLAGS -I"$ROOT/sdk/include" -c -o "$OUT/$name.app.o" "$d/main.c"
    $CC $CFLAGS -I"$ROOT/sdk/include" -c -o "$OUT/$name.libwolf.o" "$ROOT/sdk/src/libwolf.c"
    $LD -m elf_x86_64 -nostdlib -T "$OUT/link.ld" -o "$OUT/$name.elf" \
        "$OUT/$name.app.o" "$OUT/$name.libwolf.o"
    $OBJCOPY -O binary "$OUT/$name.elf" "$OUT/$name.bin"

    sym=$($NM "$OUT/$name.elf" | grep -E ' T (wolf_main|main)$' | head -1 | cut -d' ' -f1)
    [ -n "$sym" ] || { echo "  [hata] giris sembolu (wolf_main) yok" >&2; exit 1; }
    off=$($PY -c "print(int('$sym',16) - int('$LOAD',0))")

    bss=$($PY - "$OUT/$name.elf" "$READELF" <<'PY'
import subprocess, sys
out = subprocess.run([sys.argv[2], "-SW", sys.argv[1]],
                     capture_output=True, text=True).stdout
bss = 0
for line in out.splitlines():
    if " .bss " in line:
        try:
            bss = int(line.split("]")[1].split()[4], 16)
        except (IndexError, ValueError):
            pass
print(bss)
PY
)

    args="--bin $OUT/$name.bin --json $d/wolf.json --entry $off --load $LOAD --bss $bss"
    [ -n "$WOLF_KEY" ] && args="$args --key $WOLF_KEY"
    # shellcheck disable=SC2086
    $PY "$ROOT/sdk/wlfpack.py" $args -o "$OUT/$name.wlf"

    echo "$name=$BASE_URL/$name.wlf" >> "$OUT/catalog.txt"
    ok=$((ok + 1))
done

echo
echo "Hazir: $OUT ($ok paket, yukleme tabani $LOAD)"
if [ -z "$WOLF_KEY" ]; then
    echo "NOT: imzasiz paket uretildi. Arctian kurulum icin imza ister:"
    echo "     WOLF_KEY=<yerel imza anahtari> bash build.sh"
fi

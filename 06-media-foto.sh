#!/usr/bin/env bash
#[6. FOTOGRAFIJE I MULTIMEDIJA]

# [takeout] - Vraća originalni datum i GPS iz Google Takeout .json fajlova u slike/videe
foto-json() {
    command -v exiftool >/dev/null 2>&1 || { echo "Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }
    echo "Trenutni folder: $(pwd)"
    read -r -p "Upiši EXIF datume iz Google Takeout .json fajlova u slike ovde? [d/N]: " odgovor
    [[ ! "$odgovor" =~ ^[dDyY]$ ]] && { echo "Otkazano."; return 0; }

    exiftool -r -d "%s" -tagsfromfile "%d/%f.%e.json" \
        "-DateTimeOriginal<PhotoTakenTimeTimestamp" \
        "-CreateDate<PhotoTakenTimeTimestamp" \
        "-GPSLatitude<GeoDataLatitude" \
        "-GPSLongitude<GeoDataLongitude" \
        -overwrite_original \
        -ext jpg -ext jpeg -ext png -ext heic -ext webp -ext mp4 -ext mov .
    echo "Metapodaci iz JSON-a su upisani!"
}

# [test] - Preimenuje slike/videe po datumu i razvrstava (1: godine, 2: godine i meseci)
foto-sredi() {
    command -v exiftool >/dev/null 2>&1 || { echo "Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }

    echo "Preimenovanje slika/videa po datumu i razvrstavanje"
    echo "Izaberi strukturu foldera:"
    echo " 1) Po godinama (npr. 2024/2024-05-12_14-30-00.jpg)"
    echo " 2) Po godinama i mesecima (npr. 2024/2024-05/2024-05-12_14-30-00.jpg)"
    read -r -p "Unesi izbor [1/2]: " izbor

    local putanja_format
    case "$izbor" in
        1) putanja_format="%Y/%Y-%m-%d_%H-%M-%S%%-03c.%%le" ;;
        2) putanja_format="%Y/%Y-%m/%Y-%m-%d_%H-%M-%S%%-03c.%%le" ;;
        *) echo "Nevažeći izbor. Otkazano."; return 0 ;;
    esac

    echo ""
    echo "Trenutni folder: $(pwd)"
    echo "Šta želiš da uradiš?"
    echo " d) Da, pokreni stvarno preimenovanje i razvrstavanje"
    echo " t) Test (prikaži plan bez ikakvih izmena na disku)"
    echo " n) Ne, otkaži"
    read -r -p "Unesi izbor [d/t/N]: " odgovor

    local tag="FileName"
    case "$odgovor" in
        [dDyY])
            echo "=== POKREĆEM STVARNU OBRADU ==="
            ;;
        [tT])
            tag="testname"
            echo "=== TEST REŽIM (DRY-RUN): Prikaz plana bez izmena ==="
            ;;
        *)
            echo "Otkazano."
            return 0
            ;;
    esac

    echo "Obrada novih slika i video snimaka (preskačem foldere sa godinama)..."
    exiftool -r \
        -if '$Directory !~ m{/(19|20)\d{2}(/|$)}' \
        "-${tag}<FileModifyDate" \
        "-${tag}<MediaCreateDate" \
        "-${tag}<CreateDate" \
        "-${tag}<DateTimeOriginal" \
        "-${tag}<SubSecDateTimeOriginal" \
        -d "$putanja_format" \
        -ext jpg -ext jpeg -ext png -ext heic -ext webp -ext mp4 -ext mov .

    echo "Završeno!"
}

# [ocr] - Paralelno pronalazi slike sa tekstom (računi, dokumenta, skrinšotovi) i izdvaja ih
foto-papiri() {
    command -v tesseract >/dev/null 2>&1 || { echo "Greška: Instaliraj 'tesseract-ocr' (i tesseract-ocr-srp-latn)"; return 1; }

    local prag=150
    local cilj="_papiri_i_tekst"
    local jezgra
    jezgra=$(nproc)

    echo "Trenutni folder: $(pwd)"
    echo "Broj procesorskih jezgara koja će se koristiti: $jezgra"
    read -r -p "Pretraži slike sa tekstom (prag: ${prag} znakova) i premesti u '$cilj'? [d/N]: " odgovor
    [[ ! "$odgovor" =~ ^[dDyY]$ ]] && { echo "Otkazano."; return 0; }

    mkdir -p "$cilj"

    find . -path "./$cilj" -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | \
    xargs -0 -P "$jezgra" -I {} bash -c '
        slika="$1"
        prag="$2"
        cilj="$3"
#        tekst=$(OMP_THREAD_LIMIT=1 tesseract "$slika" stdout -l eng+srp_latn --oem 1 -psm 3 2>/dev/null | tr -d "[:space:]")
        tekst=$(OMP_THREAD_LIMIT=1 tesseract "$slika" stdout -l eng+srp+srp_latn --oem 1 -psm 3 2>/dev/null | tr -d "[:space:]")
        duzina=${#tekst}
        if (( duzina >= prag )); then
            echo "[Pronađeno: ${duzina} znakova] -> $slika"
            mv -n "$slika" "$cilj/"
        fi
    ' _ {} "$prag" "$cilj"

    echo "Završeno! Pregledaj folder '$cilj' pre brisanja."
}

# [slika] - Prikazuje GPS lokaciju, datum, uređaj i link ka mapi gde je fotografija snimljena
foto-lokacija() {
    command -v exiftool >/dev/null 2>&1 || { echo "Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }
    [[ -z "$1" || ! -f "$1" ]] && { echo "Upotreba: foto-lokacija <putanja_do_slike>"; return 1; }

    local koordinate datum model
    koordinate=$(exiftool -n -s3 -p '$GPSLatitude,$GPSLongitude' "$1" 2>/dev/null)
    datum=$(exiftool -s3 -DateTimeOriginal "$1" 2>/dev/null)
    model=$(exiftool -s3 -Model "$1" 2>/dev/null)

    echo "Fajl:   $1"
    [[ -n "$datum" ]] && echo "Datum:  $datum"
    [[ -n "$model" ]] && echo "Uređaj: $model"

    if [[ -z "$koordinate" || "$koordinate" == "," ]]; then
        echo "Lokacija: Ova fotografija nema sačuvane GPS podatke."
        return 0
    fi

    echo "GPS:    $koordinate"
    echo "OSM:    https://openstreetmap.org{koordinate%,*}&mlon=${koordinate#*,}&zoom=16"
    echo "GMap:   https://google.com{koordinate}"
}

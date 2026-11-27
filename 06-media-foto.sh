#!/usr/bin/env bash
#[6. FOTOGRAFIJE I MULTIMEDIJA]

# [takeout] - Vraća originalni datum i GPS iz Google Takeout .json fajlova u slike/videe i briše iskorišćene JSON-e
foto-json() {
    command -v exiftool >/dev/null 2>&1 || { echo "❌  Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }
    command -v file >/dev/null 2>&1 || { echo "❌  Greška: Instaliraj paket 'file'"; return 1; }

    echo "Trenutni folder: $(pwd)"
    printf "Upiši EXIF datume i obriši iskorišćene .json fajlove ovde? [d/N]: "
    read -r odgovor
    [[ ! "$odgovor" =~ ^[dDyY]$ ]] && { echo "Otkazano."; return 0; }

    # 1. Preimenovanje Google Takeout sufiksa (npr. .supplemental-metadata.json, .suppl.json, ili skraćeno .s)
    # Hvata i slučaj kada je broj duplikata pre .json (npr. slika.jpg.supplemental-metadata(1).json)
    find . -type f -regextype posix-extended -iregex '.*\.(jpg|jpeg|png|heic|webp|gif|mp4|mov|avi|mkv)\.s[a-z-]*(\([0-9]+\))?(\.json)?$' -exec bash -c '
        for f; do
            novi=$(echo "$f" | sed -E "s/\.s[a-z-]*(\([0-9]+\))?(\.json)?$/\1.json/i")
            mv -n "$f" "$novi"
        done
    ' bash {} +

    # 2. Ispravljanje Google-ovog baga sa duplikatima (SAMO za .json fajlove): slika.JPG(1).json -> slika(1).JPG.json
    find . -type f -regextype posix-extended -iregex '.*\.(jpg|jpeg|png|heic|webp|gif|mp4|mov|avi|mkv)\([0-9]+\)\.json$' -exec bash -c '
        for f; do
            novi=$(echo "$f" | sed -E "s/(\.[a-z0-9]+)(\([0-9]+\))\.json$/\2\1.json/i")
            mv -n "$f" "$novi"
        done
    ' bash {} +

    # 3. Ispravljanje lažnih PNG fajlova (JPEG fajlovi koji imaju .png/.PNG ekstenziju)
    find . -type f -iname "*.png" -exec bash -c '
        for f; do
            if [[ $(file -b --mime-type "$f") == "image/jpeg" ]]; then
                novi="${f%.*}.jpg"
                mv -n "$f" "$novi"
                [[ -f "${f}.json" ]] && mv -n "${f}.json" "${novi}.json"
            fi
        done
    ' bash {} +

    # 4. Kopiranje JSON-a za -измењено i -edited verzije
    find . -type f \( -name "*-измењено.*" -o -name "*-edited.*" \) ! -name "*.json" -exec bash -c '
        for f; do
            orig="${f/-измењено./.}"
            orig="${orig/-edited./.}"
            [[ -f "${orig}.json" && ! -f "${f}.json" ]] && cp "${orig}.json" "${f}.json"
        done
    ' bash {} +

    # 5. Upisivanje EXIF/QuickTime datuma i GPS metapodataka
    find . -type f -name "*.json" ! -name "metadata.json" -exec bash -c '
        for j; do
            slika="${j%.json}"
            if [[ -f "$slika" ]]; then
                # Provera da li JSON ima validne GPS koordinate (različite od 0)
                ima_gps=$(exiftool -s3 -GeoDataLatitude "$j" 2>/dev/null)

                if [[ -n "$ima_gps" && "$ima_gps" != "0" && "$ima_gps" != "0.0" ]]; then
                    exiftool -q -q -d "%s" -tagsfromfile "$j" \
                        "-DateTimeOriginal<PhotoTakenTimeTimestamp" \
                        "-CreateDate<PhotoTakenTimeTimestamp" \
                        "-TrackCreateDate<PhotoTakenTimeTimestamp" \
                        "-MediaCreateDate<PhotoTakenTimeTimestamp" \
                        "-GPSLatitude<GeoDataLatitude" \
                        "-GPSLatitudeRef<GeoDataLatitude" \
                        "-GPSLongitude<GeoDataLongitude" \
                        "-GPSLongitudeRef<GeoDataLongitude" \
                        -overwrite_original "$slika"
                else
                    exiftool -q -q -d "%s" -tagsfromfile "$j" \
                        "-DateTimeOriginal<PhotoTakenTimeTimestamp" \
                        "-CreateDate<PhotoTakenTimeTimestamp" \
                        "-TrackCreateDate<PhotoTakenTimeTimestamp" \
                        "-MediaCreateDate<PhotoTakenTimeTimestamp" \
                        -overwrite_original "$slika"
                fi

                if [[ $? -eq 0 ]]; then
                    rm -f "$j"
                else
                    echo "❌  Greška pri upisu u: $slika (JSON sačuvan)"
                fi
            fi
        done
    ' bash {} +

    echo "Gotovo!"
}

# Preimenovanje slika/videa po datumu i razvrstavanje (1: godine, 2: godine i meseci)
foto-sredi() {
    command -v exiftool >/dev/null 2>&1 || { echo "❌  Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }

    echo "Preimenovanje slika/videa po datumu i razvrstavanje"
    echo "Izaberi strukturu foldera:"
    echo " 1) Po godinama (npr. 2024/2024-05-12_14-30-00.jpg)"
    echo " 2) Po godinama i mesecima (npr. 2024/2024-05/2024-05-12_14-30-00.jpg)"
    printf "Unesi izbor [1/2]: "
    read -r izbor

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
    printf "Unesi izbor [d/t/N]: "
    read -r odgovor

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
    command -v tesseract >/dev/null 2>&1 || { echo "❌  Greška: Instaliraj 'tesseract-ocr' (i tesseract-ocr-srp-latn)"; return 1; }

    local prag=150
    local cilj="_papiri_i_tekst"
    local jezgra
    jezgra=$(nproc)

    echo "Trenutni folder: $(pwd)"
    echo "Broj procesorskih jezgara koja će se koristiti: $jezgra"
    printf "Pretraži slike sa tekstom (prag: %s znakova) i premesti u '%s'? [d/N]: " "$prag" "$cilj"
    read -r odgovor
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
    command -v exiftool >/dev/null 2>&1 || { echo "❌  Greška: Instaliraj paket 'libimage-exiftool-perl'"; return 1; }
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

# [odrediste=FOTO_BEKAP_DIR] [izvor=.] - Proverava SMART zdravlje diska i kopira nove slike iz trenutnog foldera
foto-bekap() {
    local odrediste="${1:-$FOTO_BEKAP_DIR}"
    local izvor="${2:-.}"

    if [ -z "$odrediste" ]; then
        echo "❌ Greška: Nije definisan FOTO_BEKAP_DIR u local.env niti je prosleđena putanja."
        return 1
    fi

    if [ ! -d "$odrediste" ]; then
        echo "❌ Greška: Odredište '$odrediste' nije dostupno. Da li je eksterni disk povezan?"
        return 1
    fi

    if [ ! -d "$izvor" ]; then
        echo "❌ Greška: Izvorni folder '$izvor' ne postoji."
        return 1
    fi

    [[ "$izvor" != */ ]] && izvor="${izvor}/"

    local particija uredjaj
    particija=$(df --output=source "$odrediste" | tail -n 1)
    uredjaj="/dev/$(lsblk -no PKNAME "$particija" 2>/dev/null)"
    [[ "$uredjaj" == "/dev/" ]] && uredjaj=$(echo "$particija" | sed -E 's/p?[0-9]+$//')

    if command -v smartctl &>/dev/null && [[ -b "$uredjaj" ]]; then
        echo "🔍 Zdravlje diska ($uredjaj):"
        sudo smartctl -H "$uredjaj" | grep -E "SMART overall-health|result" || echo "⚠️ USB kontroler ne prosleđuje SMART podatke."
    fi

    echo "📸 Kopiram nove slike iz '$(realpath "$izvor")' u '$odrediste'..."
    rsync -rth --info=progress2 --ignore-existing --modify-window=2 "$izvor" "$odrediste"

    echo "💾 Zapisivanje keša na disk..."
    sync
    echo "✅ Gotovo! Sve nove slike su na disku."
}





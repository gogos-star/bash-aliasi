
# =================================================================
# [3. MREŽA, BEZBEDNOST I LG TV]
# =================================================================


# =================================================================
# Učitavanje lokalnih privatnih podešavanja (ako postoje)
# =================================================================
if [ -f "$HOME/.bash_tools/local.env" ]; then
    source "$HOME/.bash_tools/local.env"
fi

# Podrazumevane generičke vrednosti ako nisu definisane u local.env
if [ -z "${UREDJAJI+x}" ] || [ ${#UREDJAJI[@]} -eq 0 ]; then
    declare -gA UREDJAJI=(
        ["aa:bb:cc:dd:ee:01"]="Glavni Ruter"
        ["aa:bb:cc:dd:ee:02"]="Pametni TV"
    )
fi
export LG_TV_IP="${LG_TV_IP:-192.168.1.100}"
export LG_TV_KEY="${LG_TV_KEY:-$HOME/.ssh/id_rsa}"

#odredjivanje adrese mreze
_get_net() {
    ip -o -4 route show to default | awk '{print $3}' | sed 's/\.[0-9]*$/.0\/24/'
}

# Pomoćna funkcija koja prepoznaje MAC adrese i lepo formatira izlaz
_format_nmap() {
    local lista=""
    for k in "${!UREDJAJI[@]}"; do
        lista+="${k,,}=${UREDJAJI[$k]}"$'\n'
    done
    local moja_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')

    awk -v list="$lista" -v moja_ip="$moja_ip" '
    BEGIN {
        split(list, pairs, "\n")
        for (i in pairs) {
            split(pairs[i], kv, "=")
            if (kv[1] != "") macs[kv[1]] = kv[2]
        }
    }
    /^Nmap scan report for/ {
        if (ip != "" && ports != "") {
            printf "\033[1;33m💻 %s (%s)\033[0m\n%s\n", name, ip, ports
        }
        ip = $NF
        gsub(/[()]/, "", ip)
        ports = ""
        name = (ip == moja_ip && moja_ip != "") ? "Moj PC (Lokalno)" : "Nepoznat uređaj"
    }
    /^[0-9]+\/(tcp|udp)[[:space:]]+open/ {
        ports = ports "  -> " $0 "\n"
    }
    /^MAC Address:/ {
        mac = tolower($3)
        vendor = substr($0, index($0, "("))
        if (mac in macs) {
            name = macs[mac] " [" mac "]"
        } else {
            name = "Nepoznat " vendor " [" mac "]"
        }
    }
    END {
        if (ip != "" && ports != "") {
            printf "\033[1;33m💻 %s (%s)\033[0m\n%s\n", name, ip, ports
        }
    }'
}
# =================================================================
# netsken / ns [X] [v] - Skenira mrežu, portove i MAC imena (dodaj 'v' za verzije)
netsken() {
    local OPSEG=""
    local DETALJNO=""

    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            OPSEG="192.168.$arg.0/24"
        elif [[ "$arg" == "v" || "$arg" == "-v" ]]; then
            DETALJNO="-sV --version-intensity 0"
        fi
    done

    OPSEG="${OPSEG:-$(_get_net)}"
    if [ -z "$OPSEG" ]; then
        _err "❌ Greška: Niste na mreži niti ste uneli opseg (npr. netsken 4)"
        return 1
    fi

    _info "🌐 Skeniram opseg: $OPSEG ${DETALJNO:+(sa verzijama servisa)}..."
    sudo nmap -T4 -n --min-rate 1000 $DETALJNO -p 21,22,80,443,990,3389,8080,8443 --open "$OPSEG" \
    | sed '/unrecognized despite returning data/,/^$/d' \
    | _format_nmap
    _ok "✅ Skeniranje opsega $OPSEG završeno!"
}
# =================================================================
# torrentsken / ts [X] - Traži aktivne torrent klijente i uređaje u mreži
torrentsken() {
    local OPSEG="${1:-$(_get_net)}"
    [[ "$OPSEG" =~ ^[0-9]+$ ]] && OPSEG="192.168.$OPSEG.0/24"

    if [ -z "$OPSEG" ]; then
        _err "❌ Greška: Niste na mreži niti ste uneli opseg (npr. torrentsken 4)"
        return 1
    fi

    local MOJA_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    local RUTER_IP=$(ip -o -4 route show to default 2>/dev/null | awk '{print $3; exit}')
    local EXCLUDE_PARAM=""
    if [ -n "$RUTER_IP" ] && [ -n "$MOJA_IP" ]; then
        EXCLUDE_PARAM="--exclude $RUTER_IP,$MOJA_IP"
    elif [ -n "$RUTER_IP" ]; then
        EXCLUDE_PARAM="--exclude $RUTER_IP"
    fi

    _info "🧲 Tražim aktivne torrente na: $OPSEG..."
    sudo nmap -T4 -n --min-rate 1500 $EXCLUDE_PARAM -p 6881-6889,49152-65535 --open "$OPSEG" \
    | _format_nmap
    _ok "✅ Provera završena!"
}
# =================================================================
# websken / ws [IP] - Traži veb servere i naslove stranica
websken() {
    local CILJ="${1:-$(_get_net)}"
    if [ -z "$CILJ" ]; then
        _err "❌ Greška: Niste povezani na mrežu niti ste uneli cilj!"
        return 1
    fi

    _info "🕸️ Tražim veb servere na: $CILJ..."
    nmap -T4 -n --min-rate 1000 -p 80,443,8000,8080,8443 --open --script http-title,http-server-header "$CILJ"
    _ok "✅ Veb skeniranje završeno!"
}
# =================================================================
# net-info / ni - Prikaz lokalnih IP adresa i aktivnih portova računara
net-info() {
    printf "\n\033[1;35m========== 🌐 MREŽNI STATUS I PORTOVI 🌐 ==========\033[0m\n"
    _info "-> Lokalna IP adresa:"
    ip -br -c a
    printf "\n"
    _info "-> Aktivni portovi na računaru:"
    sudo ss -tulnp
    printf "\033[1;35m===================================================\033[0m\n\n"
}
# =================================================================
# [X Y u p] - Brzi SSH ulaz na uređaj u podmreži (npr. ssh-in 4 105 root 9922)
ssh-in() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        _warn "ℹ️ Upotreba: ssh-in X Y [korisnik] [port] (npr. ssh-in 4 105 root 9922)"
        return 1
    fi
    local KORISNIK="${3:-root}"
    local PORT="${4:-22}"
    _info "🔓 Povezivanje na SSH ($KORISNIK@192.168.$1.$2 - port $PORT)..."
    ssh -p "$PORT" "$KORISNIK@192.168.$1.$2"
}

# =================================================================
#                 LG WEBOS TV KONTROLA
# =================================================================
# tv-check / tv [X Y] - Ping i provera LG webOS TV portova
tv-check() {
    local IP="$LG_TV_IP"
    if [ -n "$1" ] && [ -n "$2" ]; then
        IP="192.168.$1.$2"
    elif [ -n "$1" ]; then
        _warn "ℹ️ Upotreba: tv (proverava $LG_TV_IP) ili tv X Y (npr. tv 1 105)"
        return 1
    fi

    _info "📺 Proveravam LG TV na adresi: $IP..."
    if ping -c 1 -W 1 "$IP" > /dev/null 2>&1; then
        _ok "✅ TV je dostupan na mreži (Ping OK)!"
        _info "🔍 Proveravam LG WebOS i SSH portove (22, 3000, 3001, 9922)..."
        nmap -T4 -n -p 22,3000,3001,9922 --open "$IP"
    else
        _err "❌ TV na adresi $IP nije dostupan (ugašen ili u standby modu)."
    fi
}
# =================================================================
# [IP p u] - SSH na LG TV pomoću ključa (npr. tv-ssh 192.168.1.100)
tv-ssh() {
    local IP="${1:-$LG_TV_IP}"
    local PORT="${2:-22}"
    local USER="${3:-root}"

    if [ ! -f "$LG_TV_KEY" ]; then
        _err "❌ Greška: SSH ključ $LG_TV_KEY nije pronađen!"
        return 1
    fi

    _info "📺 Povezivanje na LG TV ($USER@$IP:$PORT)..."
    ssh -i "$LG_TV_KEY" -p "$PORT" "$USER@$IP"
}
# =================================================================
# [komanda] - LG TV daljinski (off, reboot, toast, vol, youtube, screenoff, glass, install)
tv-cmd() {
    local AKCIJA="$1"
    if [ -z "$AKCIJA" ]; then
        _warn "ℹ️ Upotreba: tv-cmd [off | reboot | toast 'Tekst' | mute | unmute | vol 15 | youtube]"
        return 1
    fi

    _tv_exec() { ssh -i "$LG_TV_KEY" -o ConnectTimeout=3 root@"$LG_TV_IP" "$1"; }

    case "$AKCIJA" in
        off)     _info "📺 Gasim LG TV...";      _tv_exec "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOff '{}'" ;;
        reboot)  _info "🔄 Restartujem TV...";   _tv_exec "reboot" ;;
        toast)   _info "💬 Šaljem poruku...";    _tv_exec "luna-send -n 1 luna://com.webos.notification/createToast '{\"message\":\"${2:-Pozdrav sa Linuxa!}\"}'" ;;
        mute)    _info "🔇 Utišavam zvuk...";    _tv_exec "luna-send -n 1 luna://com.webos.audio/setMuted '{\"muted\":true}'" ;;
        unmute)  _info "🔊 Uključujem zvuk...";  _tv_exec "luna-send -n 1 luna://com.webos.audio/setMuted '{\"muted\":false}'" ;;
        vol)     _info "🔉 Zvuk na ${2:-15}..."; _tv_exec "luna-send -n 1 luna://com.webos.audio/setVolume '{\"volume\":${2:-15}}'" ;;
        youtube) _info "▶️ Pokrećem YouTube..."; _tv_exec "luna-send -n 1 luna://com.webos.applicationManager/launch '{\"id\":\"youtube.leanback.v4\"}'" ;;
        *)       _info "⚡ Izvršavam: $*";       _tv_exec "$*" ;;
                screenoff)
            _info "🌑 Gasim ekran (zvuk ostaje)..."
            _tv_exec "luna-send -n 1 luna://com.webos.service.tvpower/power/turnOffScreen '{\"standbyMode\":\"active\"}'"
            ;;
        glass)
            _info "🏠 Otvaram GlassHome..."
            _tv_exec "luna-send -n 1 luna://com.webos.applicationManager/launch '{\"id\":\"io.github.rorygallagher2024.lg-webos-dashboard\"}'"
            ;;
        install)
            local IPK="$2"
            if [ -z "$IPK" ] || [ ! -f "$IPK" ]; then
                _err "❌ Navedi ispravan .ipk fajl (npr. tv-cmd install aplikacija.ipk)"
                return 1
            fi
            local IME=$(basename "$IPK")
            local APP_ID=$(python3 -c "import tarfile, json; t=tarfile.open('$IPK'); d=tarfile.open(fileobj=t.extractfile('./data.tar.gz')); m=[x for x in d.getnames() if x.endswith('appinfo.json')][0]; print(json.load(d.extractfile(m))['id'])" 2>/dev/null)
            _info "📦 Šaljem $IME na TV..."
            scp -O -i "$LG_TV_KEY" "$IPK" root@"$LG_TV_IP":/tmp/ && \
            _info "⚙️ Instaliram ${APP_ID:-$IME}..." && \
            _tv_exec "luna-send -n 1 -f luna://com.webos.appInstallService/dev/install '{\"id\":\"${APP_ID:-com.example.app}\",\"ipkUrl\":\"/tmp/$IME\",\"subscribe\":false}'"
            ;;

    esac
}
# =================================================================
# kojenamrezi / kn [X] - Spisak svih aktivnih uređaja, IP i MAC adresa
kojenamrezi() {
    local OPSEG="${1:-$(_get_net)}"
    [[ "$OPSEG" =~ ^[0-9]+$ ]] && OPSEG="192.168.$OPSEG.0/24"

    _info "📡 Aktivni uređaji na mreži: $OPSEG..."
    sudo nmap -sn -n "$OPSEG" | awk -v list="$(for k in "${!UREDJAJI[@]}"; do echo "${k,,}=${UREDJAJI[$k]}"; done)" '
    BEGIN {
        split(list, pairs, "\n")
        for (i in pairs) {
            split(pairs[i], kv, "=")
            if (kv[1] != "") macs[kv[1]] = kv[2]
        }
    }
    /^Nmap scan report for/ { ip = $NF; gsub(/[()]/, "", ip) }
    /^MAC Address:/ {
        mac = tolower($3)
        vendor = substr($0, index($0, "("))
        ime = (mac in macs) ? "\033[1;32m" macs[mac] "\033[0m" : "\033[1;33mNepoznat " vendor "\033[0m"
        printf "  • %-15s -> %s [%s]\n", ip, ime, mac
    }'
    _ok "✅ Skeniranje uređaja završeno!"
}
# =================================================================
alias kn='kojenamrezi'
alias tv='tv-check'
alias ns='netsken'
alias ws='websken'
alias ni='net-info'
alias hakujtv="sudo python3 slopbro_packed.py --webos-version 10" # Pokreće slopbro exploit za LG TV
alias ts='torrentsken'

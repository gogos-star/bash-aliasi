# =================================================================
#                 POMOĆNE FUNKCIJE ZA BOJE I SERVISE
# =================================================================
_info() { printf "\033[1;34m%s\033[0m\n" "$*"; }
_ok()   { printf "\033[1;32m%s\033[0m\n" "$*"; }
_warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
_err()  { printf "\033[1;31m%s\033[0m\n" "$*"; }
_srv_stat() {
    printf "\033[1;34m-> %-17s\033[0m " "$1:"
    if systemctl is-active "$2" >/dev/null 2>&1; then
        _ok "✅ AKTIVAN"
    else
        _err "❌ ISKLJUČEN / MASKIRAN"
    fi
}

# =================================================================
# [5. POMOĆ I KORISNIČKI ALATI]
# =================================================================

# ["poruka"] - Dodaje izmene projekta, pravi commit i šalje na GitHub
git-izmeni() {
    if [ -z "$1" ]; then
        _warn "ℹ️ Upotreba: git-izmeni \"Opis izmene\""
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _err "❌ Greška: Trenutni folder nije Git repozitorijum!"
        return 1
    fi

    _info "📦 Dodajem izmene i pravim commit..."
    git add . && git commit -m "$*" && \
    _info "🚀 Šaljem na GitHub..." && \
    git push
}

# Prikazuje ovaj meni sa svim dostupnim alatima po kategorijama
pomoc() {
    printf "\n\033[1;35m========================== 🧰 DOS TOOLS MENI 🧰 ==========================\033[0m\n"

    awk '
    BEGIN {
        C_SEC="\033[1;33m"
        C_CMD="\033[1;32m"
        C_RESET="\033[0m"
    }
    # Prepoznavanje naziva kategorije: #[X. ...]
    /^#[[:space:]]*\[[0-9]+\.[^\]]+\]/ {
        match($0, /\[[0-9]+\.[^\]]+\]/)
        print "\n" C_SEC substr($0, RSTART, RLENGTH) C_RESET
        last_desc = ""
        next
    }
    # Komentar iznad komande (ako nije divider)
    /^#[[:space:]]+[^=]/ {
        sub(/^#[[:space:]]+/, "")
        last_desc = $0
        next
    }
    # Prepoznavanje aliasa (POSIX kompatibilno za mawk i gawk)
    /^[[:space:]]*alias[[:space:]]+[a-zA-Z0-9_-]+=/ {
        line = $0
        sub(/^[[:space:]]*alias[[:space:]]+/, "", line)
        eq_idx = index(line, "=")
        cmd = substr(line, 1, eq_idx - 1)
        rest = substr(line, eq_idx + 1)
        desc = last_desc
        last_desc = ""
        if (match(rest, /#[[:space:]]*.*$/)) {
            desc = substr(rest, RSTART, RLENGTH)
            sub(/^#[[:space:]]*/, "", desc)
        }
        if (desc != "") {
            format_and_print(cmd, desc)
        }
        next
    }
    # Prepoznavanje javnih funkcija (ignorišu se pomoćne koje počinju sa _)
    /^[a-zA-Z0-9_-]+\(\)[[:space:]]*\{/ {
        paren_idx = index($0, "()")
        cmd = substr($0, 1, paren_idx - 1)
        desc = last_desc
        last_desc = ""
        if (cmd !~ /^_/ && desc != "") {
            format_and_print(cmd, desc)
        }
        next
    }
    # Prazna linija poništava zaostali komentar
    /^[[:space:]]*$/ {
        last_desc = ""
    }

    function format_and_print(cmd, desc) {
        idx = index(desc, " - ")
        if (idx > 0) {
            prefix = substr(desc, 1, idx - 1)
            sub_desc = substr(desc, idx + 3)
            if (prefix ~ /^\[/) {
                cmd = cmd " " prefix
            } else {
                cmd = prefix
            }
            desc = sub_desc
        }
        printf "  " C_CMD "%-34s" C_RESET " - %s\n", cmd, desc
    }
    ' ~/.bash_tools/*.sh

    printf "\n\033[1;35m=========================================================================\033[0m\n\n"
}

alias aliasi="grep -hE '^(alias |[a-zA-Z0-9_-]+\(\))' ~/.zshrc ~/.bash_aliases ~/.bash_tools/*.sh 2>/dev/null | sed -E 's/^alias //; s/\(\).*//' | cut -d'=' -f1 | awk 'length(\$1) > 1' | column -x"  # Tabelarni prikaz svih dostupnih aliasa i funkcija

alias istorija='grep -e "Commandline:" /var/log/apt/history.log' # Pregled istorije instaliranih APT paketa

# =================================================================
#                 STARTNI STATUS PRI OTVARANJU TERMINALA
# =================================================================

if [[ $- == *i* ]]; then
    if [ "$TERM" = "linux" ]; then
        _ok "💻 [Debian Optimization System - DOS v2.1 by gogos --- TTY mode]"
    else
        REAL_BOOT_TIME=$(systemd-analyze 2>/dev/null | grep -oP '\+ \K[0-9min\s.]+s \(userspace\)' | sed 's/ (userspace)//')
        _ok "💻 [Debian Optimization System - DOS v2.1 by gogos]"
        [ -n "$REAL_BOOT_TIME" ] && _info "⏱️  Desktop (userspace) ready in: ${REAL_BOOT_TIME}"
        if command -v fastfetch >/dev/null 2>&1; then
            [ -f "$HOME/.config/fastfetch/desktop.json" ] && fastfetch --config "$HOME/.config/fastfetch/desktop.json" || fastfetch
        fi
    fi
    provera
fi

# =================================================================
#               PAMETNE TAB DOPUNE (AUTOCOMPLETE)]
# =================================================================

# Prikazuje spisak komandi koje podržavaju pametnu Tab dopunu
dopune() {
    printf "\n\033[1;35m========== ⌨️  KOMANDE SA PAMETNOM TAB DOPUNOM ⌨️  ==========\033[0m\n"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "stampac <Tab>" "on | off"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "gps <Tab>" "on | off | sat | signal | trazi"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "fontovi <Tab>" "ocisti | ms-remove"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "tv-cmd <Tab>" "off | reboot | toast | vol | install (.ipk)..."
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "disk-proveri <Tab>" "dinamički lista povezane diskove (sda, nvme...)"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "disk-sektor <Tab>" "dinamički lista povezane diskove (sda, nvme...)"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "popravi <Tab>" "dinamički lista FAT32 fleške (b1, c1...)"
    printf "  \033[1;32m%-22s\033[0m -> %s\n" "extract <Tab>" "nudi samo arhive (.zip, .rar, .7z, .tar...)"
    printf "\033[1;35m=============================================================\033[0m\n\n"
}

if [ -n "$ZSH_VERSION" ] && command -v compdef >/dev/null 2>&1; then

    # 1. Fiksne opcije za sistemske komande
    _dos_stampac() { _arguments '1:akcija:(on off)'; }
    _dos_gps()     { _arguments '1:akcija:(on off sat signal trazi)'; }
    _dos_fontovi() { _arguments '1:akcija:(ocisti ms-remove)'; }

    # 2. LG TV daljinski (nudi komande, a posle 'install' nudi samo .ipk fajlove)
    _dos_tv_cmd() {
        _arguments \
            '1:komanda:(off reboot toast mute unmute vol youtube screenoff glass install)' \
            '2:fajl:_files -g "*.ipk"'
    }

    # 3. Dinamički pronalazi povezane diskove (sda, sdb, nvme0n1...)
    _dos_diskovi() {
        local disks=(/sys/block/(sd*|nvme*)(N:t))
        _describe 'disk' disks
    }

    # 4. Dinamički pronalazi particije fleški (npr. b1, c1 za /dev/sdb1)
    _dos_fleske() {
        local parts=(/dev/sd[b-z][0-9]*(N:t))
        parts=(${parts#sd})
        _describe 'particija' parts
    }

    # 5. Raspakivanje - na Tab nudi samo arhive (.zip, .rar, .7z, .tar...)
    _dos_extract() {
        _files -g '*.(tar|tar.gz|tgz|tar.bz2|tbz2|tar.xz|txz|tar.zst|zip|rar|7z|gz|bz2|Z)'
    }

    # Povezivanje funkcija sa komandama
    compdef _dos_stampac stampac
    compdef _dos_gps gps
    compdef _dos_fontovi fontovi
    compdef _dos_tv_cmd tv-cmd
    compdef _dos_diskovi disk-proveri disk-sektor
    compdef _dos_fleske popravi
    compdef _dos_extract extract

elif [ -n "$BASH_VERSION" ]; then
    # Osnovna podrška i za Bash
    complete -W "on off" stampac
    complete -W "on off sat signal trazi" gps
    complete -W "ocisti ms-remove" fontovi
    complete -W "off reboot toast mute unmute vol youtube screenoff glass install" tv-cmd
fi

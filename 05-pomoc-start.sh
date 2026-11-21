
# =================================================================
#                 POMOĆNE FUNKCIJE ZA BOJE I SERVISE i GIThub
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

# =============================================================
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
alias git-izmeni="git-izmeni" # ["poruka"] - Dodaje izmene projekta, pravi commit i šalje na GitHub
# =================================================================
# [5. POMOĆ I KORISNIČKI ALATI]
# =================================================================

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
    # Prepoznavanje aliasa
    /^[[:space:]]*alias[[:space:]]+[a-zA-Z0-9_-]+=/ {
        match($0, /^[[:space:]]*alias[[:space:]]+([^=]+)=(.*)$/, m)
        cmd = m[1]
        rest = m[2]
        desc = last_desc
        last_desc = ""
        if (match(rest, /#[[:space:]]*(.*)$/, c)) {
            desc = c[1]
        }
        if (desc != "") {
            format_and_print(cmd, desc)
        }
        next
    }
    # Prepoznavanje javnih funkcija (ignorišu se pomoćne koje počinju sa _)
    /^[a-zA-Z0-9_-]+\(\)[[:space:]]*\{/ {
        match($0, /^([a-zA-Z0-9_-]+)\(\)/, m)
        cmd = m[1]
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

alias aliasi="grep -hE '^(alias |[a-zA-Z0-9_-]+\(\))' ~/.bash_aliases ~/.bash_tools/*.sh | sed -E 's/^alias //; s/\(\).*//' | cut -d'=' -f1 | awk 'length(\$1) > 1' | column -x" # Tabelarni prikaz svih dostupnih aliasa i funkcija

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
        _info "⏱️  Desktop (userspace) ready in: ${REAL_BOOT_TIME}"

        if command -v fastfetch >/dev/null 2>&1; then
        [ -f "$HOME/.config/fastfetch/desktop.json" ] && fastfetch --config "$HOME/.config/fastfetch/desktop.json" || fastfetch
        fi
    fi
    provera
fi



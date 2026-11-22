

# =================================================================
# [1. SISTEM, DIJAGNOSTIKA I HARDVER]
# =================================================================
alias edit='mcedit'                               # Brzi tekstualni editor (Midnight Commander)
alias birajeditor='_info "📝 Otvaram izbor sistemskog editora..."; sudo update-alternatives --config editor' # Izbor podrazumevanog sistemskog editora
alias sacuvaj-podesavanja='_info "💾 Pravim bekap u /home..."; sudo tar -czf ~/podesavanja_backup_$(date +%Y-%m-%d).tar.gz /etc ~/.bash_aliases ~/.bash_tools ~/.bashrc ~/.ssh 2>/dev/null && _ok "✅ Bekap je sačuvan!"' # Bekap /etc, ~/.bash_tools, .bashrc i .ssh u /home
alias cirilica2='systemctl --user set-environment LANG=sr_RS.UTF-8 LC_ALL=sr_RS.UTF-8 && _ok "✅ Sistemski jezik: ćirilica"' # Postavlja sistemski jezik na ćirilicu (okruženje)
alias cirilica='export LANG=sr_RS.UTF-8 LC_ALL=sr_RS.UTF-8 && _ok "✅ Sesija: ćirilica"' # Prebacuje sesiju terminala na ćirilicu
alias latinica='export LANG=sr_RS.UTF-8@latin LC_ALL=sr_RS.UTF-8@latin && _ok "✅ Sesija: latinica"' # Prebacuje sesiju terminala na latinicu
alias engleski='export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && _ok "✅ Sesija: engleski"' # Prebacuje sesiju terminala na engleski

# [tekst] - Preslovljava tekst u clipboard-u (ili prosleđeni tekst) između ćirilice i latinice
preslovi() {
    local skripta="$HOME/.bash_tools/scripts/preslovi.py"

    # Provera da li postoji alat za clipboard (xclip ili wl-clipboard)
    if [ -n "$WAYLAND_DISPLAY" ] && ! command -v wl-copy &> /dev/null; then
        echo "❌ Nedostaje paket 'wl-clipboard' (instaliraj: sudo apt install wl-clipboard)"
        return 1
    elif [ -z "$WAYLAND_DISPLAY" ] && ! command -v xclip &> /dev/null; then
        echo "❌ Nedostaje paket 'xclip' (instaliraj: sudo apt install xclip)"
        return 1
    fi

    if [ $# -gt 0 ]; then
        # Ako je prosleđen tekst kao argument, stavi ga u clipboard i preslovi
        if [ -n "$WAYLAND_DISPLAY" ]; then
            printf "%s" "$*" | wl-copy
        else
            printf "%s" "$*" | xclip -i -selection clipboard
        fi
    fi

    python3 "$skripta"
    echo "✅ Tekst u clipboard-u je uspešno preslovljen."
}


alias resplasma='_info "🔄 Restartujem KDE Plasma 6..."; kquitapp6 plasmashell 2>/dev/null || killall plasmashell; kstart plasmashell > /dev/null 2>&1 &' # Restartuje samo KDE Plasma 6 panel (bez gašenja programa)
alias reskde='_info "🔄 Restartujem SDDM..."; sudo systemctl restart sddm' # Restartuje ceo grafički server (SDDM)
alias servisi='provera && systemctl list-unit-files --type=service --state=enabled' # Spisak omogućenih systemd servisa
alias tajmeri='systemctl list-timers --all'        # Spisak svih zakazanih systemd tajmera
alias tajming='systemd-analyze && echo "-----" && systemd-analyze critical-chain && echo "-----" && systemd-analyze blame | head -n 15 && echo "-----" && systemctl --failed' # Brzina podizanja sistema (systemd-analyze)
alias sredi-grub='_info "⚙️ Ažuriram initramfs i GRUB..."; sudo update-initramfs -u -k all && sudo update-grub && _ok "✅ GRUB je uspešno osvežen!"' # Osvežavanje initramfs-a i GRUB menija
alias tlpstat='sudo tlp-stat -s' # Statistika baterije i TLP napajanja
alias temp="watch -n 2 'sensors'"  # Praćenje temperature senzora uživo (na 2 sekunde)
# =================================================================
#                 DIJAGNOSTIKA I KONTROLA SERVISA
# =================================================================
# Status servisa, RAM, CPU temperatura, disk i lokalna IP
provera() {
    printf "\n\033[1;35m================ 🛠️ DIJAGNOSTIKA SISTEMA 🛠️ ================\033[0m\n"
    _srv_stat "GPS Servis" "gpsd.service"
    _srv_stat "Štampač   (CUPS)" "cups"
    _srv_stat "TLP servis" "tlp.service"
    _srv_stat "AD Guard" "AdGuardHome.service"

    # 1. RAM sa pragovima (žuto >= 70%, crveno >= 85%)
    printf "\033[1;34m-> %-17s\033[0m " "Iskorišćen RAM:"
    free -m | awk 'NR==2{
        pct = $3 * 100 / $2;
        if (pct >= 85) color = "\033[1;31m";
        else if (pct >= 70) color = "\033[1;33m";
        else color = "\033[0;32m";
        printf "%s%sMB / %sMB (%.2f%%)\033[0m\n", color, $3, $2, pct
    }'

    # 2. CPU Temperatura (zeleno < 70°C, žuto 70-84°C, crveno trepćuće + zvuk >= 85°C)
    local CPU_TEMP_FILE="/sys/class/thermal/thermal_zone5/temp"
    if [ -r "$CPU_TEMP_FILE" ] && [ "$(< /sys/class/thermal/thermal_zone5/type)" = "x86_pkg_temp" ]; then
        local RAW_TEMP=$(< "$CPU_TEMP_FILE")
        local TEMP_C=$((RAW_TEMP / 1000))
        local TEMP_DEC=$(((RAW_TEMP % 1000) / 100))

        if [ "$TEMP_C" -ge 85 ]; then
            printf "\a\033[1;34m-> %-17s\033[0m \033[1;5;31m%d.%d°C 🔥 !!!\033[0m\n" "Temperatura CPU:" "$TEMP_C" "$TEMP_DEC"
        elif [ "$TEMP_C" -ge 70 ]; then
            printf "\033[1;34m-> %-17s\033[0m \033[1;33m%d.%d°C ⚠️\033[0m\n" "Temperatura CPU:" "$TEMP_C" "$TEMP_DEC"
        else
            printf "\033[1;34m-> %-17s\033[0m \033[0;32m%d.%d°C\033[0m\n" "Temperatura CPU:" "$TEMP_C" "$TEMP_DEC"
        fi
    fi

    # 3. Prostor na disku (žuto >= 80%, crveno >= 90%)
    printf "\033[1;34m-> %-17s\033[0m " "Prostor na disku:"
    df -h / | awk 'NR==2{
        gsub(/%/, "", $5);
        pct = $5 + 0;
        if (pct >= 90) color = "\033[1;31m";
        else if (pct >= 80) color = "\033[1;33m";
        else color = "\033[0;32m";
        printf "%s%s slobodno od %s (iskorišćeno %s - %d%%)\033[0m\n", color, $4, $2, $3, pct
    }'

    local ROUTE_INFO=$(ip -4 route get 1.1.1.1 2>/dev/null)
    local IFACE=$(awk '{print $5; exit}' <<< "$ROUTE_INFO")
    local LOKALNA_IP=$(awk '{print $7; exit}' <<< "$ROUTE_INFO")

    printf "\033[1;34m-> %-17s\033[0m " "Lokalna IP adresa:"
    if [ -n "$LOKALNA_IP" ]; then
        local MAC_ADDR=$(< /sys/class/net/"$IFACE"/address)
        _ok "🌐 $LOKALNA_IP ($IFACE | $MAC_ADDR)"
    else
        _err "⚠️ Niste povezani"
    fi
    printf "\033[1;35m=============================================================\033[0m\n\n"
}

# [on|off] - Uključuje ili potpuno blokira/maskira CUPS štampač
stampac() {
    case "$1" in
        on)
            _info "🔄 Aktiviram servise štampača..."
            sudo systemctl unmask cups cups.path cups.socket 2>/dev/null
            sudo systemctl enable --now cups cups.path cups.socket
            _ok "✅ Štampač je UKLJUČEN!"
            ;;
        off)
            _info "🛑 Gasim i maskiram štampač..."
            sudo systemctl disable --now cups cups.path cups.socket 2>/dev/null
            sudo systemctl mask cups cups.path cups.socket
            _warn "🔒 Štampač je ISKLJUČEN i blokiran!"
            ;;
        *) _warn "ℹ️ Upotreba: stampac [on | off]" ;;
    esac
    _srv_stat "Štampač (CUPS)" "cups"
}

# [on|off|sat|signal|trazi] - Kontrola GPS servisa i satelitskog signala
gps() {
    case "$1" in
        on)
            _info "📡 Pokrećem GPS servis..."
            sudo systemctl unmask gpsd.socket gpsd.service >/dev/null 2>&1
            sudo systemctl enable --now gpsd.socket gpsd.service >/dev/null 2>&1
            ;;
        off)
            _info "🛑 Gasim GPS servis..."
            sudo systemctl disable --now gpsd.socket gpsd.service >/dev/null 2>&1
            sudo systemctl mask gpsd.socket gpsd.service >/dev/null 2>&1
            ;;
        sat)
            printf "\033[1;34m🛰️ Broj satelita je: \033[0m"
            gpspipe -w -n 15 | grep -m 1 "SKY" | jq ".satellites | length"
            ;;
        signal)
            printf "\033[1;34m📶 Jačina signala je: \033[0m"
            local ss=$(gpspipe -w -n 15 | grep -m 1 "SKY" | jq "[.satellites[]? | select(.used==true) | .ss] | if length > 0 then (add / length | round) else 0 end")
            printf "%s dB\n" "$ss"
            ;;
        trazi)
            printf "\033[1;35m🔍 Pokretanje pretrage... (Ctrl+C za prekid)\033[0m\n"
            while true; do
                local ss=$(gpspipe -w -n 15 | grep -m 1 "SKY" | jq "[.satellites[]? | select(.used==true) | .ss] | if length > 0 then (add / length | round) else 0 end")
                if [ "$ss" -eq 0 ]; then _err "❌ Jačina: $ss dB-Hz (Nema signala)"
                elif [ "$ss" -le 25 ]; then _err "⚠️ Jačina: $ss dB-Hz (Loš setup)"
                elif [ "$ss" -le 35 ]; then _warn "📶 Jačina: $ss dB-Hz (Solidan signal)"
                else printf "\a"; _ok "🎉 Jačina: $ss dB-Hz ---> SIGNAL JE ODLIČAN! <---"
                fi
                sleep 2
            done
            ;;
        *) _warn "ℹ️ Upotreba: gps [on | off | sat | signal | trazi]" ;;
    esac
    _srv_stat "GPS Servis" "gpsd.service"
}

osvezi_sistem() {
    local GRESKA=0
    for f in ~/.bashrc ~/.bash_aliases ~/.bash_tools/*.sh; do
        if [ -f "$f" ] && ! bash -n "$f"; then
            _err "⚠️ Problem u fajlu: $f"
            GRESKA=1
        fi
    done
    if [ $GRESKA -eq 0 ]; then
        source ~/.bashrc
        systemctl --user daemon-reload 2>/dev/null
        _ok "✅ Svi moduli su provereni i osveženi!"
    else
        _err "❌ GREŠKA U SINTAKSI: Izmene nisu učitane!"
    fi
}
alias osvezi="osvezi_sistem" # Provera sintakse i ponovno učitavanje svih alata


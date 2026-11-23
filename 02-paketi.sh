# =================================================================
# [2. ODRŽAVANJE, PAKETI I DISKOVI]
# =================================================================

alias disk-proveri='sudo smartctl -H /dev/sdX'   # Brza provera diska (PASSED/FAILED)
alias disk-sektor='sudo smartctl -A /dev/sdX'   # Detalji: gledaj Reallocated_Sector_Ct i Pending_Sector

# Kompletno ažuriranje sistema (APT upgrade + Flatpak + Snap)
sysupdate() {
        _info "🔄 Osvežavam listu paketa..."
        sudo apt update || { _err "❌ Greška pri osvežavanju liste paketa!"; return 1; }

        _info "⬆ Nadograđujem sistem (Full Upgrade)..."
        sudo apt full-upgrade -y || { _err "❌ Greška pri nadogradnji paketa!"; return 1; }

        _info "🗑 Uklanjam nepotrebne pakete i čistim keš..."
        sudo apt autoremove --purge -y
        sudo apt clean

        # Opciono: ažuriranje Flatpak paketa (ako ih koristiš)
        if command -v flatpak &>/dev/null; then
            _info "📦 Ažuriram Flatpak pakete..."
            flatpak update -y
        fi

        # Opciono: ažuriranje Snap paketa (ako ih koristiš)
        if command -v snap &>/dev/null; then
            _info "⚡ Ažuriram Snap pakete..."
            sudo snap refresh
        fi

        _ok "✅ Sistem je uspešno ažuriran!"

        # Provera da li je potreban restart
        if [ -f /var/run/reboot-required ]; then
            _warn "⚠ Potrebno je ponovno pokretanje sistema (Restart required)!"
        fi
    }


# genclean / generalno-ciscenje - Duboko čišćenje sistema, stranih rečnika, keša i logova
generalno-ciscenje() {
    _info "🧹 Pokrećem generalno čišćenje sistema..."
    sudo systemctl stop packagekit 2>/dev/null

    _info "🗑️ Uklanjam strane rečnike i azijske pakete..."
    sudo apt purge -y hunspell-zh-cn hunspell-zh-tw hunspell-zh-hk hunspell-ko hunspell-vi \
                     aspell-am aspell-fo aspell-ga aspell-is aspell-ku aspell-lt aspell-lv \
                     myspell-tl myspell-af myspell-bg \
                     fcitx fcitx-* fcitx5 fcitx5-* uim uim-* chewing* pinyin* anthy* m17n* \
                     plasma-thunderbolt >/dev/null 2>&1

    sudo apt purge -y "*-l10n-*" "*-localization-*" "*-translation-*" "language-pack-*" >/dev/null 2>&1
    sudo apt install -y kde-l10n-en-gb 2>/dev/null

    sysupdate

    _info "🧹 Čistim stare konfiguracije, Flatpak i logove..."
    command -v flatpak &> /dev/null && flatpak uninstall --unused -y &>/dev/null
    if [ "$(dpkg -l | grep -c '^rc')" -gt 0 ]; then
        sudo apt purge -y $(dpkg -l | grep '^rc' | awk '{print $2}') >/dev/null 2>&1
    fi
    sudo journalctl --vacuum-time=2d 2>/dev/null

    killall -9 discover plasma-discover 2>/dev/null
    sudo rm -rf /var/crash/* /var/lib/systemd/coredump/* ~/.cache/drkonqi/*
    sudo systemctl start packagekit 2>/dev/null
    _ok "✨ Sistem je potpuno očišćen i optimizovan!"
}
alias genclean='generalno-ciscenje'

# [ocisti|ms-remove] - Upravljanje fontovima (čišćenje azijskih ili MS fontova)
fontovi() {
    case "$1" in
        ocisti)
            _info "🗑️ Uklanjam nepotrebne sistemske fontove..."
            sudo apt remove --purge -y fonts-kacst fonts-lao fonts-lklug-sinhala fonts-sil-abyssinica fonts-sil-padauk fonts-tibetan fonts-khmeros-core fonts-navilu fonts-samayak-fonts fonts-smc* fonts-pagul fonts-guru* fonts-amiri* fonts-gujr* fonts-beng* fonts-deva*
            sudo apt purge -y fonts-noto-core fonts-noto-extra fonts-noto-ui-core fonts-noto-cjk fonts-noto-mono
            sudo apt autoremove --purge -y && fc-cache -f -v
            _ok "✅ Nepotrebni fontovi su očišćeni."
            ;;
        ms-remove)
            _info "🗑️ Uklanjam Microsoft fontove..."
            sudo apt purge -y ttf-mscorefonts-installer
            rm -rf ~/.local/share/fonts/msfonts
            sudo apt autoremove -y && fc-cache -fv
            _ok "✅ Microsoft fontovi su uklonjeni."
            ;;
        *) _warn "ℹ️ Upotreba: fontovi [ocisti | ms-remove]" ;;
    esac
}

# =================================================================
#                 ARHIVE, HARDVER I LOGOVI
# =================================================================
# [fajl] - Univerzalno raspakivanje arhiva (zip, rar, 7z, tar.gz...)
extract() {
    if [ ! -f "$1" ]; then _err "❌ '$1' fajl nije ispravan"; return 1; fi
    _info "📦 Raspakujem '$1'..."
    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
         *.bz2)            bunzip2 "$1" ;;
        *.rar)            unrar x "$1" ;;
        *.gz)             gunzip "$1" ;;
        *.tar)            tar xf "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *)                _err "❌ '$1' ne može biti otpakovan"; return 1 ;;
    esac
    _ok "✅ Uspešno raspakovano!"
}

# [slovo] - Popravka FAT32 fleške (npr. popravi b1 za /dev/sdb1)
popravi() {
    if [ -z "$1" ]; then _err "❌ Greška: Unesi slovo fleške (npr. popravi b1)"; return 1; fi
    _info "🔧 Popravljam /dev/sd$1..."
    sudo umount "/dev/sd$1" 2>/dev/null
    sudo fsck.vfat -a "/dev/sd$1"
    _ok "✅ Gotovo!"
}

# Dijagnostika ACPI putanja i prekida za PCI uređaje
proveri-acpi() {
    printf "\n=== VEZA IZMEĐU PCI UREĐAJA I ACPI PUTANJA ===\n\n"
    for d in /sys/bus/pci/devices/*; do
        pci_id=$(basename "$d")
        acpi_path=$(cat "$d/firmware_node/path" 2>/dev/null)
        [ -n "$acpi_path" ] && printf "%-10s -> %-25s | %s\n" "$pci_id" "$acpi_path" "$(lspci -s "$pci_id")"
    done
    printf "\n=== STATUS GPE PREKIDA U SISTEMU ===\n\n"
    grep . /sys/firmware/acpi/interrupts/gpe* | grep -v "  0"
}

# Dijagnostika i sortiranje aktivnih hardverskih GPE prekida
gpeprekid() {
    printf "%-12s %-12s %-12s\n" "GPE PREKID" "BROJ" "STATUS"
    echo "--------------------------------------"
    for f in /sys/firmware/acpi/interrupts/gpe*; do
        name=$(basename "$f")
        val=$(awk '{print $1}' "$f")
        status=$(awk '{print $2}' "$f")
        [ "$val" -ne 0 ] 2>/dev/null && printf "%-12s %-12s %-12s\n" "$name" "$val" "$status"
    done | sort -rn -k2
}

# Vizuelni prikaz sistemskih logova uživo u zelenom terminalu
haker() {
    trap 'printf "\033[0m"; clear; return' INT
    printf "\033[40;92m"
    clear
    echo "========================================================"
    echo "       INICIJALIZACIJA SISTEMSKOG SKENIRANJA...          "
    echo "========================================================"
    sleep 1
    sudo -v
    sudo journalctl -f | grep --line-buffered -Ev "wireplumber|drkonqi|wireless extensions|locale|gtk.portal|nvme|ModemMan" | while read -r linija; do
        echo "$linija"
        sleep 0.05
    done
}

# [id_ekstenzije] - Instalira KGet (ako fali) i povezuje KGet ekstenziju za Chrome/Chromium/Brave
kget-chrome() {
    local ext_dir="$HOME/.bash_tools/scripts/kget-mv3"
    local ext_id="$1"
    local browser_dirs=(
        "$HOME/.config/google-chrome"
        "$HOME/.config/chromium"
        "$HOME/.config/BraveSoftware/Brave-Browser"
        "$HOME/.config/vivaldi"
        "$HOME/.config/microsoft-edge"
    )

    if ! command -v kget >/dev/null 2>&1; then
        echo "Instaliram KGet..."
        sudo apt update && sudo apt install -y kget
    fi

    chmod +x "$ext_dir/kget_host.py"

    if [ -z "$ext_id" ]; then
        echo "1. Otvori stranicu za ekstenzije (chrome://extensions/ ili brave://extensions/)"
        echo "2. Uključi 'Developer mode' -> 'Load unpacked'"
        echo "3. Izaberi folder: $ext_dir"
        echo ""
        read -rp "Nalepi ID učitane ekstenzije: " ext_id
    fi

    if [ -z "$ext_id" ]; then
        echo "Greška: Nije unet ID ekstenzije."
        return 1
    fi

    local povezano=0
    for b_dir in "${browser_dirs[@]}"; do
        if [ -d "$b_dir" ]; then
            mkdir -p "$b_dir/NativeMessagingHosts"
            cat << JSON > "$b_dir/NativeMessagingHosts/com.kget.capture.json"
{
  "name": "com.kget.capture",
  "description": "KGet Native Messaging Host",
  "path": "$ext_dir/kget_host.py",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$ext_id/"
  ]
}
JSON
            echo "✔ Povezano za: $(basename "$b_dir")"
            povezano=$((povezano + 1))
        fi
    done

    if [ "$povezano" -eq 0 ]; then
        echo "Nije pronađen nijedan podržani pregledač u ~/.config/."
        return 1
    fi
}

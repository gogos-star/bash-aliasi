# 🧰 Bash Aliasi i Sistemski Alati (Debian / Linux) - DOS

Modularna, čista i automatizovana kolekcija Bash aliasa, funkcija i alata optimizovanih za **Debian 13 (Trixie)** i **KDE Plasma 6**, ali primenljivih na većini savremenih Linux distribucija.

---

## 📂 Struktura projekta

Svi alati su tematski podeljeni u zasebne module unutar foldera `~/.bash_tools/`:

| Fajl | Kategorija | Ključne mogućnosti |
| :--- | :--- | :--- |
| **`01-sistem.sh`** | **Sistem, Dijagnostika i Hardver** | Dijagnostika hardvera (`provera` - RAM, CPU temperatura, disk, IP), praćenje senzora (`temp`), TLP napajanje (`tlpstat`), restart KDE panela (`resplasma`) i SDDM-a (`reskde`), bekap konfiguracija (`sacuvaj-podesavanja`), promena jezika sesije (`cirilica`, `latinica`, `engleski`), kontrola štampača (`stampac`) i GPS-a (`gps`). |
| **`02-paketi.sh`** | **Održavanje, Paketi i Diskovi** | Kompletno ažuriranje (`sysupdate` za APT, Flatpak i Snap), dubinsko čišćenje (`genclean` / `generalno-ciscenje`), čišćenje fontova (`fontovi`), univerzalno raspakivanje arhiva (`extract`), popravka FAT32 USB fleški (`popravi`), ACPI dijagnostika (`proveri-acpi`, `gpeprekid`). |
| **`03-mreza-tv.sh`** | **Mreža, Bezbednost i LG TV** | Skeniranje uređaja na mreži (`kojenamrezi` / `kn`), skeniranje otvorenih portova (`netsken` / `ns`), pretraga torenta (`torrentsken` / `ts`), skeniranje veb servera (`websken` / `ws`), mrežni status računara (`net-info` / `ni`), brzi SSH ulaz (`ssh-in`), daljinska kontrola LG webOS TV-a (`tv-check`, `tv-ssh`, `tv-cmd`). |
| **`04-build.sh`** | **Kompajliranje i Pakovanje (.deb)** | Smart-build automatizacija koja kompajlira projekat i automatski ga pakuje u `.deb` paket: `cmake-smart-build` (CMake), `make-smart-build` (Autotools/Make), `meson-smart-build` (Meson/Ninja), `pnpm-smart-build` (Nx/Electron), `pnpm-vite-build` (Vite frontend). |
| **`05-pomoc-start.sh`** | **Pomoć i Korisnički Alati** | Dinamički samogenerišući meni (`pomoc`), startni status sistem dijagnostike pri otvaranju terminala, brzi tabelarni pregled svih aliasa (`aliasi`) i istorija instalacija (`istorija`). |
| **`~/.bash_tools/scripts/`**| **Pomoćne Python skripte** | `preslovi.py` za dvosmerno preslovljavanje ćirilice i latinice (`preslovi`).|
---

## 🚀 Kako funkcioniše komanda `pomoc`

Komanda **`pomoc`** koristi ugrađeni dinamički parser napisan u `awk`-u. Za razliku od uobičajenih statičkih pomoći, ovaj meni se **generiše potpuno automatski** čitanjem samih skripti u realnom vremenu:

1. **Automatsko prepoznavanje kategorija:** Zaglavlja u fajlovima (npr. `#[1. SISTEM, DIJAGNOSTIKA I HARDVER]`) postaju naslovi sekcija u meniju.
2. **Čitanje opisa:**
   - Ako alias ima inline komentar:
     ```bash
     alias tlpstat='sudo tlp-stat -s' # Statistika baterije i TLP napajanja
     ```
   - Ili ako funkcija ima komentar iznad sebe:
     ```bash
     # [on|off] - Uključuje ili potpuno blokira/maskira CUPS štampač
     stampac() { ... }
     ```
   Parser sam prepoznaje naziv komande, argumente u zagradama `[...]` i opis, te ih formatira u pregledne kolone sa bojama.
3. **Nula održavanja:** Kada dodaš novu funkciju ili alias sa komentarom, komanda `pomoc` ga odmah prikazuje bez ikakve potrebe da ručno dopisuješ spiskove!

---

## 🛠️ Instalacija

### 1. Kloniranje repozitorijuma
Klonirajte ovaj repozitorijum direktno u vaš korisnički folder kao `~/.bash_tools`:
```bash
git clone https://github.com/gogos-star/bash-aliasi.git ~/.bash_tools
```

### 2. Povezivanje sa `~/.bashrc`
Uverite se da vaš `~/.bash_aliases` učitava ove module. Ako već nemate `~/.bash_aliases`, dodajte sledeće u vaš `~/.bashrc` (ili u `~/.bash_aliases`):
```bash
if [ -d ~/.bash_tools ]; then
    for modul in ~/.bash_tools/*.sh; do
        [ -r "$modul" ] && source "$modul"
    done
fi
```

### 3. Privatna lokalna podešavanja (`local.env`)
Kako privatne IP i MAC adrese vaših kućnih uređaja ne bi dospele na javni Git, možete kreirati fajl `~/.bash_tools/local.env` (koji je automatski u `.gitignore`):

```bash
# ~/.bash_tools/local.env
declare -gA UREDJAJI=(
    ["aa:bb:cc:11:22:33"]="Moj Ruter"
    ["dd:ee:ff:44:55:66"]="Kamera"
)

export LG_TV_IP="192.168.1.50"
export LG_TV_KEY="$HOME/.ssh/moj_kljuc"
```
### 4. Skripta `~/.bash_tools/scripts/preslovi.py`
zahteva `xclip` (za X11) ili `wl-clipboard` (za Wayland) ili instalirajte `sudo apt install xclip wl-clipboard nmap`

---

## 💡 Korišćenje

Nakon što otvorite novi terminal (ili pokrenete `source ~/.bashrc`), dostupne su sve komande:
- **`pomoc`** — Prikazuje interaktivni pregled svih dostupnih alata i njihov opis.
- **`osvezi`** — Proverava sintaksu svih modula pomoću `bash -n` i ponovo ih učitava bez restarta terminala.
- **`provera`** — Brzi status RAM memorije, temperature procesora, slobodnog diska i ključnih servisa.
- **`sysupdate`** — Jednom komandom ažurira APT, Flatpak i Snap pakete.
- itd.
---

## 🎓 Šta početnici mogu da nauče iz ovog repozitorijuma

Ovaj projekat je zamišljen i kao praktičan vodič za sve koji tek ulaze u svet **Debian / Linux** terminala i žele da vide kako se od običnih komandi gradi uredno, bezbedno i automatizovano radno okruženje:

* **Modularna organizacija skripti:** Umesto jednog pretrpanog `.bashrc` fajla od hiljadu linija, konfiguracija je podeljena u manje, pregledne celine po temama (`01`–`05`).
* **Praktična upotreba Linux alata:** Kroz stvarne primere možeš videti kako rade i kako se kombinuju `awk`, `sed`, `grep`, `systemd`, `ip`, `ss` i `nmap`.
* **Bezbedno čuvanje osetljivih podataka:** Odvajanje privatnih IP/MAC adresa i putanja do SSH ključeva u `local.env` (uz `.gitignore`) sprečava slučajno objavljivanje lokalnih podataka na GitHub.
* **Provera sintakse pre učitavanja:** Funkcija `osvezi` pokazuje kako se skripte prvo testiraju (`bash -n`) pre nego što se primene u aktivnoj sesiji, čime se izbegavaju greške pri pokretanju terminala.
* **Dvosmerno preslovljavanje:** Funkcija `preslovi` putem clipboard-a pretvara ćirilicu u latinicu i obrnuto  preko skripte scripts/preslovi.py (uz podršku za X11 `xclip` i Wayland `wl-clipboard`).
* **Kontrola eksternih uređaja (IoT / TV):** Kroz modul za LG webOS prikazano je kako se preko SSH-a i JSON poruka (`luna-send`) upravlja pametnim uređajima na lokalnoj mreži direktno iz komandne linije.

---

## 📄 Licenca
Ovaj projekat je otvorenog koda pod [MIT licencom](LICENSE).

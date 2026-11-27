# =================================================================
# [4. KOMPAJLIRANJE I PAKOVANJE (.DEB)]
# =================================================================

# Kompajlira CMake projekat i pakuje ga u .deb (preko checkinstall)
cmake-smart-build() {
    [ -n "$ZSH_VERSION" ] && setopt local_options null_glob
    local APP_NAME=$(basename "$PWD" | tr '[:upper:]_' '[:lower:]-' | tr -cd '[:alnum:]-' | sed 's/^-*//;s/-*$//')
    local CURRENT_DIR="$PWD"

    if [ ! -f "CMakeLists.txt" ]; then
        echo "❌ Грешка: Налазите се у фолдеру који нема CMakeLists.txt!"
        return 1
    fi

    echo "============================================="
    echo " НАПРЕДНО КРЕИРАЊЕ .DEB ПАКЕТА: $APP_NAME"
    echo "============================================="

    local DETECTED_VERSION=$(grep -i -E 'VERSION\s+[0-9.]+' CMakeLists.txt | head -n 1 | grep -o -E '[0-9.]+' | head -n 1)
    if [ -z "$DETECTED_VERSION" ]; then
        DETECTED_VERSION=$(grep -i -E 'set\s*\(.*VERSION.*\)' CMakeLists.txt | head -n 1 | grep -o -E '[0-9.]+' | head -n 1)
    fi
    local APP_VERSION=${DETECTED_VERSION:-0.1}
    echo "📊 Пронађена верзија: $APP_VERSION"

    sudo mkdir -p /usr/lib/kf6/kauth/libexec
    rm -rf build && mkdir build && cd build || return 1

    if ! cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release ..; then
        echo "❌ Грешка у CMake конфигурацији!"
        cd "$CURRENT_DIR" && return 1
    fi

    if ! make -j"$(nproc)"; then
        echo "❌ Грешка током компајлирања!"
        cd "$CURRENT_DIR" && return 1
    fi

    sudo checkinstall --pkgname="$APP_NAME" --pkgversion="$APP_VERSION" --backup=no --deldoc=yes --deldesc=yes --delspec=yes --install=no --fstrans=no -y

    local DEB_FILE=$(ls *.deb 2>/dev/null | head -n 1)
    if [ -f "$DEB_FILE" ]; then
        cp "$DEB_FILE" ~/Downloads/"${APP_NAME}"_"${APP_VERSION}"_amd64.deb
        echo "✅ Готов пакет је сачуван као: ~/Downloads/${APP_NAME}_${APP_VERSION}_amd64.deb"
    else
        echo "❌ .deb пакет није успешно креиран!"
        cd "$CURRENT_DIR" && return 1
    fi

    cd "$CURRENT_DIR" && cd ..
    printf "❓ Да ли желите да ОБРИШЕТЕ изворни код из фолдера %s? (y/N): " "$CURRENT_DIR"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        rm -rf "$CURRENT_DIR"
        echo "🗑️  Изворни код је обрисан."
    fi
}
# =================================================================

# Kompajlira Autotools/Make projekat i pakuje ga u .deb
make-smart-build() {
    [ -n "$ZSH_VERSION" ] && setopt local_options null_glob
    command -v checkinstall >/dev/null 2>&1 || { echo "❌ Greška: Instaliraj 'checkinstall' (sudo apt install checkinstall)"; return 1; }

    local APP_NAME=$(basename "$PWD" | tr '[:upper:]_' '[:lower:]-' | tr -cd '[:alnum:]-' | sed 's/^-*//;s/-*$//')
    local CURRENT_DIR="$PWD"

    if [ ! -f "configure" ] && [ ! -f "autogen.sh" ] && [ ! -f "configure.ac" ] && [ ! -f "Makefile" ]; then
        echo "❌ Грешка: Ово није Autotools/Make пројекат!"
        return 1
    fi

    echo "============================================="
    echo " AUTOTOOLS / MAKE КРЕИРАЊЕ .DEB: $APP_NAME"
    echo "============================================="

    if [ ! -f "configure" ]; then
        if [ -f "autogen.sh" ]; then
            chmod +x autogen.sh && ./autogen.sh || return 1
        elif [ -f "configure.ac" ]; then
            autoreconf -fi || return 1
        fi
    fi

    local DETECTED_VERSION=""
    if [ -f "configure" ]; then
        DETECTED_VERSION=$(grep -E "^PACKAGE_VERSION=" configure | head -n 1 | grep -o -E '[0-9.]+' | head -n 1)
    fi
    if [ -z "$DETECTED_VERSION" ]; then
        DETECTED_VERSION=$(echo "$PWD" | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | tail -n 1)
    fi
    local APP_VERSION=${DETECTED_VERSION:-0.1}
    echo "📊 Пронађена верзија: $APP_VERSION"

    if [ -f "configure" ]; then
        if ! ./configure --prefix=/usr; then
            echo "❌ Грешка у ./configure! Провери да ли фале -dev библиотеке."
            return 1
        fi
    fi

    [ -f "Makefile" ] && sed -i 's/webkit2gtk-4.0/webkit2gtk-4.1/g' Makefile

    if ! make -j"$(nproc)"; then
        echo "❌ Грешка током компајлирања!"
        return 1
    fi

    sudo checkinstall --pkgname="$APP_NAME" --pkgversion="$APP_VERSION" --backup=no --deldoc=yes --deldesc=yes --delspec=yes --install=no --fstrans=no -y

    local DEB_FILE=$(ls *.deb 2>/dev/null | head -n 1)
    if [ -f "$DEB_FILE" ]; then
        cp "$DEB_FILE" ~/Downloads/"${APP_NAME}"_"${APP_VERSION}"_amd64.deb
        echo "✅ Готов пакет је сачуван као: ~/Downloads/${APP_NAME}_${APP_VERSION}_amd64.deb"
    else
        echo "❌ .deb пакет није креиран!"
        return 1
    fi

    cd ..
    printf "❓ Да ли желите да ОБРИШЕТЕ изворни код из фолдера %s? (y/N): " "$CURRENT_DIR"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        rm -rf "$CURRENT_DIR"
        echo "🗑️  Изворни код је обрисан."
    fi
}
# =================================================================

# Kompajlira Meson/Ninja projekat i pakuje ga u .deb
meson-smart-build() {
    [ -n "$ZSH_VERSION" ] && setopt local_options null_glob
    command -v checkinstall >/dev/null 2>&1 || { echo "❌ Greška: Instaliraj 'checkinstall' (sudo apt install checkinstall)"; return 1; }

    local APP_NAME=$(basename "$PWD" | tr '[:upper:]_' '[:lower:]-' | tr -cd '[:alnum:]-' | sed 's/^-*//;s/-*$//')
    local CURRENT_DIR="$PWD"

    if [ ! -f "meson.build" ]; then
        echo "❌ Грешка: Фолдер нема meson.build фајл!"
        return 1
    fi

    echo "============================================="
    echo " MESON + NINJA КРЕИРАЊЕ .DEB: $APP_NAME"
    echo "============================================="

    local DETECTED_VERSION=$(grep -E "version\s*:" meson.build | head -n 1 | grep -o -E '[0-9.]+' | head -n 1)
    local APP_VERSION=${DETECTED_VERSION:-0.1}
    echo "📊 Пронађена верзија: $APP_VERSION"

    rm -rf build
    if ! meson setup build --prefix=/usr --buildtype=release; then
        echo "❌ Грешка у meson setup конфигурацији!"
        return 1
    fi

    if ! ninja -C build -j"$(nproc)"; then
        echo "❌ Грешка током ninja компајлирања!"
        return 1
    fi

    cd build || return 1
    sudo checkinstall --pkgname="$APP_NAME" --pkgversion="$APP_VERSION" --backup=no --deldoc=yes --deldesc=yes --delspec=yes --install=no --fstrans=no -y ninja install

    local DEB_FILE=$(ls *.deb 2>/dev/null | head -n 1)
    if [ -f "$DEB_FILE" ]; then
        cp "$DEB_FILE" ~/Downloads/"${APP_NAME}"_"${APP_VERSION}"_amd64.deb
        echo "✅ Готов пакет је сачуван као: ~/Downloads/${APP_NAME}_${APP_VERSION}_amd64.deb"
    else
        echo "❌ .deb пакет није креиран!"
        cd "$CURRENT_DIR" && return 1
    fi

    cd "$CURRENT_DIR" && cd ..
    printf "❓ Да ли желите да ОБРИШЕТЕ изворни код из фолдера %s? (y/N): " "$CURRENT_DIR"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        rm -rf "$CURRENT_DIR"
        echo "🗑️  Изворни код је обрисан."
    fi
}
# =================================================================

# Low-RAM build za Electron/Nx aplikacije (npr. IPTVnator)
pnpm-smart-build() {
    [ -n "$ZSH_VERSION" ] && setopt local_options null_glob
    echo "🧹 0. Automatsko čišćenje zaostalih grešaka i keša..."
    rm -rf node_modules .nx apps/xtream-mock-server dist 2>/dev/null
    rm -f moj-builder.config.js index.js 2>/dev/null

    if [ -f "nx.json" ]; then
        cp nx.json nx.json.bak 2>/dev/null
        node -e "
        const fs = require('fs');
        if (fs.existsSync('nx.json')) {
            const nx = JSON.parse(fs.readFileSync('nx.json', 'utf8'));
            if (nx.plugins) {
                nx.plugins = nx.plugins.filter(p => {
                    const name = typeof p === 'string' ? p : p.plugin;
                    return !name.includes('jest') && !name.includes('playwright');
                });
                fs.writeFileSync('nx.json', JSON.stringify(nx, null, 2));
                console.log('✓ Privremeno neutralisani nekompatibilni Nx test-pluginovi.');
            }
        }
        " 2>/dev/null
    fi

    echo "📦 1. Instalacija zavisnosti u singl-thread režimu..."
    pnpm config set dangerouslyAllowAllBuilds true --location project 2>/dev/null
    pnpm install \
        --config.engine-strict=false \
        --child-concurrency=1 \
        --config.allow-unused-patches=true \
        --config.dangerously-allow-all-builds=true || return 1

    echo "📥 Dodajem krovne alate (bez menjanja verzije Nx-a)..."
    pnpm add -D astro aria-query axobject-query html-escaper nx-electron @nx/esbuild @angular/build \
        --config.engine-strict=false \
        --config.allow-unused-patches=true \
        --config.dangerously-allow-all-builds=true 2>/dev/null

    echo "⚙️ 2. Krpljenje metapodataka..."
    pnpm pkg set homepage="https://github.com" author="Goran <goran@example.com>" description="m3u-editor" 2>/dev/null

    if [ ! -d "apps/xtream-mock-server" ]; then
        mkdir -p apps/xtream-mock-server
        cat << 'EOF' > apps/xtream-mock-server/project.json
{
  "name": "xtream-mock-server",
  "targets": { "build": { "executor": "nx:noop" } }
}
EOF
    fi

    export NODE_OPTIONS="--max-old-space-size=2560"
    export NX_DAEMON=false
    export NX_INPUTS_VALIDATION=false
    export DISABLE_NX_VERSION_CHECK=true

    echo "🚀 3. Pokrećem prevođenje frontenda (Astro - Failsafe Režim)..."
    if [ -d "apps/web" ]; then
        (cd apps/web && pnpm --package=node@22 dlx astro build)
    fi

    echo "⚙️ 4. Pokrećem krovni Nx build (Serijski režim)..."
    pnpm exec nx reset 2>/dev/null
    pnpm exec nx show projects
    pnpm exec nx run-many -t build --configuration=production --parallel=1

    echo "📦 5. Priprema i pokretanje Electron Builder-a..."
    local NX_OUT_DIR=""
    if [ -d "dist/apps/electron-backend" ]; then
        NX_OUT_DIR="dist/apps/electron-backend"
    elif [ -d "dist/apps/iptvnator" ]; then
        NX_OUT_DIR="dist/apps/iptvnator"
    elif [ -d "dist/apps/web-backend" ]; then
        NX_OUT_DIR="dist/apps/web-backend"
    fi

    if [ -z "$NX_OUT_DIR" ] || [ ! -f "$NX_OUT_DIR/main.js" ]; then
        local FOUND_MAIN=$(find dist -name "main.js" 2>/dev/null | head -n 1)
        if [ -n "$FOUND_MAIN" ]; then
            NX_OUT_DIR=$(dirname "$FOUND_MAIN")
        else
            echo "❌ Greška: Kompajlirani main.js nije pronađen!"
            [ -f "nx.json.bak" ] && mv nx.json.bak nx.json 2>/dev/null
            return 1
        fi
    fi

    cp package.json "$NX_OUT_DIR/package.json" 2>/dev/null
    [ -f "electron-builder.json" ] && cp electron-builder.json "$NX_OUT_DIR/electron-builder.json" 2>/dev/null

    cat << 'EOF' > "$NX_OUT_DIR/moj-builder.config.js"
const fs = require('fs');
let baseConfig = {};
if (fs.existsSync('electron-builder.json')) {
    baseConfig = JSON.parse(fs.readFileSync('electron-builder.json', 'utf8'));
}
delete baseConfig.afterPack;
module.exports = {
    ...baseConfig,
    compression: "store",
    electronVersion: "32.0.0",
    extraMetadata: {
        ...baseConfig.extraMetadata,
        "main": "main.js"
    },
    directories: {
        output: "../../../dist/executables"
    },
    files: ["**/*"]
};
EOF

    pnpm dlx electron-builder --linux deb AppImage --config moj-builder.config.js --projectDir="$NX_OUT_DIR"
    local BUILD_RES=$?

    rm -rf apps/xtream-mock-server 2>/dev/null
    rm -f moj-builder.config.js index.js 2>/dev/null
    rm -f "$NX_OUT_DIR/moj-builder.config.js" "$NX_OUT_DIR/electron-builder.json" 2>/dev/null
    pnpm config delete dangerouslyAllowAllBuilds --location project 2>/dev/null
    unset NODE_OPTIONS
    [ -f "nx.json.bak" ] && mv nx.json.bak nx.json 2>/dev/null

    if [ $BUILD_RES -eq 0 ] && [ -d "dist/executables" ]; then
        echo -e "\e[1;32m✅ USPEŠNO! Paketi vas čekaju u dist/executables/\e[0m"
        ls -lh dist/executables/*.deb dist/executables/*.AppImage 2>/dev/null
    else
        echo "❌ Greška tokom konačnog pakovanja aplikacije!"
        return 1
    fi
}

# =================================================================

# WASM/Low-RAM build za Vite frontend projekte
pnpm-vite-build() {
    echo "🧹 0. Čišćenje starih build foldera i keša..."
    rm -rf node_modules public/build dist 2>/dev/null

    if [ ! -f "package.json" ]; then
        echo "❌ Greška: package.json nije pronađen u ovom folderu!"
        return 1
    fi

    local HAD_WORKSPACE=0
    if [ -f "pnpm-workspace.yaml" ]; then
        cp pnpm-workspace.yaml pnpm-workspace.yaml.bak
        HAD_WORKSPACE=1
    fi

    cat << 'EOF' >> pnpm-workspace.yaml

dangerouslyAllowAllBuilds: true
verifyDepsBeforeRun: false
overrides:
  rollup: "npm:@rollup/wasm-node"
  lightningcss: "npm:lightningcss-wasm"
  esbuild: "npm:esbuild-wasm"
EOF

    pnpm install --no-frozen-lockfile --child-concurrency=1 --config.engine-strict=false --config.allow-unused-patches=true --config.dangerously-allow-all-builds=true
    if [ $? -ne 0 ]; then
        echo "❌ Greška tokom instalacije zavisnosti!"
        [ $HAD_WORKSPACE -eq 1 ] && mv pnpm-workspace.yaml.bak pnpm-workspace.yaml || rm -f pnpm-workspace.yaml
        return 1
    fi

    export NODE_OPTIONS="--max-old-space-size=2560"
    pnpm --config.verify-deps-before-run=false run build
    local BUILD_RES=$?
    unset NODE_OPTIONS

    [ $HAD_WORKSPACE -eq 1 ] && mv pnpm-workspace.yaml.bak pnpm-workspace.yaml || rm -f pnpm-workspace.yaml

    if [ $BUILD_RES -eq 0 ]; then
        echo -e "\e[1;32m✅ USPEŠNO! Vite frontend je kompajliran!\e[0m"
        ls -lh public/build dist 2>/dev/null
    else
        echo "❌ Greška tokom Vite build-a!"
        return 1
    fi
}

# =================================================================

# Instalira sveže napravljen .deb paket iz dist/executables/
pnpm-install-deb() {
    [ -n "$ZSH_VERSION" ] && setopt local_options null_glob
    local DEB_FILE=$(ls dist/executables/*.deb 2>/dev/null | head -n 1)
    if [ -n "$DEB_FILE" ]; then
        echo "📥 Pronađen paket: $DEB_FILE"
        sudo apt install -y "./$DEB_FILE" && \
        echo -e "\e[1;32m✅ APLIKACIJA JE USPEŠNO INSTALIRANA NA SISTEM!\e[0m"
    else
        echo "❌ Greška: .deb paket nije pronađen u dist/executables/ folderu!"
        return 1
    fi
}


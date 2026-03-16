#!/usr/bin/env bash
# setup-linux.sh — Configuration initiale d'une machine Linux
# Installe : zsh, oh-my-zsh, plugins, bat, gdu, bpytop
# Validé sur Debian Bookworm/Trixie, DietPi, Raspberry Pi OS

set -e

# ─── Couleurs ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
ask()  { echo -e "${YELLOW}? $1${NC}"; }

# ─── Menu interactif ─────────────────────────────────────────────────────────
echo -e "\n${BLUE}╔══════════════════════════════════════╗"
echo -e   "║      Setup Linux — Options           ║"
echo -e   "╚══════════════════════════════════════╝${NC}\n"

ask "Désactiver le Wi-Fi ? (machine headless/serveur) [o/N]"
read -r DISABLE_WIFI

ask "Installer AdGuard Home ? [o/N]"
read -r INSTALL_ADGUARD

# ─── 1. Paquets ──────────────────────────────────────────────────────────────
step "Installation des paquets"
sudo apt update -qq
sudo apt install -y zsh git curl bat gdu bpytop mc \
    dnsutils tcpdump nmap iftop ufw unattended-upgrades

# Sur Debian/RPiOS, bat s'appelle batcat
BAT_BIN=$(which batcat 2>/dev/null || which bat 2>/dev/null)
ok "Paquets installés (bat: $BAT_BIN)"

# ─── 2. Symlink cat → bat ────────────────────────────────────────────────────
if [[ "$BAT_BIN" == */batcat ]]; then
    step "Symlink cat → batcat"
    sudo ln -sf "$BAT_BIN" /usr/local/bin/cat
    ok "Symlink créé : /usr/local/bin/cat → $BAT_BIN"
fi

# ─── 3. Oh My Zsh ────────────────────────────────────────────────────────────
step "Installation Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh déjà installé, ignoré."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installé"
fi

# ─── 4. Plugins ──────────────────────────────────────────────────────────────
step "Installation des plugins zsh"

PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"

if [[ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
    ok "zsh-autosuggestions cloné"
else
    echo "zsh-autosuggestions déjà présent, ignoré."
fi

if [[ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting cloné"
else
    echo "zsh-syntax-highlighting déjà présent, ignoré."
fi

# ─── 5. Configuration .zshrc ─────────────────────────────────────────────────
step "Configuration .zshrc"
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
sed -i 's/^plugins=.*/plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

# Titre d'onglet terminal : hostname au repos, hostname - commande en cours
if ! grep -q "DISABLE_AUTO_TITLE" "$HOME/.zshrc"; then
    sed -i '/^ZSH_THEME=/a DISABLE_AUTO_TITLE="true"' "$HOME/.zshrc"
    cat >> "$HOME/.zshrc" <<'EOF'

# Titre onglet terminal
function _set_tab_title_idle()    { print -Pn "\e]0;%m\a" }
function _set_tab_title_running() { print -Pn "\e]0;%m - $1\a" }
precmd_functions+=(_set_tab_title_idle)
preexec_functions+=(_set_tab_title_running)
EOF
fi
ok "Thème agnoster + plugins + titre onglet configurés"

# ─── 6. Fix locale (DietPi) ──────────────────────────────────────────────────
if [[ -f /etc/dietpi/.version ]]; then
    step "Fix locale UTF-8 (DietPi)"
    if ! grep -q "LANG=C.UTF-8" "$HOME/.zshrc"; then
        sed -i '1s/^/export LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n/' "$HOME/.zshrc"
        ok "Locale C.UTF-8 ajoutée en tête de .zshrc"
    fi
    if ! grep -q "dietpi.bash" "$HOME/.zshrc"; then
        echo -e "\n# DietPi integration (aliases dietpi-* + banniere login)" >> "$HOME/.zshrc"
        echo "[[ -f /etc/bashrc.d/dietpi.bash ]] && source /etc/bashrc.d/dietpi.bash" >> "$HOME/.zshrc"
        ok "Intégration DietPi ajoutée"
    fi
fi

# ─── 7. Shell par défaut ─────────────────────────────────────────────────────
step "Changement du shell par défaut"
ZSH_PATH=$(which zsh)
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    sudo chsh -s "$ZSH_PATH" "$(whoami)"
    ok "Shell par défaut → $ZSH_PATH (effectif à la prochaine connexion)"
else
    echo "zsh est déjà le shell par défaut."
fi

# ─── 8. Désactivation Wi-Fi ──────────────────────────────────────────────────
if [[ "${DISABLE_WIFI,,}" == "o" ]]; then
    step "Désactivation du Wi-Fi"
    CONFIG_TXT="/boot/firmware/config.txt"
    [[ ! -f "$CONFIG_TXT" ]] && CONFIG_TXT="/boot/config.txt"
    if ! grep -q "disable-wifi" "$CONFIG_TXT"; then
        echo "dtoverlay=disable-wifi" | sudo tee -a "$CONFIG_TXT" > /dev/null
        ok "Wi-Fi désactivé de façon permanente dans $CONFIG_TXT"
    else
        echo "Wi-Fi déjà désactivé dans $CONFIG_TXT."
    fi
    sudo nmcli radio wifi off 2>/dev/null || true
fi

# ─── 9. AdGuard Home ─────────────────────────────────────────────────────────
if [[ "${INSTALL_ADGUARD,,}" == "o" ]]; then
    step "Installation AdGuard Home"
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    ok "AdGuard Home installé — accès initial : http://$(hostname -I | awk '{print $1}'):3000"
fi

echo -e "\n${GREEN}Installation terminée. Reconnecte-toi pour activer zsh.${NC}\n"

#!/usr/bin/env bash
# setup-linux.sh — Configuration initiale d'une machine Linux
# Installe : zsh, oh-my-zsh, plugins, bat, gdu, bpytop
# Validé sur Debian Bookworm/Trixie, DietPi, Raspberry Pi OS

set -e

# ─── Couleurs ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }

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
ok "Thème agnoster + plugins configurés"

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

echo -e "\n${GREEN}Installation terminée. Reconnecte-toi pour activer zsh.${NC}\n"

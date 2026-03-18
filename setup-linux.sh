#!/usr/bin/env bash
# setup-linux.sh — Configuration initiale d'une machine Linux
# Installe : zsh, oh-my-zsh, plugins, bat, gdu, bpytop
# Validé sur Debian Bookworm/Trixie, DietPi, Raspberry Pi OS

set -e

# ─── Log ─────────────────────────────────────────────────────────────────────
LOGFILE="/var/log/setup-linux.log"
sudo touch "$LOGFILE" && sudo chmod 644 "$LOGFILE"
exec > >(sudo tee -a "$LOGFILE") 2>&1
echo -e "\n=== setup-linux.sh démarré le $(date) ==="

# ─── Couleurs (terminal uniquement, pas dans le log) ─────────────────────────
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
    GREEN=''; BLUE=''; YELLOW=''; RED=''; NC=''
fi

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
ask()  { echo -e "${YELLOW}? $1${NC}" > /dev/tty; }
warn() { echo -e "${RED}⚠ $1${NC}"; }

prompt() {
    local question="$1" default="$2"
    if [[ -n "$default" ]]; then
        ask "$question [$default]"
    else
        ask "$question"
    fi
    read -r REPLY </dev/tty
    if [[ -z "$REPLY" ]]; then REPLY="$default"; fi
}

# Validation IP (ex: 192.168.1.1 ou 192.168.1.1/24)
validate_ip() {
    local ip="${1%%/*}"  # enlève le masque si présent
    local mask="${1##*/}" # masque seul (vide si pas de /)
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! "$ip" =~ $regex ]]; then return 1; fi
    IFS='.' read -ra octets <<< "$ip"
    for o in "${octets[@]}"; do
        if (( o > 255 )); then return 1; fi
    done
    if [[ "$1" == */* ]]; then
        if ! [[ "$mask" =~ ^[0-9]+$ ]] || (( mask < 0 || mask > 32 )); then return 1; fi
    fi
    return 0
}

prompt_ip() {
    local question="$1" default="$2" require_mask="${3:-false}"
    while true; do
        prompt "$question" "$default"
        if [[ -z "$REPLY" ]]; then
            warn "Adresse IP requise." > /dev/tty; continue
        fi
        if [[ "$require_mask" == "true" && "$REPLY" != */* ]]; then
            warn "Format requis : IP/masque (ex: 192.168.1.10/24)" > /dev/tty; continue
        fi
        local ip_part="${REPLY%%/*}"
        if ! validate_ip "$REPLY"; then
            warn "'$REPLY' n'est pas une adresse IP valide." > /dev/tty; continue
        fi
        break
    done
}

# ─── Menu interactif ─────────────────────────────────────────────────────────
echo -e "\n${BLUE}╔══════════════════════════════════════╗
║      Setup Linux — Options           ║
╚══════════════════════════════════════╝${NC}\n" > /dev/tty

ask "Désactiver le Wi-Fi ? (machine headless/serveur) [o/N]"
read -r DISABLE_WIFI </dev/tty

ask "Installer AdGuard Home ? [o/N]"
read -r INSTALL_ADGUARD </dev/tty

ask "Configurer le réseau (hostname, IP, VLAN...) ? [o/N]"
read -r CONFIGURE_NETWORK </dev/tty

# ─── Collecte des infos réseau ───────────────────────────────────────────────
if [[ "${CONFIGURE_NETWORK,,}" == "o" ]]; then
    echo "" > /dev/tty
    CURRENT_HOSTNAME=$(hostname)
    CURRENT_IFACE=$(nmcli -t -f NAME,TYPE con show --active | grep -i ethernet | head -1 | cut -d: -f1 || true)

    prompt "Nouveau hostname" "$CURRENT_HOSTNAME"
    NET_HOSTNAME="$REPLY"

    prompt "Interface principale (connection NetworkManager)" "$CURRENT_IFACE"
    NET_CON="$REPLY"

    prompt "Renommer cette connexion (laisser vide pour garder '$NET_CON')"
    NET_CON_RENAME="$REPLY"

    prompt_ip "Adresse IP principale (ex: 192.168.1.10/24)" "" true
    NET_IP="$REPLY"

    prompt_ip "Gateway"
    NET_GW="$REPLY"

    prompt_ip "DNS primaire" "1.1.1.1"
    NET_DNS1="$REPLY"

    prompt "DNS secondaire (laisser vide si aucun)"
    NET_DNS2="$REPLY"
    if [[ -n "$NET_DNS2" ]] && ! validate_ip "$NET_DNS2"; then
        warn "DNS secondaire invalide, ignoré." > /dev/tty
        NET_DNS2=""
    fi

    echo "" > /dev/tty
    ask "Créer une interface VLAN ? [o/N]"
    read -r ADD_VLAN </dev/tty

    if [[ "${ADD_VLAN,,}" == "o" ]]; then
        prompt "ID du VLAN (ex: 1020)"
        VLAN_ID="$REPLY"

        prompt_ip "Adresse IP du VLAN (ex: 10.10.20.1/24)" "" true
        VLAN_IP="$REPLY"

        prompt "Gateway VLAN (laisser vide si aucune)"
        VLAN_GW="$REPLY"
        if [[ -n "$VLAN_GW" ]] && ! validate_ip "$VLAN_GW"; then
            warn "Gateway VLAN invalide, ignorée." > /dev/tty
            VLAN_GW=""
        fi
    fi
fi

# ─── Résumé et confirmation ───────────────────────────────────────────────────
echo -e "\n${BLUE}╔══════════════════════════════════════╗
║         Résumé des modifications     ║
╚══════════════════════════════════════╝${NC}" > /dev/tty

echo -e "${BLUE}Paquets & shell :${NC} zsh, oh-my-zsh, bat, gdu, bpytop, mc, dnsutils, tcpdump, nmap, iftop, ufw, unattended-upgrades" > /dev/tty
[[ "${DISABLE_WIFI,,}" == "o" ]]    && echo -e "${BLUE}Wi-Fi :${NC} désactivé (permanent)" > /dev/tty
[[ "${INSTALL_ADGUARD,,}" == "o" ]] && echo -e "${BLUE}AdGuard Home :${NC} installation" > /dev/tty

if [[ "${CONFIGURE_NETWORK,,}" == "o" ]]; then
    echo -e "${BLUE}Réseau :${NC}" > /dev/tty
    [[ "$NET_HOSTNAME" != "$(hostname)" ]] && echo -e "  Hostname : $(hostname) → $NET_HOSTNAME" > /dev/tty
    [[ -n "$NET_CON_RENAME" ]] && echo -e "  Connexion renommée : $NET_CON → $NET_CON_RENAME" > /dev/tty
    echo -e "  IP : $NET_IP  GW : $NET_GW  DNS : $NET_DNS1${NET_DNS2:+, $NET_DNS2}" > /dev/tty
    [[ "${ADD_VLAN,,}" == "o" ]] && echo -e "  VLAN $VLAN_ID : $VLAN_IP${VLAN_GW:+  GW: $VLAN_GW}" > /dev/tty
    warn "⚠ Le changement d'IP réseau mettra fin à cette session SSH." > /dev/tty
fi

echo "" > /dev/tty
ask "Confirmer et lancer l'installation ? [o/N]"
read -r CONFIRM </dev/tty
if [[ "${CONFIRM,,}" != "o" ]]; then
    echo "Installation annulée."
    exit 0
fi

# ─── 1. Mise à jour du système ───────────────────────────────────────────────
step "Mise à jour du système"
sudo apt update -qq
sudo apt upgrade -y
ok "Système à jour"

# ─── 2. Installation des paquets ─────────────────────────────────────────────
step "Installation des paquets"
sudo apt install -y zsh git curl bat gdu bpytop mc \
    dnsutils tcpdump nmap iftop ufw unattended-upgrades

BAT_BIN=$(which batcat 2>/dev/null || which bat 2>/dev/null)
ok "Paquets installés (bat: $BAT_BIN)"

# ─── 3. Symlink cat → bat ────────────────────────────────────────────────────
if [[ "$BAT_BIN" == */batcat ]]; then
    step "Symlink cat → batcat"
    sudo ln -sf "$BAT_BIN" /usr/local/bin/cat
    ok "Symlink créé : /usr/local/bin/cat → $BAT_BIN"
fi

# ─── 4. Oh My Zsh ────────────────────────────────────────────────────────────
step "Installation Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "Oh My Zsh déjà installé, ignoré."
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installé"
fi

# ─── 5. Plugins ──────────────────────────────────────────────────────────────
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

# ─── 6. Configuration .zshrc ─────────────────────────────────────────────────
step "Configuration .zshrc"
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
sed -i 's/^plugins=.*/plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

if ! grep -q "_set_tab_title_idle" "$HOME/.zshrc"; then
    sed -i 's/^#*\s*DISABLE_AUTO_TITLE.*/DISABLE_AUTO_TITLE="true"/' "$HOME/.zshrc"
    if ! grep -q 'DISABLE_AUTO_TITLE="true"' "$HOME/.zshrc"; then
        sed -i '/^ZSH_THEME=/a DISABLE_AUTO_TITLE="true"' "$HOME/.zshrc"
    fi
    cat >> "$HOME/.zshrc" <<'EOF'

# Titre onglet terminal
function _set_tab_title_idle()    { print -Pn "\e]0;%m\a" }
function _set_tab_title_running() { print -Pn "\e]0;%m - $1\a" }
precmd_functions+=(_set_tab_title_idle)
preexec_functions+=(_set_tab_title_running)
EOF
fi
ok "Thème agnoster + plugins + titre onglet configurés"

# ─── 7. Fix locale (DietPi) ──────────────────────────────────────────────────
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

# ─── 8. Shell par défaut ─────────────────────────────────────────────────────
step "Changement du shell par défaut"
ZSH_PATH=$(which zsh)
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    sudo chsh -s "$ZSH_PATH" "$(whoami)"
    ok "Shell par défaut → $ZSH_PATH (effectif à la prochaine connexion)"
else
    echo "zsh est déjà le shell par défaut."
fi

# ─── 9. Désactivation Wi-Fi ──────────────────────────────────────────────────
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

# ─── 10. AdGuard Home ────────────────────────────────────────────────────────
if [[ "${INSTALL_ADGUARD,,}" == "o" ]]; then
    step "Installation AdGuard Home"
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    ok "AdGuard Home installé — accès initial : http://$(hostname -I | awk '{print $1}'):3000"
fi

# ─── 11. Configuration réseau ────────────────────────────────────────────────
if [[ "${CONFIGURE_NETWORK,,}" == "o" ]]; then
    step "Configuration réseau"

    if [[ "$NET_HOSTNAME" != "$(hostname)" ]]; then
        if command -v raspi-config &>/dev/null; then
            sudo raspi-config nonint do_hostname "$NET_HOSTNAME"
        else
            sudo hostnamectl set-hostname "$NET_HOSTNAME"
            sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NET_HOSTNAME/" /etc/hosts
        fi
        ok "Hostname → $NET_HOSTNAME"
    fi

    if [[ -n "$NET_CON_RENAME" && "$NET_CON_RENAME" != "$NET_CON" ]]; then
        sudo nmcli con mod "$NET_CON" connection.id "$NET_CON_RENAME"
        ok "Connexion renommée : $NET_CON → $NET_CON_RENAME"
        NET_CON="$NET_CON_RENAME"
    fi

    DNS_ENTRIES="$NET_DNS1"
    if [[ -n "$NET_DNS2" ]]; then DNS_ENTRIES="$NET_DNS1,$NET_DNS2"; fi

    sudo nmcli con mod "$NET_CON" \
        ipv4.addresses "$NET_IP" \
        ipv4.gateway   "$NET_GW" \
        ipv4.dns       "$DNS_ENTRIES" \
        ipv4.method    manual

    if [[ "${ADD_VLAN,,}" == "o" ]]; then
        VLAN_CON="eth0.${VLAN_ID}"
        PHYS_IFACE=$(nmcli -t -f GENERAL.DEVICES con show "$NET_CON" 2>/dev/null | cut -d: -f2 || true)
        if [[ -z "$PHYS_IFACE" ]]; then PHYS_IFACE="eth0"; fi

        nmcli con del "$VLAN_CON" 2>/dev/null || true

        VLAN_ARGS=(type vlan con-name "$VLAN_CON" dev "$PHYS_IFACE" id "$VLAN_ID"
                   ipv4.addresses "$VLAN_IP" ipv4.method manual)
        if [[ -n "$VLAN_GW" ]]; then VLAN_ARGS+=(ipv4.gateway "$VLAN_GW"); fi

        sudo nmcli con add "${VLAN_ARGS[@]}"
        sudo nmcli con up "$VLAN_CON"
        ok "VLAN $VLAN_ID → $VLAN_IP configuré sur $VLAN_CON"
    fi

    warn "Application de la nouvelle config IP — la session SSH va se couper."
    sudo nmcli con up "$NET_CON" || true
fi

echo -e "\n${GREEN}Installation terminée. Log : $LOGFILE${NC}"
echo -e "${GREEN}Reconnecte-toi sur $(echo $NET_IP | cut -d/ -f1) pour vérifier.${NC}\n"

# linux-fresh-install

Scripts de configuration initiale pour une nouvelle machine Linux.

## setup-linux.sh

Configure un environnement shell complet en une commande.

### Utilisation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/matlantin/linux-fresh-install/main/setup-linux.sh)
```

Le script est **idempotent** — il peut être relancé sans risque sur une machine déjà configurée.

### Menu interactif

Le script pose les questions suivantes au démarrage :

```
? Configurer le réseau (hostname, IP, VLAN...) ? [o/N]
? Désactiver le Wi-Fi ? (machine headless/serveur) [o/N]
? Installer AdGuard Home ? [o/N]
```

#### Configuration réseau (optionnelle)

Si activée, le script demande :

```
? Nouveau hostname [hostname-actuel]
? Interface principale (connection NetworkManager) [netplan-eth0]
? Renommer cette connexion (laisser vide pour garder 'netplan-eth0')
? Adresse IP (ex: 192.168.1.10/24)
? Gateway
? DNS primaire [1.1.1.1]
? DNS secondaire (laisser vide si aucun)
? Créer une interface VLAN ? [o/N]
  → ID du VLAN (ex: 1020)
  → Adresse IP du VLAN (ex: 10.10.20.1/24)
  → Gateway VLAN (optionnel)
```

Les valeurs actuelles sont proposées comme défaut entre crochets.

### Ce qui est installé

| Outil | Description |
|---|---|
| `zsh` | Shell de remplacement |
| `oh-my-zsh` | Framework de configuration zsh |
| `zsh-autosuggestions` | Suggestions de commandes basées sur l'historique |
| `zsh-syntax-highlighting` | Coloration syntaxique dans le shell |
| `z` | Navigation rapide dans les répertoires (inclus dans oh-my-zsh) |
| `bat` | `cat` avec coloration syntaxique |
| `gdu` | Analyseur d'espace disque interactif |
| `bpytop` | Moniteur de ressources (CPU, RAM, réseau, disque) |
| `mc` | Midnight Commander — gestionnaire de fichiers en mode texte |
| `dnsutils` | `dig`, `nslookup` — outils de debug DNS |
| `tcpdump` | Capture et analyse de trafic réseau |
| `nmap` | Scan réseau |
| `iftop` | Monitoring du trafic réseau en temps réel |
| `ufw` | Firewall simple |
| `unattended-upgrades` | Mises à jour de sécurité automatiques |

### Configuration appliquée

- Thème oh-my-zsh : **agnoster** (nécessite une police Powerline dans le terminal)
- Plugins actifs : `git z zsh-autosuggestions zsh-syntax-highlighting`
- Titre d'onglet terminal : `hostname` au repos, `hostname - commande` pendant l'exécution
- Symlink `cat → batcat` (Debian/Raspberry Pi OS)
- zsh défini comme shell par défaut
- Fix locale UTF-8 + intégration aliases sur **DietPi**

### Distributions testées

- Debian Bookworm (12)
- Debian Trixie (13)
- DietPi (Bookworm)
- Raspberry Pi OS (Bookworm)

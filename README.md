# linux-fresh-install

Scripts de configuration initiale pour une nouvelle machine Linux.

## setup-linux.sh

Configure un environnement shell complet en une commande.

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
- Symlink `cat → batcat` (Debian/Raspberry Pi OS)
- zsh défini comme shell par défaut
- Fix locale UTF-8 + intégration aliases sur **DietPi**

### Utilisation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/matlantin/linux-fresh-install/main/setup-linux.sh)
```

Le script est **idempotent** — il peut être relancé sans risque sur une machine déjà configurée.

### Distributions testées

- Debian Bookworm (12)
- Debian Trixie (13)
- DietPi (Bookworm)
- Raspberry Pi OS (Trixie)

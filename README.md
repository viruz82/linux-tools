# Linux tools
## bcp
Create file backups like filename.YYY-MM-DD_HH:MM.bak<br>
usage: bcp file<br>
path: /usr/local/bin/bcp<br>
chmod +x bcp && cp bcp /usr/local/bin/

## bash_aliases
alias dir='ls -lh --color=auto'<br>
alias ll='ls -lh --color=auto'<br>
alias la='ls -lha --color=auto'<br>
alias l='ls -ahlF --color=auto'<br>
alias ls='ls -h --color=auto'<br>
alias ls-l='ls -lh --color=auto'<br>
alias das='dig +short a'<br>
alias dmx='dig +short mx'<br>
alias dix='dig +short -x'<br>
alias o='less'<br>
alias ..='cd ..'<br>
alias ...='cd ../..'<br>
alias cd..='cd ..'<br>
alias rd='rmdir'<br>
alias md='mkdir -p'<br>
alias vi='vi -c ":sy on"'<br>
alias vi='vim -c ":sy on"'

path: user's home (/root/.bash_aliases)<br>
cp bash_aliases /root/.bash_aliases

## 99-sysinfo
path: /etc/update-motd.d/<br>
chmod +x 99-sysinfo && cp 99-sysinfo /etc/update-motd.d/

## bashrc
file: /etc/bash.bashrc <br>
append: force_color_prompt=yes<br>
echo force_color_prompt=yes >> /etc/bash.bashrc

## Cronicle Worker Manager (interaktiv)

Ein Bash‑Skript zum **minimalen Setup** oder **vollständigen Entfernen** eines Cronicle‑Workers.  
Es arbeitet interaktiv: Alle Parameter werden beim Start abgefragt, Standardwerte können mit `Enter` übernommen werden.

### Features
- **Installation**
  - Fragt Master‑IP, Secret‑Key, Worker‑Name, SMTP‑Host & Port ab  
  - Installiert Node.js 22.19.0 lokal (keine Systeminstallation nötig)  
  - Klont Cronicle, kopiert `sample_conf` → `conf` und erstellt `config.json`  
  - Passt Config automatisch an (Rolle, Hostname, Master‑URL, SMTP‑Daten)  
  - Erstellt Symlink `/root/cronicle-worker` → `/opt/cronicle-worker`  
  - Richtet systemd‑Service ein, der beim Boot startet  
- **Uninstall**
  - Stoppt und deaktiviert den Service  
  - Entfernt alle Dateien und den Symlink rückstandslos  

### Voraussetzungen
- Linux mit `bash`, `curl`, `git`, `tar`  
- Root‑Rechte  
- Zugriff auf Cronicle‑Master (IP + Secret‑Key)  

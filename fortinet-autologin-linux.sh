#!/bin/bash
# Bozok Universitesi FortiGate captive portal otomatik giris betigi (Linux)
# (https://fortinet.bozok.edu.tr:1003)

# 1. Ortam degiskenlerinden veya config dosyasindan bilgileri al
CONF_FILE="/etc/fortinet-autologin/config.env"
if [ -f "$CONF_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
elif [ -f "$HOME/.config/fortinet-autologin/config.env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.config/fortinet-autologin/config.env"
fi

DEFAULT_USER=""
DEFAULT_PASS=""

FORTINET_USER="${FORTINET_USER:-$DEFAULT_USER}"
FORTINET_PASS="${FORTINET_PASS:-$DEFAULT_PASS}"

PROBE_URL="http://captive.apple.com/hotspot-detect.html"

# Log dosyasi belirleme
if [ -w "/var/log" ]; then
    LOG="/var/log/fortinet-autologin.log"
elif [ -n "$XDG_STATE_HOME" ] && [ -w "$XDG_STATE_HOME" ]; then
    LOG="$XDG_STATE_HOME/fortinet-autologin.log"
else
    LOG="$HOME/.fortinet-autologin.log"
fi

DRY_RUN=0
[ "$1" = "--dry-run" ] && DRY_RUN=1

log() {
    echo "$(date '+%F %T') $*" | tee -a "$LOG"
}

CURL=(curl -k -s -m 10 --noproxy '*')

# 1. Baglanti testi (internet var mi?)
probe=$("${CURL[@]}" -D - "$PROBE_URL")
if [[ $probe == *"<TITLE>Success</TITLE>"* ]]; then
    [ $DRY_RUN -eq 1 ] && log "Internet baglantisi aktif, islem yapilmadi."
    exit 0
fi

[ -z "$probe" ] && { log "Ag yanit vermiyor (baglanti kopuk olabilir)."; exit 1; }

# 2. FortiGate auth URL tespit etme
auth_url=$(grep -oE "https?://[^\"' <>]*:1003/fgtauth\?[0-9A-Za-z]+" <<<"$probe" | head -1)
if [ -z "$auth_url" ]; then
    log "Cevrimdisi fakat fgtauth yonlendirmesi bulunamadi."
    head -c 500 <<<"$probe" >>"$LOG"
    echo >>"$LOG"
    exit 1
fi
log "Portal algilandi: $auth_url"

# 3. Formu ayrintilariyla oku
page=$("${CURL[@]}" "$auth_url")
field() { grep -oE "name=\"$1\"[^>]*value=\"[^\"]*\"" <<<"$page" | head -1 | sed -E 's/.*value="([^"]*)"/\1/'; }
magic=$(field magic)
redir=$(field 4Tredir)
base=$(grep -oE '^https?://[^/]+' <<<"$auth_url")
[ -z "$magic" ] && magic=$(grep -oE 'fgtauth\?[0-9A-Za-z]+' <<<"$auth_url" | cut -d'?' -f2)

args=(--data-urlencode "4Tredir=${redir:-$PROBE_URL}" --data-urlencode "magic=$magic")

if grep -q 'name="username"' <<<"$page"; then
    if [ -z "$FORTINET_USER" ] || [ -z "$FORTINET_PASS" ]; then
        log "HATA: Portal kullanici adi ve sifre istiyor fakat bilgiler tanimli degil!"
        exit 1
    fi
    args+=(--data-urlencode "username=$FORTINET_USER" --data-urlencode "password=$FORTINET_PASS")
    kind="kimlik bilgileri ile giris"
else
    args+=(--data-urlencode "answer=1")
    kind="disclaimer (sozlesme) onayi"
fi

if [ $DRY_RUN -eq 1 ]; then
    log "Dry-run: $base/ adresine POST ($kind) gonderilecek (magic=$magic)."
    exit 0
fi

# 4. Gonder ve teyit et
"${CURL[@]}" -o /dev/null "${args[@]}" "$base/"
sleep 2

if [[ $("${CURL[@]}" "$PROBE_URL") == *Success* ]]; then
    log "Giris basarili ($kind)."
else
    log "Giris denemesi ($kind) basarisiz oldu."
    exit 1
fi

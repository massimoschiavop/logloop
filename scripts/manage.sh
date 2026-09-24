#!/bin/zsh
#
# Menu unico per avviare e rilasciare LogLoop: basta premere il numero, senza Invio.
# Dopo ogni azione si torna al menu; si esce con 0 (o Ctrl+D).
# Ctrl+C interrompe l'azione in corso e riporta al menu.
#
# Uso:
#   ./scripts/manage.sh
#
# build_ipa.sh e update_source.py restano separati perché li usa la GitHub Action.

cd "$(dirname "$0")/.."

REPO="massimoschiavop/logloop"
# Letto da project.yml, l'unico posto in cui è definito.
BUNDLE_ID=$(sed -n 's/^ *PRODUCT_BUNDLE_IDENTIFIER: *\([^ #]*\).*/\1/p' project.yml)
DERIVED_DATA="build/DerivedData"
LOG_FILE="build/logloop-menu.log"
UUID_PATTERN='[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}'

# MARK: - Stile

step()    { print -P "   %F{cyan}›%f $1" }
success() { print -P "   %F{green}✔%f $1" }
failure() { print -P -u2 "   %F{red}✘%f $1" }
note()    { print -P "     %F{242}$1%f" }

# Esegue un comando mostrando una rotellina; in caso di errore mostra le righe utili del log.
with_spinner() {
  local message=$1; shift
  mkdir -p build
  "$@" >"$LOG_FILE" 2>&1 &
  local pid=$! frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=1 start=$SECONDS
  trap "kill $pid 2>/dev/null; print; exit 130" INT
  while kill -0 $pid 2>/dev/null; do
    print -Pn "\r   %F{cyan}${frames[i]}%f $message %F{242}$(( SECONDS - start ))s%f "
    i=$(( i % ${#frames} + 1 ))
    sleep 0.1
  done
  wait $pid
  local code=$?
  trap - INT
  print -n "\r\e[K"
  if (( code == 0 )); then
    success "$message %F{242}$(( SECONDS - start ))s%f"
  else
    failure "$message"
    { grep -E "error:|Error" "$LOG_FILE" || tail -20 "$LOG_FILE" } | head -20 | sed 's/^/     /'
    note "Log completo: $LOG_FILE"
  fi
  return $code
}

# XcodeGen solo se i file del progetto sono cambiati, così i file Swift nuovi entrano
# sempre nella build; lo schema riscritto da XcodeGen viene ripristinato.
regenerate_project() {
  command -v xcodegen >/dev/null || return 0
  with_spinner "Aggiorno il progetto Xcode" xcodegen generate --use-cache
  git checkout -q -- LogLoop.xcodeproj/xcshareddata/xcschemes/LogLoop.xcscheme 2>/dev/null || true
}

# MARK: - Simulatore e telefono

# Il simulatore avviato; se nessuno è avviato avvia il primo iPhone disponibile.
booted_simulator() {
  local udid line
  udid=$(xcrun simctl list devices | grep "(Booted)" | grep -oE "$UUID_PATTERN" | head -1)
  if [[ -z "$udid" ]]; then
    line=$(xcrun simctl list devices available | grep -i "iphone" | head -1)
    udid=$(print -r -- "$line" | grep -oE "$UUID_PATTERN")
    [[ -z "$udid" ]] && { failure "Nessun simulatore iPhone disponibile." ; return 1 }
    xcrun simctl boot "$udid"
  fi
  # Mostra la finestra se l'app Simulator è installata; il simulatore gira comunque.
  # Su stderr: l'output di questa funzione è l'UDID.
  open -a Simulator 2>/dev/null \
    || print -P -u2 "     %F{242}App Simulator non trovata: il simulatore gira senza finestra.%f"
  print -r -- "$udid"
}

simulator_name() {
  xcrun simctl list devices | grep "$1" | sed -E 's/^ *(.*) \(.*\) \(.*/\1/'
}

run_on_simulator() {
  regenerate_project
  local udid
  udid=$(booted_simulator)
  step "Simulatore: %B$(simulator_name "$udid")%b"
  with_spinner "Compilo LogLoop" \
    xcodebuild -project LogLoop.xcodeproj -scheme LogLoop -configuration Debug \
      -destination "id=$udid" -derivedDataPath "$DERIVED_DATA" build
  with_spinner "Installo l'app" \
    xcrun simctl install "$udid" "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LogLoop.app"
  with_spinner "Avvio l'app" xcrun simctl launch "$udid" "$BUNDLE_ID"
}

run_on_phone() {
  regenerate_project
  local udid
  udid=$(xcrun xctrace list devices 2>&1 \
    | sed -n '/== Devices ==/,/== Simulators ==/p' \
    | grep -i "iphone" \
    | grep -oE '\([A-F0-9-]+\)$' \
    | tr -d '()' \
    | head -1)
  [[ -z "$udid" ]] && { failure "Nessun iPhone collegato."; return 1 }
  step "Telefono: %B$udid%b"
  with_spinner "Compilo LogLoop" \
    xcodebuild -project LogLoop.xcodeproj -scheme LogLoop -configuration Debug \
      -destination "id=$udid" -allowProvisioningUpdates \
      -derivedDataPath "$DERIVED_DATA" build
  with_spinner "Installo l'app" \
    xcrun devicectl device install app --device "$udid" "$DERIVED_DATA/Build/Products/Debug-iphoneos/LogLoop.app"
  with_spinner "Avvio l'app" xcrun devicectl device process launch --device "$udid" "$BUNDLE_ID"
}

# MARK: - Rilascio

last_version() {
  local tag
  tag=$(git tag --list 'v*' --sort=-v:refname | head -1)
  print -r -- "${tag#v}"
}

# Stato dell'ultima esecuzione avviata dal tag: "status conclusion", oppure vuoto se non ancora partita.
run_state() {
  curl -s "https://api.github.com/repos/$REPO/actions/runs?event=push&branch=v$1&per_page=1" \
    | python3 -c "import sys,json; r=json.load(sys.stdin).get('workflow_runs',[]); print(r[0]['status'], r[0]['conclusion']) if r else print('')"
}

# Chiede la versione, fa push di main e del tag, attende la GitHub Action che pubblica l'IPA
# e aggiorna apps.json.
release() {
  if [[ "$(git branch --show-current)" != "main" ]]; then
    failure "Devi essere su main."
    return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    step "Ci sono modifiche non committate:"
    git status --short | sed 's/^/     /'
    print
    local message
    read "message?   Messaggio di commit (vuoto per annullare): "
    [[ -z "$message" ]] && { note "Annullato."; return 1 }
    git add -A
    git commit -q -m "$message"
    success "Commit creato"
  fi

  with_spinner "Aggiorno main" git pull -q --rebase origin main

  local last suggested version confirm
  last=$(last_version)
  if [[ -n "$last" ]]; then
    local parts=("${(@s:.:)last}")
    suggested="${parts[1]}.$(( ${parts[2]:-0} + 1 ))"
    step "Ultima versione: %B$last%b"
  else
    suggested="1.0"
  fi

  read "version?   Nuova versione [$suggested]: "
  version="${version:-$suggested}"
  version="${version#v}"

  if [[ ! "$version" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
    failure "Versione non valida: usa il formato 1.2 o 1.2.3."
    return 1
  fi
  if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
    failure "La versione $version esiste già."
    return 1
  fi
  if [[ -n "$last" && "$(printf '%s\n%s\n' "$last" "$version" | sort -V | tail -1)" != "$version" ]]; then
    failure "La versione deve essere maggiore di $last."
    return 1
  fi

  read "confirm?   Rilascio LogLoop $version. Procedo? [s/N] "
  [[ "$confirm" == [sS] ]] || { note "Annullato."; return 1 }

  with_spinner "Invio main e il tag v$version" \
    zsh -c "git push -q origin main && git tag v$version && git push -q origin v$version"
  note "Ctrl+C per smettere di attendere: la GitHub Action prosegue comunque."
  with_spinner "Attendo la GitHub Action" wait_for_action "$version"
  with_spinner "Scarico apps.json aggiornato" git pull -q --rebase origin main
  print
  success "%BLogLoop $version pubblicata%b"
  note "Release: https://github.com/$REPO/releases/tag/v$version"
  note "In KravaSign aggiorna la fonte (apps.json può impiegare ~5 minuti ad aggiornarsi)."
}

wait_for_action() {
  for _ in {1..60}; do
    sleep 15
    case "$(run_state "$1")" in
      "completed success") return 0 ;;
      completed*) print "La GitHub Action è fallita: https://github.com/$REPO/actions"; return 1 ;;
    esac
  done
  print "Non ha finito in 15 minuti: controlla https://github.com/$REPO/actions"
  return 1
}

# MARK: - Menu

show_header() {
  local version branch changes simulator state
  version=$(last_version)
  branch=$(git branch --show-current)
  changes=$(git status --porcelain | wc -l | tr -d ' ')
  simulator=$(xcrun simctl list devices 2>/dev/null | grep "(Booted)" | head -1 | sed -E 's/^ *(.*) \(.*\) \(.*/\1/')
  [[ -z "$simulator" ]] && simulator="%F{242}spento%f"

  if (( changes == 0 )); then
    state="%F{green}●%f pulito"
  else
    state="%F{yellow}●%f $changes modifiche"
  fi

  print
  print -P "   %F{magenta}╭─────────────────────────────────────────╮%f"
  print -P "   %F{magenta}│%f   %B%F{white}∞  L O G L O O P%f%b                      %F{magenta}│%f"
  print -P "   %F{magenta}│%f   %F{242}${(r:38:)BUNDLE_ID}%f%F{magenta}│%f"
  print -P "   %F{magenta}╰─────────────────────────────────────────╯%f"
  print -P "   %F{242}versione%f %B${version:-—}%b   %F{242}branch%f %B$branch%b   $state"
  print -P "   %F{242}simulatore%f $simulator"
  print
}

menu_item() {
  print -P "   %K{$1}%F{black}%B $2 %b%f%k  $3  $4"
}

show_menu() {
  clear
  show_header
  menu_item cyan 1 "📱" "Compila e avvia sul simulatore"
  menu_item blue 2 "📲" "Compila e avvia sul telefono"
  menu_item magenta 3 "🚀" "Rilascia una nuova versione"
  print
  menu_item 242 0 "👋" "Esci"
  print
}

# Esegue l'azione in una subshell: un errore o Ctrl+C la interrompono senza chiudere il menu.
run_action() {
  clear
  print
  print -P "   %B$1%b"
  print -P "   %F{242}─────────────────────────────────────────%f"
  shift
  (
    trap - INT
    setopt errexit pipefail
    "$@"
  )
  local code=$?
  print
  if (( code == 0 )); then
    print -P "   %K{green}%F{black}%B FATTO %b%f%k"
  else
    print -P "   %K{red}%F{black}%B INTERROTTO %b%f%k"
  fi
  print
  read -s -k 1 "?   Premi un tasto per tornare al menu…" || true
}

# Ctrl+C al prompt del menu non chiude lo script.
trap 'print' INT

while true; do
  show_menu
  # Un solo tasto, senza Invio; Ctrl+C interrompe la lettura e ridisegna il menu.
  read -k 1 "choice?   Scelta : " || continue
  case "$choice" in
    1) run_action "📱  Simulatore" run_on_simulator ;;
    2) run_action "📲  Telefono" run_on_phone ;;
    3) run_action "🚀  Rilascio" release ;;
    0|q|$'\x04') break ;;
  esac
done

# Uscendo si lascia il terminale pulito.
clear

#!/bin/zsh
#
# Rilascia una nuova versione di LogLoop per KravaSign: chiede la versione, fa push di main
# e del tag, attende la GitHub Action che pubblica l'IPA e aggiorna apps.json.
#
# Uso:
#   ./scripts/release.sh

set -euo pipefail

cd "$(dirname "$0")/.."

REPO="massimoschiavop/logloop"

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Devi essere su main." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Ci sono modifiche non committate:"
  git status --short
  read "MESSAGE?Messaggio di commit (vuoto per annullare): "
  [[ -z "$MESSAGE" ]] && { echo "Annullato."; exit 1; }
  git add -A
  git commit -q -m "$MESSAGE"
fi

git pull -q --rebase origin main

LAST=$(git tag --list 'v*' --sort=-v:refname | head -1)
LAST="${LAST#v}"
if [[ -n "$LAST" ]]; then
  PARTS=("${(@s:.:)LAST}")
  SUGGESTED="${PARTS[1]}.$(( ${PARTS[2]:-0} + 1 ))"
  echo "Ultima versione: $LAST"
else
  SUGGESTED="1.0"
fi

read "VERSION?Nuova versione [$SUGGESTED]: "
VERSION="${VERSION:-$SUGGESTED}"
VERSION="${VERSION#v}"

if [[ ! "$VERSION" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
  echo "Versione non valida: usa il formato 1.2 o 1.2.3." >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
  echo "La versione $VERSION esiste già." >&2
  exit 1
fi
if [[ -n "$LAST" && "$(printf '%s\n%s\n' "$LAST" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]]; then
  echo "La versione deve essere maggiore di $LAST." >&2
  exit 1
fi

read "CONFIRM?Rilascio LogLoop $VERSION. Procedo? [s/N] "
[[ "$CONFIRM" == [sS] ]] || { echo "Annullato."; exit 1; }

git push -q origin main
git tag "v$VERSION"
git push -q origin "v$VERSION"
echo "Tag v$VERSION inviato. Attendo la GitHub Action (qualche minuto)..."

# Stato dell'ultima esecuzione avviata dal tag: "status conclusion", oppure vuoto se non ancora partita.
run_state() {
  curl -s "https://api.github.com/repos/$REPO/actions/runs?event=push&branch=v$VERSION&per_page=1" \
    | python3 -c "import sys,json; r=json.load(sys.stdin).get('workflow_runs',[]); print(r[0]['status'], r[0]['conclusion']) if r else print('')"
}

for _ in {1..60}; do
  sleep 15
  STATE=$(run_state)
  case "$STATE" in
    "completed success")
      git pull -q --rebase origin main
      echo "Fatto: LogLoop $VERSION pubblicata."
      echo "Release: https://github.com/$REPO/releases/tag/v$VERSION"
      echo "In KravaSign aggiorna la fonte (apps.json può impiegare ~5 minuti ad aggiornarsi)."
      exit 0
      ;;
    completed*)
      echo "La GitHub Action è fallita: https://github.com/$REPO/actions" >&2
      exit 1
      ;;
  esac
done

echo "La GitHub Action non ha finito in 15 minuti: controlla https://github.com/$REPO/actions" >&2
exit 1

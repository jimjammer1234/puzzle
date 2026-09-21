#!/usr/bin/env bash
cd "$(dirname "$0")"
HERE="$(pwd)"

: "${BIN:=$HERE/vanitysearch}"
: "${PUZZLE:=72}"
: "${ADDR:=1JTK7s9YVYywfm5XUH7RNhHJH1LshCaRFR}"
: "${BITS:=44}"
: "${TW:=100}"
: "${GPU:=0}"
: "${HB:=2}"
: "${TG_TOKEN:=}"
: "${TG_CHAT:=}"

if [ -z "${WI:-}" ]; then
  echo "ERROR: set WI to this worker's unique number, e.g.  WI=51 ./scan.sh"
  exit 1
fi

D="$HERE/state/w$WI"
mkdir -p "$D"

tg() {
  [ -z "$TG_TOKEN" ] && return 0
  local n=0
  while :; do
    curl -sf -m 30 -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
      --data-urlencode "chat_id=$TG_CHAT" --data-urlencode "text=$1" >/dev/null && return 0
    n=$((n+1)); [ "${2:-0}" != 1 ] && [ $n -ge 3 ] && return 1
    sleep 10
  done
}

I=0; [ -f "$D/state" ] && I=$(cat "$D/state")
echo "worker $WI, puzzle $PUZZLE, resuming at chunk iteration $I"
tg "Puzzle $PUZZLE worker $WI started on $(hostname), resuming at $I"

while :; do
  read -r CI S CNT < <(python3 -c "
p=$PUZZLE;b=$BITS;w=$WI;t=$TW;i=$I
st=1<<(p-1);sz=1<<b;n=((1<<p)-st)//sz
c=(w+i*t)%n
print(c,format(st+c*sz,'X'),format(sz-1,'X'))")
  rm -f "$D/found"
  echo "$(date -Is) chunk $CI $S:+$CNT" >> "$D/log"
  "$BIN" -gpu -gpuId "$GPU" -t 0 -stop -o "$D/found" --keyspace "$S:+$CNT" "$ADDR" >> "$D/log" 2>&1
  if [ -s "$D/found" ]; then
    M="KEY FOUND puzzle $PUZZLE worker $WI chunk $CI
$(cat "$D/found")"
    echo "$M" | tee "$HERE/FOUND_PUZZLE$PUZZLE.txt"
    tg "$M" 1
    exit 0
  fi
  I=$((I+1)); echo "$I" > "$D/state"
  [ "$HB" -gt 0 ] && [ $((I % HB)) -eq 0 ] && tg "Puzzle $PUZZLE worker $WI alive on $(hostname): $I chunks done"
done

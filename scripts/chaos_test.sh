#!/usr/bin/env sh
# Chaos test: kill each backing service in turn and confirm the API degrades
# gracefully instead of crashing, then recovers when the service returns.
#
# Pass condition for each phase:
#   - /health stays 200 (liveness must not depend on backing services)
#   - /ready reports 503 with the failed dependency = false (honest readiness)
#   - no crash; after restart /ready returns to 200
#
# Usage (docker stack up):  ./scripts/chaos_test.sh
set -eu

BACKEND="smartride_backend"
PASS=0
FAIL=0

probe() {
  # Prints: "<health_code> <ready_code> <db> <redis>"
  docker exec "$BACKEND" python -c "
import httpx, json
try:
    h = httpx.get('http://localhost:8000/health', timeout=5).status_code
except Exception:
    h = 0
try:
    r = httpx.get('http://localhost:8000/ready', timeout=8)
    body = r.json()
    print(h, r.status_code, body.get('db'), body.get('redis'))
except Exception as e:
    print(h, 0, 'err', 'err')
" 2>/dev/null
}

check() {
  desc="$1"; want="$2"; got="$3"
  if [ "$got" = "$want" ]; then
    echo "  PASS — $desc (got: $got)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL — $desc (want: $want, got: $got)"
    FAIL=$((FAIL + 1))
  fi
}

wait_ready() {
  # Poll until /ready is 200 again (service recovered), up to ~40s.
  i=0
  while [ "$i" -lt 20 ]; do
    set -- $(probe)
    [ "${2:-}" = "200" ] && return 0
    i=$((i + 1)); sleep 2
  done
  return 1
}

echo "=== Baseline ==="
set -- $(probe)
echo "  health=$1 ready=$2 db=$3 redis=$4"
check "healthy at rest" "200 200 True True" "$1 $2 $3 $4"

echo "=== Chaos 1: Redis down ==="
docker stop smartride_redis >/dev/null
sleep 3
set -- $(probe)
echo "  health=$1 ready=$2 db=$3 redis=$4"
check "health still 200 with Redis down" "200" "$1"
check "ready=503 and redis=False" "503 False" "$2 $4"

echo "=== Recovery 1: Redis back ==="
docker start smartride_redis >/dev/null
if wait_ready; then echo "  recovered"; check "ready back to 200" "200" "$(probe | cut -d' ' -f2)"; else echo "  FAIL — did not recover"; FAIL=$((FAIL + 1)); fi

echo "=== Chaos 2: Postgres down ==="
docker stop smartride_postgres >/dev/null
sleep 3
set -- $(probe)
echo "  health=$1 ready=$2 db=$3 redis=$4"
check "health still 200 with Postgres down" "200" "$1"
check "ready=503 and db=False" "503 False" "$2 $3"

echo "=== Recovery 2: Postgres back ==="
docker start smartride_postgres >/dev/null
if wait_ready; then echo "  recovered"; check "ready back to 200" "200" "$(probe | cut -d' ' -f2)"; else echo "  FAIL — did not recover"; FAIL=$((FAIL + 1)); fi

echo ""
echo "=== RESULT: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1

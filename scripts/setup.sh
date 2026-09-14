#!/usr/bin/env bash
# Creates the parameter lists a fresh Yamcs instance doesn't have. Yamcs keeps
# them in its own database, so `mvn clean` or a new checkout starts without them.
#
# Safe to run again: an existing list with the same name is left alone.

set -euo pipefail

YAMCS="${YAMCS:-http://localhost:8090}"
INSTANCE="${INSTANCE:-kfsw}"

curl -sf "$YAMCS/api/mdb/$INSTANCE" >/dev/null || {
	echo "no Yamcs at $YAMCS; start it with ./mvnw yamcs:run" >&2
	exit 1
}

have_list()
{
	curl -sf "$YAMCS/api/parameter-lists/$INSTANCE/lists" |
		python3 -c "
import sys, json
name = sys.argv[1]
lists = json.load(sys.stdin).get('lists', [])
sys.exit(0 if any(entry['name'] == name for entry in lists) else 1)
" "$1"
}

make_list()
{
	local name="$1" description="$2" patterns="$3"

	if have_list "$name"; then
		printf '  [skip] %s already exists\n' "$name"
		return
	fi
	curl -sf -X POST "$YAMCS/api/parameter-lists/$INSTANCE/lists" \
		-H 'Content-Type: application/json' \
		-d "{\"name\":\"$name\",\"description\":\"$description\",\"patterns\":$patterns}" \
		>/dev/null
	printf '  [ok]   %s\n' "$name"
}

echo "SETUP: parameter lists"

# The values the node collects, in one list.
make_list "Housekeeping" \
	"The nucleo_temperature report, as the node collects it" \
	'["/kfsw/nucleo_temperature_*"]'

# The header fields of every sample. hk_flags and hk_seconds show whether a
# value is missing, and hk_sequence shows lost samples.
make_list "Housekeeping frame" \
	"Sequence, timestamp and flags from each sample's header" \
	'["/kfsw/hk_*", "/kfsw/gs_*"]'

echo "SETUP RESULT: PASS"

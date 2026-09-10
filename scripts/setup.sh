#!/usr/bin/env bash
# Create the things a fresh instance does not come with.
#
# Yamcs keeps parameter lists in its own database, so a `mvn clean` or a new
# checkout starts without them. Making them here rather than by hand in the web
# interface means everyone gets the same ones, and that what an operator opens
# is described in the repository rather than in somebody's local database.
#
# Safe to run repeatedly: an existing list of the same name is left alone.

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

# What the node actually collects, so opening Yamcs shows the report together
# rather than leaving an operator to find five parameters among the system ones.
make_list "Housekeeping" \
	"The nucleo_temperature report, as the node collects it" \
	'["/kfsw/nucleo_temperature_*"]'

# The header of every sample. Worth its own list: hk_flags and hk_seconds are
# how you tell a value that is missing from one that is genuinely zero, and
# hk_sequence is how you see that a sample was lost rather than never taken.
make_list "Housekeeping frame" \
	"Sequence, timestamp and flags from each sample's header" \
	'["/kfsw/hk_*", "/kfsw/gs_*"]'

echo "SETUP RESULT: PASS"

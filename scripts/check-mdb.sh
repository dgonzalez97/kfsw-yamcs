#!/usr/bin/env bash
# Checks that the mission database decodes a housekeeping frame recorded from a
# node.
#
# Expects Yamcs to be running and answering on $YAMCS.

set -euo pipefail

YAMCS="${YAMCS:-http://localhost:8090}"
INSTANCE="${INSTANCE:-kfsw}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="$HERE/../test/hk-sample.hex"
failures=0

check()
{
	if [[ "$2" == "$3" ]]; then
		printf '  [ok]   %s\n' "$1"
	else
		printf '  [FAIL] %s\n         wanted %s\n         got    %s\n' "$1" "$3" "$2" >&2
		failures=$((failures + 1))
	fi
}

present()
{
	if curl -sf "$YAMCS/api/mdb/$INSTANCE/$1" >/dev/null; then
		printf '  [ok]   %s\n' "$1"
	else
		printf '  [FAIL] the database has no %s\n' "$1" >&2
		failures=$((failures + 1))
	fi
}

echo "MDB CHECK"
present "containers/kfsw/hk_frame"
present "containers/kfsw/nucleo_temperature"
present "parameters/kfsw/hk_sequence"
present "parameters/kfsw/nucleo_temperature_temp_mcu"

# A frame recorded from a hosted node. There is no sensor, so the temperature is
# the reserved value and temp_valid is 0; the uptime and free buffers are real.
python3 - "$SAMPLE" <<'PY'
import socket, struct, sys, time
frame = bytes.fromhex(open(sys.argv[1]).read().strip())
sequence = struct.unpack_from(">H", frame, 2)[0]
datagram = struct.pack(">QI", int(time.time() * 1000), sequence) + frame
socket.socket(socket.AF_INET, socket.SOCK_DGRAM).sendto(datagram, ("127.0.0.1", 10015))
PY
sleep 3

value()
{
	curl -sf "$YAMCS/api/processors/$INSTANCE/realtime/parameters/kfsw/$1" |
		python3 -c "
import sys, json
raw = json.load(sys.stdin).get('rawValue') or {}
print(next((v for k, v in raw.items() if k != 'type'), 'NO VALUE'))
"
}

check "uptime came through" "$(value nucleo_temperature_uptime_s)" "3"
check "the free-buffer count came through" "$(value nucleo_temperature_csp_buf_free)" "32"
check "the report id decoded" "$(value hk_report)" "0"
check "the sequence decoded" "$(value hk_sequence)" "0"
check "the absent reading is the reserved value" \
	"$(value nucleo_temperature_temp_mcu)" "-2147483648"
check "and it is marked absent" "$(value nucleo_temperature_temp_valid)" "0"

if [[ "$failures" -eq 0 ]]; then
	echo "MDB CHECK RESULT: PASS"
else
	echo "MDB CHECK RESULT: FAIL ($failures)"
	exit 1
fi

# K-FSW Mission Control

The ground half of K-FSW housekeeping: a [Yamcs](https://yamcs.org/) instance
that keeps what comes down, so a pass can be read after it ends.

Forked from [yamcs/quickstart](https://github.com/yamcs/quickstart) and kept
deliberately small. The upstream simulator, its test data and its example Java
are gone; what is left is one telemetry link and one mission database.

## Why this exists

A K-FSW node collects a housekeeping report — a named set of parameter values,
sampled together and served in one packet — and answers when asked. Until this,
nothing on the ground kept the answer. A pass was read on a console and lost,
and the history the node's ring held collapsed the moment the terminal
scrolled.

The interesting part is not that Yamcs stores telemetry. It is that a
housekeeping frame carries **no names**: values back to back in the order the
report was defined, and nothing in the packet says what they are. That is the
right trade for a radio and it means the two ends have to agree out of band.
So the mission database here is generated, not written, from the same file in
[k-fsw](https://github.com/dgonzalez97/k-fsw) that tells the node what to
collect.

## Running it

    ./mvnw yamcs:run
    ./scripts/setup.sh

Then open <http://localhost:8090>.

`setup.sh` creates the parameter lists — **Housekeeping**, the five values the
node collects, and **Housekeeping frame**, the sequence, timestamp and flags
from each sample's header. Yamcs keeps those in its own database, so a fresh
checkout or a `mvn clean` starts without them; making them from a script means
what an operator opens is described here rather than in somebody's local
database. It is safe to run again. Nothing arrives on its own — housekeeping is
pull-only — so ask a node for samples with the bridge in k-fsw:

    tools/ground/hk-bridge.py --device /dev/pts/7 --node 1 --report 0

The bridge speaks CSP over KISS on the host, pulls samples, and forwards each
one to the UDP link on port 10015. It decodes nothing: frames go on byte for
byte, and what a value means lives in the database here.

## What is in the packets

Every datagram is a 12-byte envelope the bridge adds, then the frame the node
sent:

```
 0  u64  Unix milliseconds   the node's own clock, or the host's if it is unset
 8  u32  sequence
12  u8   protocol version
13  u8   report id           which container this is
14  u16  sequence            per report; a gap here is a lost sample
16  u32  UTC seconds         when collection started, 0 if the clock is unset
20  u8   entry count
21  u8   flags               bit 0: a value was absent and zero-filled
22  ...  values, big endian, widths fixed by the report definition
```

The envelope exists because Yamcs reads an 8-byte time and a 4-byte count at
fixed offsets and the frame carries 4 and 2. Without it a pull of sixteen
samples would all land at one reception instant, and the history would collapse
into a single moment in the archive.

## Regenerating the mission database

From a k-fsw checkout:

    tools/ground/hk-report.py ground-station/reports/nucleo-temperature.yaml \
        xtce -o ground-station/yamcs/src/main/yamcs/mdb/kfsw-hk.xml

The same file emits the `hk define` line the node is given, and `hk-report.py
check` compares it against a node's own `param list`. Do not edit
`mdb/kfsw-hk.xml` by hand.

## Tests

    ./scripts/check-mdb.sh

Pushes a housekeeping frame recorded off a real node into a running instance
and reads the values back out. Loading a database is not evidence that it
decodes anything; this is. It runs on every push.

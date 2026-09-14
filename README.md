# K-FSW Mission Control

The [Yamcs](https://yamcs.org/) instance for K-FSW housekeeping. It stores the
samples that come down so a pass can be looked at afterwards.

Forked from [yamcs/quickstart](https://github.com/yamcs/quickstart), without the
simulator, its test data and the example Java: one telemetry link and one
mission database.

## How it works

A K-FSW node collects a housekeeping report, a set of parameter values sampled
together and sent in one packet. The packet has no names, only the values in the
order the report defines, so the ground needs the same definition. The mission
database is generated from the report file in
[k-fsw](https://github.com/dgonzalez97/k-fsw) that also sets up the node.

## Running it

    ./mvnw yamcs:run
    ./scripts/setup.sh

Then open <http://localhost:8090>.

`setup.sh` creates two parameter lists: **Housekeeping**, the five values the
node collects, and **Housekeeping frame**, the sequence, timestamp and flags from
each sample's header. Yamcs keeps the lists in its own database, so a fresh
checkout or `mvn clean` starts without them. It is safe to run again.

Samples come from the bridge in k-fsw, which polls a node:

    tools/ground/hk-bridge.py --device /dev/pts/7 --node 1 --report 0

or records the beacons a node sends when started with `--listen`. The bridge
talks CSP over KISS and forwards each sample to the UDP link on port 10015
without decoding it; Yamcs decodes it with the database here.

## Packet layout

Every datagram is a 12-byte envelope added by the bridge, followed by the frame
from the node:

```
 0  u64  Unix milliseconds   the node's clock, or the host's if it is not set
 8  u32  sequence
12  u8   protocol version
13  u8   report id           which container this is
14  u16  sequence            per report; a gap is a lost sample
16  u32  UTC seconds         when collection started, 0 if the clock is not set
20  u8   entry count
21  u8   flags               bit 0: a value was missing and zero-filled
22  ...  values, big endian, widths set by the report definition
```

Yamcs reads an 8-byte time and a 4-byte count at fixed offsets, and the frame
has 4 and 2 bytes, so the bridge adds the envelope. Without it, samples pulled
together would all get the same time in the archive.

## Regenerating the mission database

From a k-fsw checkout:

    tools/ground/hk-report.py ground-station/reports/nucleo-temperature.yaml \
        xtce -o ground-station/yamcs/src/main/yamcs/mdb/kfsw-hk.xml

The same file gives the `hk define` line for the node, and `hk-report.py check`
compares it with a node's `param list`. Don't edit `mdb/kfsw-hk.xml` by hand.

## Where the bridge is

The bridge is in [k-fsw](https://github.com/dgonzalez97/k-fsw), not here.
`hk-bridge.py` implements the CSP and KISS framing, which is K-FSW's protocol,
and `tests/hk-yamcs-smoke.sh` in k-fsw checks it against a running node: the
bytes the bridge receives must match what the node's shell prints.

This repository has what Yamcs needs: the instance configuration, the generated
mission database, the parameter lists and the recorded frame used by the check.

## Tests

    ./scripts/check-mdb.sh

Sends a housekeeping frame recorded from a node to a running instance and reads
the values back. CI runs it on every push.

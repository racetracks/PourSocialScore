#!/bin/sh
# Clone the scratch repo with the SCRATCH_TOKEN secret into <dest> for a CI
# job that runs the service bus gate (service-bus-helper DEC-00203, STP-00144).
# A clone that fails deletes its folder and clones fresh, four tries with
# backoff (2, 4, 8 s). Exit 0 cloned, 1 failed, 2 no token (a fork: the gate
# then SKIPs, which is not a pass but cannot be helped there).
#   SCRATCH_TOKEN=... sh tools/ci_scratch.sh <dest>
dest=$1
[ -n "$dest" ] && [ "$dest" != "/" ] || { echo "usage: ci_scratch.sh <dest>"; exit 1; }
[ -n "$SCRATCH_TOKEN" ] || { echo "no SCRATCH_TOKEN"; exit 2; }
tries=0
wait=2
while [ "$tries" -lt 4 ]; do
	rm -rf "$dest"
	if git clone -q --depth 1 "https://x-access-token:${SCRATCH_TOKEN}@github.com/racetracks/Pour-Social-Score_Scratch" "$dest"; then
		exit 0
	fi
	tries=$((tries + 1))
	echo "scratch clone failed (try $tries of 4)"
	sleep "$wait"
	wait=$((wait * 2))
done
rm -rf "$dest"
exit 1

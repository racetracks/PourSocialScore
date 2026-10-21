#!/bin/sh
# validate_all.sh watchdog: validate_watchdog.sh PID WORK TIMEOUT
# Fails and stops the section (named in WORK/.section) that runs over TIMEOUT seconds:
# prints a FAIL line, lists the name in WORK/.timedout, TERMs every descendant of PID.
pid=$1; work=$2; limit=$3
last=""
kids() {
	for c in $(ps -o pid= --ppid "$1"); do
		[ "$c" = "$$" ] && continue
		kids "$c"
		echo "$c"
	done
}
while kill -0 "$pid" 2>/dev/null; do
	sleep 5
	[ -f "$work/.section" ] || continue
	read -r start name < "$work/.section"
	[ -n "$start" ] || continue
	now=$(date +%s)
	if [ $((now - start)) -gt "$limit" ] && [ "$start $name" != "$last" ]; then
		echo "FAIL timeout: $name ran over ${limit}s (PSS_SECTION_TIMEOUT)"
		echo "$name" >> "$work/.timedout"
		last="$start $name"
		for k in $(kids "$pid"); do kill -TERM "$k" 2>/dev/null; done
	fi
done
exit 0

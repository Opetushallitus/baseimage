#!/usr/bin/env bash

dump_count=${1:-1}
dump_interval_seconds=${2:-10}

for n in $(seq -w 1 "${dump_count}"); do
  if [[ $(whoami) == "oph" ]]; then
    ${JAVA_HOME}/bin/jcmd "$(pidof java)" Thread.print
  else
    # Run the command as oph, the java process is also running as oph and this needs to be the same user
    su - oph bash -c "${JAVA_HOME}/bin/jcmd $(pidof java) Thread.print"
  fi
  if [[ "${n}" < "${dump_count}" ]]; then
    echo "Dump ${n}/${dump_count} done, sleeping ${dump_interval_seconds} seconds before the next one..."
    sleep "${dump_interval_seconds}"
  fi
done

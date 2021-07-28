#!/usr/bin/env bash

if [[ $(whoami) == "oph" ]]; then
  /opt/java/openjdk/bin/jcmd "$(pidof java)" Thread.print
else
  # Run the command as oph, the java process is also running as oph and this needs to be the same user
  su - oph bash -c "/opt/java/openjdk/bin/jcmd $(pidof java) Thread.print"
fi

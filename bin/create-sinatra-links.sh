#!/bin/bash
#
# Since git does not keep symlinks we need to generate them
#
PORTS="5000 5001 5002 5003"

if [ ! -f sinatra.template ] ; then 
  echo "Run this within unit_files dir"
  exit
fi

for port in ${PORTS} ; do
  ln -s  sinatra.template sinatra@${port}.service
done

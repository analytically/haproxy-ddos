#!/bin/bash
set -e

# In case of a crash, let's wait for a sec for the kernel to clean up
# the bound port. See https://github.com/bketelsen/captainhook/issues/9.
sleep 1

increment=${CAPTAINHOOK_PORT_INCREMENT:-1}
port=${CAPTAINHOOK_PORT:-666}
while nc -z localhost $port; do port=$[port+increment]; done

exec /usr/share/gocode/bin/captainhook -listen-addr 127.0.0.1:$port -configdir /etc/captainhook -echo
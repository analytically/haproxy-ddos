#!/bin/bash
set -e

cd /etc/haproxy-ddos/blacklists
curl -sSf -m 120 -o tor-exit-nodes.txt https://www.dan.me.uk/torlist/
supervisorctl restart haproxy-ddos
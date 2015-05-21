#!/bin/bash
set -e

iptables -I INPUT -p tcp -m multiport --dports 80,443 --syn -j DROP

sleep 0.5
supervisorctl restart haproxy-ddos

iptables -D INPUT -p tcp -m multiport --dports 80,443 --syn -j DROP

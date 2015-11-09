#!/bin/bash
set -e

unix2dos /etc/haproxy-ddos/errors/403-html.http
unix2dos /etc/haproxy-ddos/errors/403-json.http

envtpl /etc/haproxy-ddos/haproxy.cfg.tpl --keep-template

exec haproxy -f /etc/haproxy-ddos/haproxy.cfg

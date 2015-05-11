# haproxy-ddos

DDOS resilient HAProxy configuration

## Building

```shell
docker build -t mycompany/haproxy-ddos
```

## Blocking

Implements two ways of blocking users: a simple deny via HTTP 200 response page and a tarpit. Tarpit stops the request without responding for a delay of
10 seconds. After that delay, if the client is still connected, an HTTP error 500 is returned so that the client does not suspect it has been tarpitted.
The goal of the tarpit is to slow down robots during an attack when they're limited on the number of concurrent requests. It can be very efficient against
very dumb robots, and will significantly reduce the load on servers compared to a "deny" rule. We also disconnect slow handshake clients early, to protect from
resources exhaustion attacks.

Tracks client IPs into a global stick table. Each IP is stored for a limited amount of time, with several counters attached to it. When a new connection
comes in, the stick table is evaluated to verify that the new connection from this client is allowed to continue. The client IP is provided by CloudFlare
through the CF-Connecting-IP HTTP header.

### Deny block

- IP’s from the following countries (via http://ip.ludost.net/): af, ar, ci, cu, ee, eg, er, id, iq, ir, kp, kr, lb, lr, ly, mm, my, ro, rs, sd, so, sy, th, tr, ua, vn, ye, zw
- IP’s http://www.wizcrafts.net/exploited-servers-iptables-blocklist.html
- IP’s http://www.wizcrafts.net/nigerian-iptables-blocklist.html
- CyberGhost VPN, Hotspot Shield Elite VPN
- TOR nodes on https://www.dan.me.uk/torlist/ - we update this monthly
- DigitalOcean, ServerStack and AWS (VPS providers that can easily be used to setup VPN/TOR nodes)

### Tarpit block

- TARPIT the new connection if the client already has 10 opened
- TARPIT the new connection if the client has opened more than 20 connections in 3 seconds
- TARPIT the connection if the client has passed the HTTP error rate (10s)
- TARPIT the connection if the client has passed the HTTP request rate (10s)
- TARPIT content-length larger than 20kB (eg. POST requests)
- TARPIT requests with more than 10 Range headers (see http://httpd.apache.org/security/CVE-2011-3192.txt)
- TARPIT requests for .ida .asp .dll .exe .php .sh .pl .py .so chat phpbb sumthin horde _vti_bin MSOffice %00 <script xmlrpc.php
- TARPIT requests with illegal headers

## HAProxy Stats

Available on 9090, use `admin` as username and `FeYskS2qjP7qvED` as password.

# Issues

Don't run on Docker using OverlayFS.

#### License

Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Copyright 2014-2015 [Mathias Bogaert](mailto:mathias.bogaert@gmail.com).

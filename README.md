## haproxy-ddos

DDOS and attack resilient [HAProxy](http://www.haproxy.org/) configuration. To be used behind [CloudFlare](https://www.cloudflare.com/).
Use it to build [Docker](http://www.docker.com) load balancers. Follow [@analytically](http://twitter.com/analytically) for updates.

Part inspired from https://jve.linuxwall.info/ressources/taf/haproxy-aws/.

### Building

```sh
docker build -t mycompany/haproxy-ddos
```

### Running

Mozilla's recommended configuration ['Modern'](https://wiki.mozilla.org/Security/Server_Side_TLS#Modern_compatibility) is used. Mount the
directory containing your SSL certificates (pem) as `/etc/ssl/private/`:

```sh
docker run --cap-add=NET_ADMIN --restart=always -v /opt/mycompany/ssl:/etc/ssl/private \ -t -i mycompany/haproxy-ddos bash
```

This will give you an interactive bash prompt into the Docker container. To customize the backends, edit `haproxy.cfg.tpl`.

### Blocking

Uses two ways of blocking users: a simple deny via HTTP 200 response page and a tarpit. Tarpit stops the request without responding for a delay of
10 seconds. After that delay, if the client is still connected, an HTTP error 500 is returned so that the client does not suspect it has been tarpitted.

Tracks client IPs into a global stick table. Each IP is stored for a limited amount of time, with several counters attached to it. When a new connection
comes in, the stick table is evaluated to verify that the new connection from this client is allowed to continue.

The client IP is provided by CloudFlare through the `CF-Connecting-IP` HTTP header.

#### Deny block

HTTP `200` for app backend, `403` for API backend.

- IPs from the following countries (via http://ip.ludost.net/): af, ar, ci, cu, ee, eg, er, id, iq, ir, kp, kr, lb, lr, ly, mm, my, ro, rs, sd, so, sy, th, tr, ua, vn, ye, zw
- IPs http://www.wizcrafts.net/exploited-servers-iptables-blocklist.html
- IPs http://www.wizcrafts.net/nigerian-iptables-blocklist.html
- CyberGhost VPN, Hotspot Shield Elite VPN
- TOR nodes on https://www.dan.me.uk/torlist/
- DigitalOcean, ServerStack and AWS (VPS providers that can easily be used to setup VPN/TOR nodes)

#### Tarpit block

- TARPIT the new connection if the client already has 10 opened
- TARPIT the new connection if the client has opened more than 20 connections in 3 seconds
- TARPIT the connection if the client has passed the HTTP error rate (10s)
- TARPIT the connection if the client has passed the HTTP request rate (10s)
- TARPIT content-length larger than 20kB (eg. POST requests)
- TARPIT requests with more than 10 Range headers (see http://httpd.apache.org/security/CVE-2011-3192.txt)
- TARPIT requests for .ida .asp .dll .exe .php .sh .pl .py .so chat phpbb sumthin horde _vti_bin MSOffice %00 <script xmlrpc.php
- TARPIT requests with illegal headers

### HAProxy Stats

Available on [http://localhost:9090](http://localhost:9090), use `haproxy/haproxy` for read-only access, `admin/FeYskS2qjP7qvED` for admin access.

### Webhooks (via [CaptainHook](https://github.com/bketelsen/captainhook))

#### Updating the TOR node list

```sh
curl -X POST localhost:666/update-tor-exit-nodes
```

#### Restarting HAProxy

```sh
curl -X POST localhost:666/restart-haproxy
```

### Issues

Don't run on Docker using OverlayFS.

### Logstash

If you set the environment variable `LOGSTASH_SERVICE_HOST` to the [Logstash](http://logstash.net/) host, HAProxy will log against it (port 5140).
Use the following configuration to better deal with HAProxy's logging:

```
if [type] == "haproxy" {
    grok {
      match           => ["message", "%{IP:client_ip}:%{INT:client_port} \[%{HAPROXYDATE:accept_date}\] %{NOTSPACE:frontend_name} %{NOTSPACE:backend_name}/%{NOTSPACE:server_name} %{INT:time_request}/%{INT:time_queue}/%{INT:time_backend_connect}/%{INT:time_backend_response}/%{NOTSPACE:time_duration} %{INT:http_status_code} %{NOTSPACE:bytes_read} %{DATA:captured_request_cookie} %{DATA:captured_response_cookie} %{NOTSPACE:termination_state} %{INT:actconn}/%{INT:feconn}/%{INT:beconn}/%{INT:srvconn}/%{NOTSPACE:retries} %{INT:srv_queue}/%{INT:backend_queue} (\{%{DATA:request_header_host}\|%{DATA:request_header_x_forwarded_for}\|%{DATA:request_header_accept_language}\|%{DATA:request_header_referer}\|%{DATA:request_header_user_agent}\|%{DATA:request_cf_ip_country}\|%{DATA:request_cf_connecting_ip}\|%{DATA:request_cf_ray}\|%{DATA:request_content_length}\|%{DATA:request_haproxy_acl}\|%{DATA:request_haproxy_tarpit}\|%{DATA:request_bc_api_access_key}\})?( )?(\{%{HAPROXYCAPTUREDRESPONSEHEADERS}\})?( )?\"(<BADREQ>|(%{WORD:http_verb} (%{URIPROTO:http_proto}://)?(?:%{USER:http_user}(?::[^@]*)?@)?(?:%{URIHOST:http_host})?(?:%{URIPATHPARAM:http_request})?( HTTP/%{NUMBER:http_version})?))?"]
    }

    # Re-do the timestamp, because haproxy logs come with sub-second precision
    date {
      match           => ["accept_date", "d/MMM/YYYY:HH:mm:ss.SSS"]
      timezone        => "UTC"
      remove_field    => ["accept_date", "haproxy_monthday", "haproxy_month", "haproxy_time", "haproxy_year", "haproxy_month", "haproxy_hour", "haproxy_minute", "haproxy_second", "haproxy_milliseconds"]
      add_tag         => "haproxy"
    }

    geoip {
      source          => "request_cf_connecting_ip"
      target          => "geoip"
      add_field       => ["[geoip][coordinates]","%{[geoip][longitude]}"]
      add_field       => ["[geoip][coordinates]","%{[geoip][latitude]}"]
      add_tag         => [ "geoip" ]
    }

    # Clean up
    if [captured_request_cookie] == "-" { mutate { remove_field => "captured_request_cookie" } }
    if [captured_response_cookie] == "-" { mutate { remove_field => "captured_response_cookie" } }

    mutate {
      replace => ["type", "haproxy"]
      convert => [ "client_port", "integer" ]
      convert => [ "time_request", "integer" ]
      convert => [ "time_queue", "integer" ]
      convert => [ "time_backend_connect", "integer" ]
      convert => [ "time_backend_response", "integer" ]
      convert => [ "time_duration", "integer" ]
      convert => [ "http_status_code", "integer" ]
      convert => [ "bytes_read", "integer" ]
      convert => [ "actconn", "integer" ]
      convert => [ "feconn", "integer" ]
      convert => [ "beconn", "integer" ]
      convert => [ "srvconn", "integer" ]
      convert => [ "retries", "integer" ]
      convert => [ "srv_queue", "integer" ]
      convert => [ "backend_queue", "integer" ]
      convert => [ "[geoip][coordinates]", "float" ]
      uppercase => [ "http_verb" ]
    }
  }
```

### License

Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Copyright 2015 [Mathias Bogaert](mailto:mathias.bogaert@gmail.com).
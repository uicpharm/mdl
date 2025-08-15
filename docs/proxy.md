# Proxy FAQs

How do I...

## Redirect all requests from /moodle?

Since all existing links go to <http://server/moodle>, and by default the proxy will host
Moodle at just <http://server>, we should have redirection for those old links.

In your custom configuration for the proxy host, add this configuration:

```nginx
rewrite ^/moodle(.*)$ $scheme://$server_name$1 permanent;
```

## Restrict access on the staging server?

Restricting access makes sense to accomplish at the proxy level. You could accomplish this
by restricting to just internal network IP addresses.

**IP Address blocking** is the most straightforward way to block the staging server from
unwanted access. Just enter the [CIDR](https://cidr.xyz/) or specific IP Addresses to
allow, and then deny everything else.

In order to do IP-based blocking, you can't use container-based Nginx Proxy Manager.
Instead, use [Caddy](https://caddyserver.com) installed directly on the server. Caddy
needs access to the port for Moodle, which is automatically calculated as a number
counting up from 8000, (i.e. 8001, 8002...) but can also be explicitly set in the `.env`
file with the `MOODLE_PORT` variable, if needed.

A `Caddyfile` configuration similar to this may work for your staging server, so that
the environments are only accessible via internal network IPs (`10.0.0.0/8`):

```text
(logging) {
   log {
      output file /var/log/caddy/access.log
      format json
   }
}

(internal_only) {
   @denied not client_ip 10.0.0.0/8
   respond @denied "Site is only accessible within our network." 403
}

# Reverse proxy for mymoodle.sample.dev
mymoodle.sample.dev {
   import logging
   import internal_only
   tls myemail@sample.dev
   reverse_proxy {
      to http://localhost:8001
   }
}
```

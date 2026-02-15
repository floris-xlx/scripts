# docs.xbp.app returning 502 / not loading — Root Cause & Resolution

## Symptoms
- Local tests succeeded:
  - `curl http://127.0.0.1:4039` → 200 OK (Next.js healthy)
  - `curl -k https://127.0.0.1 -H "Host: docs.xbp.app"` → 200 OK (Nginx → upstream works)
- External access failed or intermittently hung
- Nginx error log showed:
  connect() failed (111: Connection refused) while connecting to upstream

## Observed Network State
DNS:


docs.xbp.app → A → 116.202.32.85
(no AAAA record)


Server addresses:


Public IPv4: 116.202.32.85
Public IPv6: 2a01:4f8:231:2986::2


Clients on modern networks attempt IPv6 first (Happy Eyeballs / RFC 8305 behavior).
Because the host had IPv6 connectivity but no AAAA record and Nginx was not explicitly bound to IPv6, connection attempts behaved inconsistently depending on resolver path and client stack.

This produced:
- browsers hanging
- random 502
- bots failing
- local tests working

## Root Cause
Partial IPv6 configuration.

The server was dual-stack capable but DNS exposed only IPv4.
Some client resolvers or upstream routing paths still attempted IPv6, while Nginx was effectively reachable only via IPv4. This created asymmetric reachability:



Client → IPv6 attempt → fails
Client → IPv4 fallback → sometimes works
Local curl → forced IPv4 → always works


The upstream refusal errors were secondary effects of unreachable listener paths rather than a Next.js failure.

## Resolution

### 1) Publish IPv6 in DNS
Add AAAA record:



docs.xbp.app AAAA 2a01:4f8:231:2986::2


Keep existing A record:


docs.xbp.app A 116.202.32.85


### 2) Bind Nginx to IPv6 explicitly

Update both HTTP and HTTPS server blocks:



server {
listen 80;
listen [::]:80;
server_name docs.xbp.app;
return 301 https://$host$request_uri;
}

server {
listen 443 ssl;
listen [::]:443 ssl;
server_name docs.xbp.app;

ssl_certificate /etc/letsencrypt/live/docs.xbp.app/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/docs.xbp.app/privkey.pem;

location / {
    proxy_pass http://127.0.0.1:4039;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}


}


Reload:


nginx -t && systemctl reload nginx


### 3) Verification

From server:


curl -g -6 -I https://docs.xbp.app

curl -g -4 -I https://docs.xbp.app


From external machine:


curl -I https://docs.xbp.app


Expected:


HTTP/1.1 200 OK


## Final State
- Dual stack DNS (A + AAAA)
- Nginx bound on IPv4 and IPv6
- Next.js upstream unchanged
- No further 502 errors
- Consistent connectivity across networks

## Key Takeaway
If a server has global IPv6 connectivity, always publish AAAA and bind listeners to `[::]`.  
Running IPv6 on the host but exposing only IPv4 in DNS produces nondeterministic failures that appear as u

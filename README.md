# WSO2 API Management in Docker

Docker-first scaffold for a WSO2 API management deployment with a management plane (Admin + Publisher + Developer Portal) and a data plane gateway segment that fronts an internal backend network.

## Topology
- Management plane: WSO2 API Manager reachable on https://localhost:9443 (self-signed certificate). HTTP is available on http://localhost:9763 for local testing.
- Data plane (DMZ): Choreo Connect gateway (adapter, enforcer, router) exposed on http://localhost:9090.
- Internal network: Sample backend (httpbin-compatible) bound to port 8081 on the host for debugging.

### TOGAF-style deployment view
```
+--------------------+     mgmt_net (control)     +----------------------+
|  Management Plane  | <------------------------> |   DMZ Data Plane    |
|  WSO2 API Manager  |                            | Choreo Connect GW   |
|  (Admin/Portal)    |                            | (adapter/enforcer/  |
|  9443 / 9763       |                            |  router) 9090/9095  |
+--------------------+                            +----------+-----------+
                                                                |
                                                                | internal_net (east-west)
                                                                v
                                                      +------------------+
                                                      |  Internal Apps   |
                                                      |  httpbin sample  |
                                                      |  backend:8080    |
                                                      +------------------+

External clients -> dmz_net -> Gateway router 9090 -> upstream to internal_net
```

Networks in `docker-compose.yml`:
- `mgmt_net`: control-plane traffic between API Manager and gateways.
- `dmz_net`: external-facing gateway segment.
- `internal_net`: east-west traffic to backend services.

## Prerequisites
- Docker and Docker Compose v2
- At least 6 GB RAM allocated to Docker (WSO2 images are resource-hungry)

## Quick start
1) Set versions and credentials in `.env` if you want different defaults.
2) Start the stack:
   ```sh
   docker compose up -d
   ```
3) Access portals:
   - Admin/Publisher/Developer Portal: https://localhost:9443 (user/password from `.env`)
   - Gateway: http://localhost:9090
   - Sample backend (debug only): http://localhost:8081
4) Import or create an API in Publisher, publish, and subscribe via the Developer Portal. The gateway routes `/httpbin` to the sample backend by default (see `config/choreo-connect/config.toml`).

Gateway mTLS note: adapter/enforcer expect `mg.pem` and `mg.key` mounted at `/home/wso2/security/keystore`. Dev-only self-signed files are provided under `config/choreo-connect/security/keystore`; replace them with your own cert/key pair for real environments.
Envoy trusts `/home/wso2/security/truststore/mg.pem` for upstream calls; a dev copy is mounted from `config/choreo-connect/security/truststore`.

## Adding another DMZ gateway segment
- Duplicate the `dmz-gateway-*` services in `docker-compose.yml`, rename them (for example, `dmz2-gateway-router`), and attach them to a new `dmz_net` variant (for example, `dmz_net_eu`).
- Point external DNS or load balancers at the new router listener port you expose.
- Adjust `config/choreo-connect/config.toml` per gateway if you want different upstreams or certificates.

## Notes and caveats
- Certificates: the stack uses self-signed certs. For real use, replace keystores/truststores and update the Choreo Connect config accordingly.
- Persistence: API Manager deployment artifacts persist in the `apim_repository` volume; clean it only if you want a fresh start.
- Resources: tune JVM heap via `JAVA_OPTS` and allocate more memory in Docker Desktop if containers restart due to OOM.
- This scaffold favors clarity over production hardening (no analytics, no external DBs, default credentials). Harden before non-demo use.

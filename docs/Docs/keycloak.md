# Keycloak

## Concepts & Definitions

### Overview

- **Keycloak realm**: a space where we manage objects: users, applications, roles and groups.
    A realm can shared/used for different applications if they share the same users and roles.
    A single realm interesting because we would have a single centralized identity managmeent server. It could also provide single sign on accross applications.

---

## Getting Started

### Creating a Realm and Users

 1. Create a custom realm for applications
    Give it name, mark it as enabled
 2. Create user, give him name, email (mark it as verified)
    - Each user is given an ID, if a db is not configured, the user ID is stored in an embeded h2 database
 3. Give user credentials: username & password = test
 4. To sign in to a different realm: go to `<KEYCLOAK_SERVER>/realms/<REALM_NAME>/account`

 5. A client = an application that requests auth on behalf of the user.
    Could a be a web UI, a backend API, etc...

    Create client, make it OpenID
    There is distinction between "public client" and "confidential client"
    - A public client: cannot securely store a client secret (web UI)
    - A confidential client: appropriate for server to server conn

    1. Valid redirect URIs: URIs related to an app, for now putting test app available online at <www.keycloak.org/app/>*
    2. Web origins: Base address (of app ?)

 6. Testing with test app: put local url of keycloak, realm name and client type
    After logging in, we fetch a token, the token is given by the server on `/realms/<REALM_NAME>/openid-connect/token`

 7. Another client: confidential client => Enable client authentication + tick service accounts roles
    No redirect/URIs needed
    We have client secret available, used to request an access token

### Request an access token

We then send a URL encoded form request like this:

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=public-client&username=test&password=test&scope=email%20openid"
```

Note that the grant_type=password is not recommended.

And we get an access token in response. The access token is JWT which contains info about the user, the keycloak client used, the user ID, the roles...
We also get a refresh token, which can be used to get a new access token.
To use the refresh token:

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=refresh_token&client_id=public-client&refresh_token=<REFRESH_TOKEN>"
```

For the confidential client:

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=client_credentials&client_id=confidential-client&client_secret=<CLIENT_SECRET>&scope=openid"
```

This returns an access token and an ID token to authenticate against servers

---

## Application Integration

### Argo CD

**Documentation:** [Argo CD Keycloak Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/)

**Client Type:** OpenID Connect

**Configuration Notes:**
- Watch out for config maps `argocd-cm` and `argocd-rbac-cm`
- If you encounter issues about an incorrect redirect URL, check the `url` field in `argocd-cm`
- If your user doesn't have sufficient rights after logging in, check the `policy.csv` field in `argocd-rbac-cm`

---

### Proxmox

**Documentation:** [Setup Guide](https://gist.github.com/jakoberpf/d6f519459f7dad3b30f509facdc22445)

**Client Type:** Confidential Client

**Configuration Steps:**
1. Create a confidential client in Keycloak
2. Enable client authentication
3. Give the client secret to Proxmox when creating a realm
4. Users will be auto-created on first login
5. Role assignment must be done manually on Proxmox side

---

### pgAdmin

**Documentation:** [pgAdmin OAuth2 Setup](https://www.olavgg.com/show/how-to-configure-pgadmin-4-with-oauth2-and-keycloak)

**Client Type:** Public Client

**Configuration:**
- Config file location: `/etc/pgadmin/config_system.py`
- More setup parameters: [pgAdmin OAuth2 Docs](https://www.pgadmin.org/docs/pgadmin4/development/oauth2.html)

---

### Grafana

**Documentation:** [Grafana Keycloak Integration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/keycloak/)

**Client Type:** OpenID Connect

**Keycloak Configuration:**
1. Create an OpenID Connect client
2. Configure valid redirect URIs

**Grafana Configuration:**
- Set the `root_url` option so the URL callback is correct if Grafana is behind a proxy
- Configure role mapping using jmespath expression

**Role Mapping:**
- Default suggestion: `contains(roles[*], 'admin') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'`
- **Note:** For Keycloak, use `resource_access.<CLIENT_ID>.roles` instead
- This field is mapped to the client (found at: Client scopes > roles > Mappers > client roles > Token Claim Name)
- Mapping should be added to either ID token or userinfo for it to be effective

---

### Immich

**Client Type:** Confidential Client

**Keycloak Configuration:**
1. Create a confidential client
2. Enable client authentication (checked)
3. Authentication flow: Enable Standard flow (checked)
4. Keep all other options unchecked

**Immich Configuration:**
- Configure OAuth using the client credentials from Keycloak

---

### Portainer

**Client Type:** Confidential Client (with OAuth 2.0)

**Portainer OAuth Configuration:**
```
authorization url:  KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/auth
access token url:   KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/token
resource url:       KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/userinfo
redirect url:       PORTAINER_URL
logout url:         KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/logout
user identifier:    preferred_username
scopes:             openid email profile offline_access roles
```

**Keycloak Client Configuration:**
- Client authentication: **Yes**
- Authorization: **Yes**
- Standard flow: **Yes**
- Direct access grants: **Yes**
- OAuth 2.0 Device Authorization Grant: **Yes**
- Automatic user provisioning: **Enable**

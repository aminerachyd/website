---
tags:
  - keycloak
  - oauth
  - oidc
---

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
   - Give it a name
   - Mark it as enabled

2. Create a user
   - Give them a name and email (mark email as verified)
   - Each user is given an ID; if a DB is not configured, the user ID is stored in an embedded H2 database

3. Give user credentials
   - Username and password (e.g., test/test)

4. Sign in to a different realm
   - Navigate to: `<KEYCLOAK_SERVER>/realms/<REALM_NAME>/account`

5. Create a client (application)
   - A client is an application that requests auth on behalf of the user
   - Can be a web UI, backend API, etc.
   - Make it OpenID Connect
   - Choose between:
     - **Public client**: Cannot securely store a client secret (web UIs)
     - **Confidential client**: Appropriate for server-to-server connections
   - Configure:
     - Valid redirect URIs: URIs related to your app
     - Web origins: Base address of your app

6. Test with test app
   - Put local URL of Keycloak, realm name, and client type
   - After logging in, fetch a token from: `/realms/<REALM_NAME>/openid-connect/token`

7. Create a confidential client for service accounts
   - Enable client authentication
   - Tick "Service accounts roles"
   - No redirect URIs needed
   - Client secret is available for requesting access tokens

### Request an Access Token

We then send a URL encoded form request like this:

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=public-client&username=test&password=test&scope=email%20openid"
```

!!! note
    The `grant_type=password` is not recommended for production use.

The response contains an access token (JWT) with user info, Keycloak client info, user ID, and roles. A refresh token is also provided for obtaining new access tokens.

**Using refresh token:**

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&client_id=public-client&refresh_token=<REFRESH_TOKEN>"
```

**Using client credentials (confidential client):**

```bash
curl -k -X POST http://<KEYCLOAK_SERVER>/realms/testrealm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=confidential-client&client_secret=<CLIENT_SECRET>&scope=openid"
```

This returns an access token and an ID token for server-to-server authentication.

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

```ini
authorization_url = KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/auth
access_token_url = KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/token
resource_url = KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/userinfo
redirect_url = PORTAINER_URL
logout_url = KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/logout
user_identifier = preferred_username
scopes = openid email profile offline_access roles
```

**Keycloak Client Configuration:**

- Client authentication: **Yes**
- Authorization: **Yes**
- Standard flow: **Yes**
- Direct access grants: **Yes**
- OAuth 2.0 Device Authorization Grant: **Yes**
- Automatic user provisioning: **Enable**

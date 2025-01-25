# Notes: Keycloak

A default "master" real is available, but it's not considered a good practice to use it

### Some definitions

- **Keycloak realm**: a space where we manage objects: users, applications, roles and groups.
    A realm can shared/used for different applications if they share the same users and roles.
    A single realm interesting because we would have a single centralized identity managmeent server. It could also provide single sign on accross applications.

### Creating a realm and users in it

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

    1. Valid redirect URIs: URIs related to an app, for now putting test app available online at www.keycloak.org/app/*
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

## Keycloak setup for applications

- [Argo CD](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/)
  Notes: Watch out for config maps `argocd-cm` and `argocd-rbac-cm`. If you encounter issues about an incorrect redirect URL, check the `url` field in the former. If your user doesn't have sufficient rights after logging, check the `policy.csv` field in the latter.
- [Proxmox](https://gist.github.com/jakoberpf/d6f519459f7dad3b30f509facdc22445)
  Notes: Needs a confidential client. The client secret should be given to Proxmox when creating a realm. Users should be autocreated, role assignment however needs to be done manually on Proxmox
- [pgadmin](https://www.olavgg.com/show/how-to-configure-pgadmin-4-with-oauth2-and-keycloak)
  Notes: The config file can be named `config_system.py` and put in `/etc/pgadmin`. More setup parameters available [here](https://www.pgadmin.org/docs/pgadmin4/development/oauth2.html) 
- [Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/keycloak/)
  Notes: the `root_url` option has to be set so the URL callback is correct if Grafana is behind a proxy
- Portainer: oauth configuration
  - `authorization url`: KEYLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/auth
  - `access token url`: KEYLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/token
  - `resource url`: KEYLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/userinfo
  - `redirect url`: PORTAINER_URL
  - `logout url`: KEYLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/logout
  - `user identifier`: preferred_username
  - `scopes`: openid email profile offline_access roles
  
  Make sure to also enable the **automatic user provisioning**
  

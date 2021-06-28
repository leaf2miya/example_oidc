# oidc example
## environment
 use docker (with docker-compose)
### docker containers
 * kc  
   role: OpenID Connect IdP  
     keycloak server (use postgreSQL in the backend postgres container)  
 * postgres  
   role: PostgreSQL Server  
     Used from keycloak server  
 * sp  
   role: OpenID Connect RP (use Apache module)  
     For easy confirmation of OpenID Connect  
 * sp2  
   role: OpenID Connect RP (use sinatra + omniauth\_openid\_connect)  
     Pseudo portal server  
 * sp3  
   role: Backend service server (REST API server)  
     API is called from portal server(sp2)  
## Setup
### docker-compose
 1. rename .env.sample to .env (if you want to use .env file in docker-compose environment)
 1. edit .env
 1. edit docker-compose.yml
### register and setting RP(for sp container)
 1. access to keycloak http://hostname:port/auth/
 1. logged in (KEYCLOAK\_USER:KEYCLOAK\_PASSWORD (see environment sector in docker-compose))
 1. select admin console
 1. choose Configure\>Clients
 1. click 'Create'
 1. input ClientID and Save. show Clients Detail page
 1. choose Settings tab
 1. following settings  
    Access Type: 'confidential'  
    Valid Redirect URIs: http://hostname:port/secure (redirect sp container)  
    Enabled: ON
    Always Display in Console: ON|OFF (show confirmation page)
    etc...  
 1. choose Credentials tab
 1. take notes: 'Secret' value
 1. choose Manage\>Users
 1. click 'Add user'
 1. input Username and click Save (it's login user)
 1. choose Credentials
 1. set Password
### register and setting RP(for sp2 container)
 1. access to keycloak http://hostname:port/auth/
 1. logged in (KEYCLOAK\_USER:KEYCLOAK\_PASSWORD (see environment sector in docker-compose))
 1. select admin console
 1. choose Configure\>Clients
 1. click 'Create'
 1. input ClientID and Save. show Clients Detail page
 1. choose Settings tab
 1. following settings  
    Access Type: 'confidential'  
    Valid Redirect URIs:  
      http://hostname:port/auth/openid_connect/callback (redirect to sp2 container after authentication)  
      http://hostname:port/auth/logout (redirect to sp2 container after logout)  
    Enabled: ON
    Always Display in Console: ON|OFF (show confirmation page)
    etc...  
 1. choose Credentials tab
 1. take notes: 'Secret' value
 1. choose Manage\>Users
 1. click 'Add user'
 1. input Username and click Save (it's login user)
 1. choose Credentials
 1. set Password
### register and setting Resource Server(for sp3 container)
 1. access to keycloak http://hostname:port/auth/
 1. logged in (KEYCLOAK\_USER:KEYCLOAK\_PASSWORD (see environment sector in docker-compose))
 1. select admin console
 1. choose Configure\>Clients
 1. click 'Create'
 1. input ClientID and Save. show Clients Detail page
 1. choose Settings tab
 1. following settings  
    Access Type: 'bearer-only'  
    etc...  
 1. choose Credentials tab
 1. take notes: 'Secret' value
### RP (sp container)
 1. edit /etc/apache2/mods-available/auth\_openidc.conf
   ```
   OIDCProviderMetadataURL       http://hostname:port/auth/realms/<realm name>/.well-known/openid-configuration (kc container url)
   OIDCClientID                  <identifier>
   OIDCClientSecret              <secret>
   OIDCRedirectURI               http://hostname:port/secure (sp container url)
   ```
 1. restart sp container
### RP (sp2 container)
 1. rename keycloak\_rp.env.sample to keycloak\_rp.env
 1. edit keycloak\_rp.env
   edit OpendID Connect params(references: https://github.com/m0n9oose/omniauth_openid_connect)
### RP (sp3 container)
 1. rename keycloak\_backend.env.sample to keycloak\_backend.env
 1. edit keycloak\_backend.env
## Run
 ```
   $ docker-compose build [options]
   $ docker-compose up [options]
 ```
## Example
### simple test: Authentication flow (view informations)
 access to http://hostname:port/secure/test.php (sp container)
### simple test: Authentication flow & call REST API (with token)
 access to http://hostname:port/ (sp2 container)
## KeyCloak Hint
 * show well-known openid configuration  
   http://hostname:port/auth/realms/<realm name>/.well-known/openid-configuration (kc container)
 * add user attribute  
   1. clients>(your client)>Mappers, click Create
   1. create new mapper  
     MapperType: User Attribute
   1. Users>(add attribute user)>attribute, add attribute(attribute name is specified by the User Attribute name in mapper)
 * show signature key information  
   1. Realm Settings>Keys
 * add new scope  
   1. select Client Sposes, and click Create
   1. edit scope data, and click save
   1. Clients>(your client)>Client Scopes
   1. add new scope to Assigned {Optional or Default} Client Scopes

#!/bin/bash

# Ensure the Keycloak domain name is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <keycloak-domain-name>"
    exit 1
fi

KEYCLOAK_DOMAIN_NAME=$1

echo "Creating CheCluster patch file with Keycloak domain: $KEYCLOAK_DOMAIN_NAME"

# Create the che-cluster-patch.yaml file
cat <<EOF > che-cluster-patch.yaml
spec:
  networking:
    auth:
      oAuthClientName: k8s-client
      oAuthSecret: eclipse-che
      identityProviderURL: "https://$KEYCLOAK_DOMAIN_NAME/realms/che"
      gateway:
        oAuthProxy:
          cookieExpireSeconds: 300
        deployment:
          containers:
          - env:
             - name: OAUTH2_PROXY_BACKEND_LOGOUT_URL
               value: "http://$KEYCLOAK_DOMAIN_NAME/realms/che/protocol/openid-connect/logout?id_token_hint={id_token}"
            name: oauth-proxy
  components:
    cheServer:
      extraProperties:
        CHE_OIDC_USERNAME__CLAIM: email
EOF

if [ $? -eq 0 ]; then
    echo "CheCluster patch file 'che-cluster-patch.yaml' created successfully."
else
    echo "Failed to create CheCluster patch file. Please check for errors."
    exit 1
fi

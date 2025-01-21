#!/bin/bash

# Ensure arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <keycloak-domain-name>"
    exit 1
fi

KEYCLOAK_DOMAIN_NAME=$1

echo "Setting up Keycloak for domain: $KEYCLOAK_DOMAIN_NAME"

# Step 1: Create Namespace
echo "Creating Keycloak namespace..."
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Create Certificate for Keycloak
echo "Creating Certificate for Keycloak..."
# cat <<EOF | kubectl apply -f -
# apiVersion: cert-manager.io/v1
# kind: Certificate
# metadata:
#   name: keycloak
#   namespace: keycloak
#   labels:
#     app: keycloak
# spec:
#   secretName: keycloak.tls
#   issuerRef:
#     name: che-letsencrypt
#     kind: ClusterIssuer
#   commonName: $KEYCLOAK_DOMAIN_NAME
#   dnsNames:
#   - $KEYCLOAK_DOMAIN_NAME
#   usages:
#     - server auth
#     - digital signature
#     - key encipherment
#     - key agreement
#     - data encipherment
# EOF


cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: che-letsencrypt
spec:
  acme:
    email: your@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: che-letsencrypt-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF



cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  secretName: keycloak.tls
  issuerRef:
    name: che-letsencrypt
    kind: ClusterIssuer
  commonName: $KEYCLOAK_DOMAIN_NAME
  dnsNames:
  - $KEYCLOAK_DOMAIN_NAME
  usages:
    - server auth
    - digital signature
    - key encipherment
    - key agreement
    - data encipherment
EOF







# Step 3: Deploy Keycloak Service and Deployment
echo "Deploying Keycloak Service and Deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    app: keycloak
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:18.0.2
        args: ["start-dev"]
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: "admin"
        - name: KC_PROXY
          value: "edge"
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
EOF

# Step 4: Create Ingress for Keycloak
echo "Creating Ingress for Keycloak..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: keycloak
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: '3600'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - $KEYCLOAK_DOMAIN_NAME
      secretName: keycloak.tls
  rules:
  - host: $KEYCLOAK_DOMAIN_NAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
EOF

# Step 5: Wait for Keycloak to be Ready
echo "Waiting for Keycloak pod to be ready..."
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=120s

# Step 6: Wait for Certificate Secret
echo "Waiting for Keycloak TLS secret to be created..."
until kubectl get secret -n keycloak keycloak.tls >/dev/null 2>&1; do
    sleep 5
done

# Step 7: Configure Keycloak Realm, Client, and User
echo "Configuring Keycloak..."
kubectl exec deploy/keycloak -n keycloak -- bash -c \
    "/opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user admin \
        --password admin && \
    /opt/keycloak/bin/kcadm.sh create realms \
        -s realm='che' \
        -s displayName='che' \
        -s enabled=true \
        -s registrationAllowed=false \
        -s resetPasswordAllowed=true && \
    /opt/keycloak/bin/kcadm.sh create clients \
        -r 'che' \
        -s clientId=k8s-client \
        -s id=k8s-client \
        -s redirectUris='[\"*\"]' \
        -s directAccessGrantsEnabled=true \
        -s secret=eclipse-che && \
    /opt/keycloak/bin/kcadm.sh create users \
        -r 'che' \
        -s username=test \
        -s email=\"test@test.com\" \
        -s enabled=true \
        -s emailVerified=true && \
    /opt/keycloak/bin/kcadm.sh set-password \
        -r 'che' \
        --username test \
        --new-password test"

echo "Keycloak setup completed successfully!"
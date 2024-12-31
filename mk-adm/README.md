# Installation with KubeADM wit minikube configuration

### 1. Install cert-manager

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --wait \
  --create-namespace \
  --namespace cert-manager \
  --set installCRDs=true
```

### 2. Install and Deploy **KeyCloak**

```sh
kubectl apply -f ./install-keycloak.yaml
```

```sh
kubectl apply -f ./deploy-keycloak.yaml
```

### 3. Save Keycloak CA certificate

```sh
kubectl get secret ca.crt -o "jsonpath={.data['ca\.crt']}" -n keycloak | base64 -d > keycloak-ca.crt
chmod 755 keycloak-ca.crt
```

### 4. Bind Kubernetes to use Keycloak as OIDC provider

#### 4.1. Copy Keycloak's certificate to your system keystore

```sh
sudo cp keycloak-ca.crt /etc/ca-certificates/keycloak-ca.crt
```

- This certificate file must be reachable by your Kubernetes cluster.

#### 4.2. Add the following configuration to `/etc/kubernetes/manifests/kube-apiserver.yaml`

```sh
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

- Please replace `<your-cluster-domain>` !

```sh
    - --oidc-issuer-url=https://keycloak.devpath.xyz/realms/che
    - --oidc-username-claim=email
    - --oidc-client-id=k8s-client
    - --oidc-ca-file=/etc/ca-certificates/keycloak-ca.crt
```

- Wait 2 minute and check that the cluster `kubectl get pods -A`

### 5. Configure Keycloak to create the realm, client, and user

```sh
kubectl exec deploy/keycloak -n keycloak -- bash -c \
    "/opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user admin  \
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
        -s emailVerified=true &&  \
    /opt/keycloak/bin/kcadm.sh set-password \
        -r 'che' \
        --username test \
        --new-password test"
```

### 6. Copy Keycloak CA certificate into the eclipse-che namespace:

```sh
kubectl create namespace eclipse-che &&  \
kubectl create configmap keycloak-certs \
    --from-file=keycloak-ca.crt=keycloak-ca.crt \
    -n eclipse-che && \
```

```sh
kubectl label configmap keycloak-certs \
    app.kubernetes.io/part-of=che.eclipse.org \
    app.kubernetes.io/component=ca-bundle \
    -n eclipse-che
```

### 7. here che-patch.yaml is set.

### 8. Create the Che instance with `chectl`

```sh
chectl server:deploy --platform k8s --domain che.devpath.xyz --che-operator-cr-patch-yaml che-patch.yaml --skip-cert-manager
```

---

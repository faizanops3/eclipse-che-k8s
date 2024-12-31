# Installing Che on Minikube with Keycloak as the OIDC provider

### 1. Install Minikube

```sh
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
```

### 2. Helm

```sh
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### 3. kubectl

```sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### 4. chectl

```sh
bash <(curl -sL  https://che-incubator.github.io/chectl/install.sh)
```

- `chectl --version`

### 5. Install Docker

```sh
bash ./docker-install.sh
```

### 6. Start Minikube

```sh
minikube start --vm=true --memory=10240 --cpus=4 --disk-size=50GB --driver=docker
```

```sh
minikube status
```

### 7. Bare-MetalLLB and Nginx Ingress Controller

- Add Your IP in the script

```sh
vim ./matallb.sh
```

```sh
bash ./matallb.sh
```

### 8. Install cert-manager

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --wait \
  --create-namespace \
  --namespace cert-manager \
  --set installCRDs=true
```

```sh
kubectl get pods -n cert-manager
```

### 9. Install Keycloak

```sh
kubectl apply -f keycloak.yaml
```

### 10. Save Keycloak CA certificate

```sh
kubectl get secret ca.crt -o "jsonpath={.data['ca\.crt']}" -n keycloak | base64 -d > keycloak-ca.crt
```

```sh
ls | grep keycloak-ca.crt
```

### 11. Copy Keycloak CA certificate into Minikube

```sh
minikube ssh sudo "mkdir -p /etc/ca-certificates" && \
minikube cp keycloak-ca.crt /etc/ca-certificates/keycloak-ca.crt
```

### 12. Configure Minikube to use Keycloak as the OIDC provider

```sh
minikube start \
    --extra-config=apiserver.oidc-issuer-url=https://keycloak.devpath.xyz/realms/che \
    --extra-config=apiserver.oidc-username-claim=email \
    --extra-config=apiserver.oidc-client-id=k8s-client \
    --extra-config=apiserver.oidc-ca-file=/etc/ca-certificates/keycloak-ca.crt
```

#### Wait until the Keycloak pod is ready

```sh
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=120s
```

### 13. Configure Keycloak to create the realm, client, and user:

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

- **Output like this.**

```
Logging into http://localhost:8080 as user admin of realm master
Created new realm with id 'che'
Created new client with id 'k8s-client'
Created new user with id '1146eab4-b58f-47fa-ba3e-778930010c5c'
```

### 14. Copy Keycloak CA certificate into the eclipse-che namespace

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

### 15. Create the Che instance with chectl

```sh
chectl server:deploy --platform k8s --domain che.devpath.xyz --che-operator-cr-patch-yaml che-patch.yaml --skip-cert-manager
```

---

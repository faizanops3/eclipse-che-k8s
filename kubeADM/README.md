# Installation with KubeADM

## **A. Prerequisites**

### 1. Creating k8s Cluster

- Run `common.sh` and `install-k8s.sh` to create k8s cluster.

```sh
bash pre/common.sh
```

```sh
bash pre/install-k8s.sh
```

### 2. Metallb, Ingress Controller, Certmanager

- Add your IP `METALLB_PUBLIC_IP="<public ip>"`

```sh
vim pre/matallb.sh
```

```sh
bash pre/matallb.sh
```

### 3. Install Docker

```sh
bash pre/docker-install.sh
```

---

## **B. Setup Keycloak**

### 1. Set env variables and Export it.

```sh
vim keycloak/.env
```

```sh
export $(grep -v '^#' ./keycloak/.env | xargs)
```

### 2. Generate `certs` dir and start `Keycloak`

```sh
cd keycloak
bash ./generate-certs.sh
```

```sh
docker compose up -d
```

### 3. Create and configure the `kubernetes` client in `Keycloak`

```sh
bash ./configure-keycloak.sh
export $(grep -v '^#' .env | xargs)
```

```sh
cd ..
kubectl create ns test-ns
kubectl apply -f ./rbac.yaml
```

### 4. Bind Kubernetes to use Keycloak as OIDC provider

#### 4.1. Copy Keycloak's certificate to your system keystore

```sh
sudo cp ./keycloak/certs/ca/root-ca.pem /etc/ca-certificates/keycloak-ca.pem
```

- This certificate file must be reachable by your Kubernetes cluster.

#### 4.2. Add the following configuration to `/etc/kubernetes/manifests/kube-apiserver.yaml`

- Please replace `KEYCLOAK_EXTERNAL_URL` !

```sh
    - --oidc-issuer-url=$KEYCLOAK_EXTERNAL_URL/realms/master
    - --oidc-client-id=kubernetes
    - --oidc-username-claim=email
    - --oidc-groups-prefix='keycloak:'
    - --oidc-groups-claim=groups
    - --oidc-ca-file=/etc/ca-certificates/keycloak-ca.pem
```

- Wait 2 minute and check that the cluster `kubectl get pods -A`

#### 4.3. Make Keycloak accessible through your Ingress Controller

- Create **secret**

```sh
kubectl create secret tls tls-keycloak-ingress --cert ./keycloak/certs/keycloak/keycloak.pem --key ./keycloak/certs/keycloak/keycloak.key
```

- Generate `ingress-keycloak.yaml` file

```sh
sed "s|\$KEYCLOAK_EXTERNAL_URL|${KEYCLOAK_EXTERNAL_URL#https://}|g" ingress-keycloak-example.yaml > ingress-keycloak.yaml
sed -i "s|\$CHE_EXTERNAL_URL|${CHE_EXTERNAL_URL#https://}|g" ingress-keycloak.yaml
```

```sh
kubectl apply -f ./ingress-keycloak.yaml
```

---

## **C. Install Eclipse Che**

### 1. Install the `chectl` command line

```sh
bash <(curl -sL  https://che-incubator.github.io/chectl/install.sh)
```

- Check: `chectl --version`

### 2. Configure Keycloak certificates for Che

```sh
kubectl create namespace eclipse-che
kubectl create configmap keycloak-certs \
    --from-file=keycloak-ca.crt=./keycloak/certs/keycloak/tls.crt \
    -n eclipse-che
```

```sh
kubectl label configmap keycloak-certs \
    app.kubernetes.io/part-of=che.eclipse.org \
    app.kubernetes.io/component=ca-bundle \
    -n eclipse-che
```

### 3. Generate the config file and run the install

#### 3.1. Generate che-patch.yaml with variables

```sh
cp che-patch-example.yaml che-patch.yaml
sed -i "s|\$KEYCLOAK_CHE_CLIENT_SECRET|${KEYCLOAK_CHE_CLIENT_SECRET}|g" che-patch.yaml
sed -i "s|\$KEYCLOAK_CHE_CLIENT_ID|${KEYCLOAK_CHE_CLIENT_ID}|g" che-patch.yaml
sed -i "s|\$KEYCLOAK_EXTERNAL_URL|${KEYCLOAK_EXTERNAL_URL}|g" che-patch.yaml
sed -i "s|\$CHE_EXTERNAL_URL|${CHE_EXTERNAL_URL}|g" che-patch.yaml
```

#### 3.2. Deploy

- Replace `CHE_EXTERNAL_URL` with the domain without `https://`
- Make sure you have a **`default storage class`** installed on your cluster.

```sh
chectl server:deploy --platform k8s --domain CHE_EXTERNAL_URL --che-operator-cr-patch-yaml che-patch.yaml --skip-cert-manager
```

> If something goes wrong, you can uninstall Che using the following commands:
>
> ```sh
> chectl server:delete --delete-all --delete-namespace
> ```
>
> Run again commands from step 2.

### 4. Connect to `CHE_EXTERNAL_URL`

```sh
echo $CHE_EXTERNAL_URL
```

---

```sh
 Eclipse Che 7.96.0 has been successfully deployed.
    ✔ Documentation             : https://www.eclipse.org/che/docs/
    ✔ -------------------------------------------------------------------------------
    ✔ Users Dashboard           : https://che.devpath.xyz/dashboard/
    ✔ -------------------------------------------------------------------------------
Command server:deploy has completed successfully in 05:13
```

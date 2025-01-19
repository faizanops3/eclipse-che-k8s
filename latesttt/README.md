# Eclipse che with kubeADM

### 1. Setting up kubeadm cluster

- Installing all the required packages for kubeadm

```sh
bash ./prerequisites/common.sh
```

- Initializing kubernetes cluster

```sh
bash ./prerequisites/install-k8s.sh
```

> **Verify:** `kubectl get nodes`

### 2. Setting up StorageAccount with OpenEBS

```sh
bash ./prerequisites/openebs.sh
```

### 3. Installing `Helm`, `chectl`, `cert-manager`

```sh
bash ./prerequisites/tools.sh
```

##### **Verify:**

- chectl: `chectl --version`

- cert-manager: `kubectl get pods -n cert-manager`

### 4. Installing MetalLlb & Nginx ingress controller

- Replace `<public_ip>` with you vm public IP.

```sh
bash ./prerequisites/metallb.sh "<public_ip>"
```

- You should see your public IP as `EXTERNAL IP`.

### 5. Creating Let’s Encrypt certificate for che

#### 5.1. Adding Domain

For HTTP01 validation, ensure the domain `che.example.com` is pointing to the external IP of your ingress controller. Add an A record in your DNS provider:

- Name: `che.example.com`
- Value: `<Ingress Controller External IP>`

#### 5.2. Set up ClusterIssuer and Create a Certificate for Eclipse Che

- Add your email for SSL renewal
- Add your che domain

```sh
bash ./setup_letsencrypt_che.sh "your-email@example.com" "che.example.com"
```

##### **Verify**

- `kubectl get certificate che-tls -n eclipse-che`

- **Verify the certificate creation:**

```sh
kubectl describe certificate che-tls -n eclipse-che
```

Check for `Ready: True`.

Verify Certificate: `kubectl get secret che-tls -n eclipse-che`

### 7. Installing Che

#### 7.1. Prepare a CheCluster patch YAML file:

- Replace `keycloak.example.com` with your domain

```sh
bash ./create_che_patch.sh "keycloak.example.com"
```

- This will generate a `che-cluster-patch.yaml` file.

#### 7.2. Deploy Che:

- Replace `$CHE_DOMAIN_NAME` with che domain

```sh
chectl server:deploy \
    --platform k8s \
    --domain $CHE_DOMAIN_NAME \
    --skip-cert-manager \
    --k8spodreadytimeout 240000 \
    --k8spoddownloadimagetimeout 240000
```

- Visit your domain.!

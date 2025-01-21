Here’s a complete step-by-step guide to set up and issue a certificate for Keycloak using cert-manager:

---

### Step 1: **Set Environment Variables**

Define the `KEYCLOAK_DOMAIN_NAME` environment variable:

```bash
export KEYCLOAK_DOMAIN_NAME="keycloak.devpath.xyz"
```

---

### Step 2: **Install cert-manager**

Ensure cert-manager is installed and running in your Kubernetes cluster:

```bash
kubectl get pods -n cert-manager
```

If not installed, you can install cert-manager using Helm:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.1 \
  --set installCRDs=true
```

---

### Step 3: **Create the ClusterIssuer**

Create a `ClusterIssuer` named `che-letsencrypt` for Let's Encrypt:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: che-letsencrypt
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: che-letsencrypt-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

Verify the `ClusterIssuer` is ready:

```bash
kubectl describe clusterissuer che-letsencrypt
```

---

### Step 4: **Create the Certificate Resource**

Apply the `Certificate` resource for Keycloak:

```yaml
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
```

---

### Step 5: **Monitor Certificate Issuance**

Check the status of the certificate and its resources:

```bash
kubectl get certificate -n keycloak
kubectl describe certificate keycloak -n keycloak
kubectl get certificaterequest,order,challenge -n keycloak
```

Inspect the `Events` section for any issues. cert-manager will handle the HTTP-01 challenge using the Nginx ingress.

---

### Step 6: **Verify the Secret**

Once the certificate is ready, verify the `keycloak.tls` secret:

```bash
kubectl get secret keycloak.tls -n keycloak -o yaml
```

It should contain:

- `tls.crt` (the certificate)
- `tls.key` (the private key)

---

### Step 7: **Configure Keycloak**

Update Keycloak to use the generated certificate. Modify the Keycloak deployment or StatefulSet to mount the `keycloak.tls` secret:

```yaml
        volumeMounts:
        - name: keycloak-tls
          mountPath: /etc/x509/https
          readOnly: true
      volumes:
      - name: keycloak-tls
        secret:
          secretName: keycloak.tls
```

Set the environment variable in Keycloak to point to the certificate:

```yaml
- name: X509_CA_BUNDLE
  value: /etc/x509/https/tls.crt
```

---

### Step 8: **Test HTTPS**

Access Keycloak using the configured domain:

```bash
https://keycloak.devpath.xyz
```

---

### Step 9: **Monitor Certificate Renewals**

Cert-manager will automatically renew the certificate before it expires. You can monitor the process:

```bash
kubectl describe certificate keycloak -n keycloak
```

---

This guide covers all steps needed to set up and use cert-manager for issuing a TLS certificate for Keycloak. Let me know if you need further clarification!

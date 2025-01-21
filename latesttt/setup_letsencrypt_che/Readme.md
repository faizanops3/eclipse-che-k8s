To configure cert-manager with **Cloudflare** as the DNS provider for `dns-01` challenge validation, follow these steps:

---

### 1. **Create a Cloudflare API Token**:

1. Log in to your Cloudflare account.
2. Navigate to **My Profile > API Tokens**.
3. Create a new API token with the following permissions:
   - **Zone**: `DNS` - `Edit`
   - **Zone Resources**: Include the zone you want to manage (`che.devpath.xyz`).
4. Save the API token securely.

---

### 2. **Create a Secret for the Cloudflare API Token**:

Store the Cloudflare API token as a Kubernetes secret. Replace `<namespace>` with your cert-manager namespace, e.g., `cert-manager`:

```bash
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=<your-cloudflare-api-token> \
  -n cert-manager
```

---

### 3. **Update the ClusterIssuer**:

Edit your `ClusterIssuer` to include the `dns-01` solver for Cloudflare:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          cloudflare:
            email: your@gmail.com # Cloudflare account email
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

---

### 4. **Create Separate Certificates**:

Separate your certificates for `http-01` and `dns-01` challenges as described earlier:

#### Certificate for `che.devpath.xyz` (using `http-01`):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: che-tls
  namespace: eclipse-che
spec:
  secretName: che-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: che.devpath.xyz
  dnsNames:
    - che.devpath.xyz
```

#### Certificate for `*.che.devpath.xyz` (using `dns-01`):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: che-wildcard-tls
  namespace: eclipse-che
spec:
  secretName: che-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "*.che.devpath.xyz"
  dnsNames:
    - "*.che.devpath.xyz"
```

---

### 5. **Apply the Configuration**:

Apply the updated `ClusterIssuer` and `Certificate` resources:

```bash
kubectl apply -f clusterissuer-cloudflare.yaml
kubectl apply -f certificate-http01.yaml
kubectl apply -f certificate-dns01.yaml
```

---

### 6. **Monitor Progress**:

Monitor the resources to ensure certificates are issued successfully:

```bash
kubectl get certificaterequest,order,challenge -n eclipse-che
kubectl describe certificaterequest <name> -n eclipse-che
kubectl describe order <name> -n eclipse-che
kubectl describe challenge <name> -n eclipse-che
```

---

### 7. **Validate DNS Records**:

Cert-manager will automatically update DNS TXT records for `dns-01` challenges. You can verify these records using:

```bash
dig -t txt _acme-challenge.che.devpath.xyz
dig -t txt _acme-challenge.devpath.xyz
```

---

### 8. **Test HTTPS**:

After successful certificate issuance, test the HTTPS configuration by accessing:

- `https://che.devpath.xyz`
- `https://<subdomain>.che.devpath.xyz`

---

This setup ensures cert-manager uses Cloudflare for `dns-01` challenges and Nginx for `http-01` challenges, effectively resolving your certificate issuance issues. Let me know if you encounter any errors!

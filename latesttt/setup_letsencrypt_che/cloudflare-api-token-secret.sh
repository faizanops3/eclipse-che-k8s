#!/bin/bash

kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=<your-cloudflare-api-token> \
  -n cert-manager

if [ $? -eq 0 ]; then
    echo "Cloudflare API Token secret created successfully."
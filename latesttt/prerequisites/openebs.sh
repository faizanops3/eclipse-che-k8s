#!/bin/bash

echo "Installing OpenEBS..."

kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-device
provisioner: openebs.io/local
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
parameters:
  storageType: "device"
EOF
kubectl patch storageclass local-device -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


# Setup horizontal scaler on Kubernetes

1. Enable Kubernetes in Docker Desktop

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

2. Install Metrics Server
- First check whether metrics already work:

```bash
kubectl top nodes
```
- If Metrics Server is missing, install it:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

- If its **logs** show a kubelet certificate error: i.e on running **kubectl logs -n kube-system <metric-server>**
- This disables kubelet certificate verification; use it for local testing only. Metrics Server’s README also lists Kubernetes version compatibility. Metrics Server documentation
- For your local Docker Desktop cluster, add the certificate workaround:

```bash
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```


## TO use Horizontal scaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache # match deployment name
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache # match deployment name
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

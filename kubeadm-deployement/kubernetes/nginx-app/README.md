# Nginx Application Deployment on AWS Kubernetes

This directory contains Kubernetes manifests for deploying an nginx application with AWS Load Balancer integration.

## Files

- **deployment.yaml**: Nginx deployment with 3 replicas, health checks, and resource limits
- **service.yaml**: LoadBalancer service that creates an AWS Network Load Balancer (NLB)
- **pod.yaml**: Standalone nginx pod for testing purposes

## Deployment Instructions

### 1. Deploy the Application

```bash
# Apply all manifests at once
kubectl apply -f kubernetes/nginx-app/

# Or apply individually
kubectl apply -f kubernetes/nginx-app/deployment.yaml
kubectl apply -f kubernetes/nginx-app/service.yaml
```

### 2. Verify Deployment

```bash
# Check deployment status
kubectl get deployments
kubectl rollout status deployment/nginx-deployment

# Check pods
kubectl get pods -l app=nginx

# Check service and get external IP
kubectl get svc nginx-service
```

### 3. Get Load Balancer URL

```bash
# Wait for external IP to be assigned (may take 2-3 minutes)
kubectl get svc nginx-service -w

# Once EXTERNAL-IP is available, access the application
curl http://<EXTERNAL-IP>
```

### 4. Scale the Deployment

```bash
# Scale to 5 replicas
kubectl scale deployment/nginx-deployment --replicas=5

# Verify scaling
kubectl get pods -l app=nginx
```

### 5. Update the Application

```bash
# Update nginx image version
kubectl set image deployment/nginx-deployment nginx=nginx:1.25

# Check rollout status
kubectl rollout status deployment/nginx-deployment

# Rollback if needed
kubectl rollout undo deployment/nginx-deployment
```

## Service Details

The service is configured as **LoadBalancer** type with the following AWS annotations:

- `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"` - Uses Network Load Balancer
- `service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"` - Enables cross-AZ load balancing
- `service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"` - Backend protocol is HTTP

## Cleanup

```bash
# Delete all resources
kubectl delete -f kubernetes/nginx-app/

# Or delete individually
kubectl delete deployment nginx-deployment
kubectl delete service nginx-service
kubectl delete pod nginx-pod
```

## Troubleshooting

### Check Pod Logs

```bash
kubectl logs -l app=nginx
kubectl logs deployment/nginx-deployment
```

### Describe Resources

```bash
kubectl describe deployment nginx-deployment
kubectl describe service nginx-service
kubectl describe pod <pod-name>
```

### Check Events

```bash
kubectl get events --sort-by='.lastTimestamp'
```

### Service Not Getting External IP

```bash
# Check if AWS Load Balancer Controller is installed
kubectl get pods -n kube-system | grep aws-load-balancer

# Check service events
kubectl describe svc nginx-service
```

## Notes

- The deployment uses **3 replicas** for high availability
- Resource limits are set to prevent resource exhaustion
- Health probes ensure only healthy pods receive traffic
- The AWS Load Balancer is automatically created when the service is deployed
- Make sure your worker nodes have the appropriate IAM roles for creating load balancers

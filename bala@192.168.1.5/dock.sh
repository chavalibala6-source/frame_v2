docker build --no-cache -t balu051989/frame_v2-web:latest .
kubectl rollout restart deployment/frame-v2 && sleep 2 && kubectl get pods -l app=frame-v2 --watch &deployment.apps/frame-v2 restarted

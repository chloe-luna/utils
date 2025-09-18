#!/bin/bash
# Critical Infrastructure Repository Sets
# Organized by priority and category for offline development

# Create directory structure
mkdir -p repo_lists/{tier1_essential,tier2_advanced,tier3_specialized}

# =============================================================================
# TIER 1: ABSOLUTELY ESSENTIAL (Download First)
# =============================================================================

cat > repo_lists/tier1_essential/containers_runtime.txt << 'EOF'
# Container Runtimes & Core Tools
https://github.com/moby/moby
https://github.com/containerd/containerd
https://github.com/opencontainers/runc
https://github.com/containers/podman
https://github.com/containers/buildah
https://github.com/containers/skopeo
https://github.com/containers/crun
https://github.com/opencontainers/runtime-spec
https://github.com/opencontainers/image-spec
https://github.com/containers/image
EOF

cat > repo_lists/tier1_essential/kubernetes_core.txt << 'EOF'
# Kubernetes Essentials
https://github.com/kubernetes/kubernetes
https://github.com/kubernetes/kubectl
https://github.com/kubernetes/client-go
https://github.com/kubernetes/api
https://github.com/kubernetes/apimachinery
https://github.com/kubernetes/kubelet
https://github.com/kubernetes/kube-proxy
https://github.com/kubernetes/apiserver
https://github.com/etcd-io/etcd
EOF

cat > repo_lists/tier1_essential/networking_core.txt << 'EOF'
# Core Networking
https://github.com/containernetworking/cni
https://github.com/containernetworking/plugins
https://github.com/flannel-io/flannel
https://github.com/projectcalico/calico
https://github.com/kubernetes/ingress-nginx
https://github.com/envoyproxy/envoy
https://github.com/coredns/coredns
https://github.com/metallb/metallb
EOF

cat > repo_lists/tier1_essential/web_essentials.txt << 'EOF'
# Web Server Essentials
https://github.com/nginx/nginx
https://github.com/apache/httpd
https://github.com/traefik/traefik
https://github.com/caddyserver/caddy
https://github.com/hashicorp/consul-template
EOF

cat > repo_lists/tier1_essential/monitoring_basics.txt << 'EOF'
# Basic Monitoring (Essential for Production)
https://github.com/prometheus/prometheus
https://github.com/grafana/grafana
https://github.com/prometheus/node_exporter
https://github.com/prometheus/alertmanager
https://github.com/grafana/loki
EOF

cat > repo_lists/tier1_essential/security_core.txt << 'EOF'
# Security Essentials
https://github.com/cert-manager/cert-manager
https://github.com/open-policy-agent/opa
https://github.com/open-policy-agent/gatekeeper
https://github.com/aquasecurity/trivy
https://github.com/falcosecurity/falco
EOF

# =============================================================================
# TIER 2: ADVANCED TOOLS (Download Second)
# =============================================================================

cat > repo_lists/tier2_advanced/orchestration_advanced.txt << 'EOF'
# Advanced Orchestration
https://github.com/helm/helm
https://github.com/argoproj/argo-cd
https://github.com/argoproj/argo-workflows
https://github.com/fluxcd/flux2
https://github.com/kustomize/kustomize
https://github.com/kubernetes-sigs/krew
https://github.com/kubernetes-sigs/kind
https://github.com/k3s-io/k3s
https://github.com/k0sproject/k0s
https://github.com/rancher/rancher
EOF

cat > repo_lists/tier2_advanced/service_mesh.txt << 'EOF'
# Service Mesh
https://github.com/istio/istio
https://github.com/linkerd/linkerd2
https://github.com/consul-connect/consul-connect
https://github.com/servicemeshinterface/smi-spec
https://github.com/envoyproxy/go-control-plane
EOF

cat > repo_lists/tier2_advanced/storage_networking.txt << 'EOF'
# Storage & Advanced Networking
https://github.com/rook/rook
https://github.com/kubernetes-csi/external-provisioner
https://github.com/kubernetes-csi/external-attacher
https://github.com/openebs/openebs
https://github.com/longhorn/longhorn
https://github.com/cilium/cilium
https://github.com/antrea-io/antrea
https://github.com/vmware-tanzu/multus-cni
EOF

cat > repo_lists/tier2_advanced/ci_cd_tools.txt << 'EOF'
# CI/CD Pipeline Tools
https://github.com/jenkins-x/jx
https://github.com/tektoncd/pipeline
https://github.com/buildpacks/pack
https://github.com/GoogleContainerTools/kaniko
https://github.com/GoogleContainerTools/skaffold
https://github.com/drone/drone
https://github.com/concourse/concourse
EOF

cat > repo_lists/tier2_advanced/observability_advanced.txt << 'EOF'
# Advanced Observability
https://github.com/jaegertracing/jaeger
https://github.com/open-telemetry/opentelemetry-collector
https://github.com/elastic/elasticsearch
https://github.com/elastic/kibana
https://github.com/elastic/beats
https://github.com/fluent/fluentd
https://github.com/grafana/tempo
https://github.com/thanos-io/thanos
EOF

cat > repo_lists/tier2_advanced/development_tools.txt << 'EOF'
# Development & Debugging Tools
https://github.com/kubernetes/minikube
https://github.com/tilt-dev/tilt
https://github.com/telepresenceio/telepresence
https://github.com/GoogleContainerTools/jib
https://github.com/docker/compose
https://github.com/kubernetes/kompose
https://github.com/stern/stern
https://github.com/derailed/k9s
EOF

# =============================================================================
# TIER 3: SPECIALIZED TOOLS (Download Last)
# =============================================================================

cat > repo_lists/tier3_specialized/databases_messaging.txt << 'EOF'
# Database & Messaging Systems
https://github.com/postgres/postgres
https://github.com/redis/redis
https://github.com/mongodb/mongo
https://github.com/elastic/elasticsearch
https://github.com/apache/kafka
https://github.com/rabbitmq/rabbitmq-server
https://github.com/nats-io/nats-server
https://github.com/cockroachdb/cockroach
https://github.com/vitessio/vitess
EOF

cat > repo_lists/tier3_specialized/serverless_edge.txt << 'EOF'
# Serverless & Edge Computing
https://github.com/knative/serving
https://github.com/knative/eventing
https://github.com/openfaas/faas
https://github.com/kubeless/kubeless
https://github.com/fission/fission
https://github.com/virtual-kubelet/virtual-kubelet
https://github.com/kubernetes-sigs/cluster-api
EOF

cat > repo_lists/tier3_specialized/ml_ai_tools.txt << 'EOF'
# ML/AI Infrastructure
https://github.com/kubeflow/kubeflow
https://github.com/seldon-io/seldon-core
https://github.com/kserve/kserve
https://github.com/ray-project/ray
https://github.com/mlflow/mlflow
https://github.com/jupyter/docker-stacks
EOF

cat > repo_lists/tier3_specialized/gaming_media.txt << 'EOF'
# Gaming & Media Processing
https://github.com/googleforgames/agones
https://github.com/FFmpeg/FFmpeg
https://github.com/kubernetes-sigs/controller-runtime
EOF

cat > repo_lists/tier3_specialized/backup_disaster_recovery.txt << 'EOF'
# Backup & Disaster Recovery
https://github.com/vmware-tanzu/velero
https://github.com/stashed/stash
https://github.com/kubernetes-csi/external-snapshotter
https://github.com/restic/restic
EOF

cat > repo_lists/tier3_specialized/compliance_governance.txt << 'EOF'
# Compliance & Governance
https://github.com/falcosecurity/falcosidekick
https://github.com/aquasecurity/kube-bench
https://github.com/aquasecurity/kube-hunter
https://github.com/armosec/kubescape
https://github.com/kubernetes/policy-management
EOF

# =============================================================================
# UTILITY SCRIPTS
# =============================================================================

cat > download_tier1.sh << 'EOF'
#!/bin/bash
echo "=== DOWNLOADING TIER 1: ESSENTIAL INFRASTRUCTURE ==="
python3 downloader.py repo_lists/tier1_essential/containers_runtime.txt --framework containers_runtime
python3 downloader.py repo_lists/tier1_essential/kubernetes_core.txt --framework kubernetes_core
python3 downloader.py repo_lists/tier1_essential/networking_core.txt --framework networking_core
python3 downloader.py repo_lists/tier1_essential/web_essentials.txt --framework web_essentials
python3 downloader.py repo_lists/tier1_essential/monitoring_basics.txt --framework monitoring_basics
python3 downloader.py repo_lists/tier1_essential/security_core.txt --framework security_core
echo "=== TIER 1 COMPLETE ==="
EOF

cat > download_tier2.sh << 'EOF'
#!/bin/bash
echo "=== DOWNLOADING TIER 2: ADVANCED TOOLS ==="
python3 downloader.py repo_lists/tier2_advanced/orchestration_advanced.txt --framework orchestration_advanced
python3 downloader.py repo_lists/tier2_advanced/service_mesh.txt --framework service_mesh
python3 downloader.py repo_lists/tier2_advanced/storage_networking.txt --framework storage_networking
python3 downloader.py repo_lists/tier2_advanced/ci_cd_tools.txt --framework ci_cd_tools
python3 downloader.py repo_lists/tier2_advanced/observability_advanced.txt --framework observability_advanced
python3 downloader.py repo_lists/tier2_advanced/development_tools.txt --framework development_tools
echo "=== TIER 2 COMPLETE ==="
EOF

cat > download_tier3.sh << 'EOF'
#!/bin/bash
echo "=== DOWNLOADING TIER 3: SPECIALIZED TOOLS ==="
python3 downloader.py repo_lists/tier3_specialized/databases_messaging.txt --framework databases_messaging
python3 downloader.py repo_lists/tier3_specialized/serverless_edge.txt --framework serverless_edge
python3 downloader.py repo_lists/tier3_specialized/ml_ai_tools.txt --framework ml_ai_tools
python3 downloader.py repo_lists/tier3_specialized/gaming_media.txt --framework gaming_media
python3 downloader.py repo_lists/tier3_specialized/backup_disaster_recovery.txt --framework backup_disaster_recovery
python3 downloader.py repo_lists/tier3_specialized/compliance_governance.txt --framework compliance_governance
echo "=== TIER 3 COMPLETE ==="
EOF

cat > download_all.sh << 'EOF'
#!/bin/bash
echo "=== DOWNLOADING ALL TIERS ==="
echo "This will download 100+ repositories. Estimated time: 2-4 hours"
echo "Press Ctrl+C to cancel, or wait 10 seconds to continue..."
sleep 10

./download_tier1.sh
echo "Tier 1 complete. Taking 30 second break..."
sleep 30

./download_tier2.sh
echo "Tier 2 complete. Taking 30 second break..."
sleep 30

./download_tier3.sh
echo "=== ALL DOWNLOADS COMPLETE ==="
EOF

chmod +x download_tier1.sh download_tier2.sh download_tier3.sh download_all.sh

# =============================================================================
# DOCUMENTATION
# =============================================================================

cat > README.md << 'EOF'
# Critical Infrastructure Repository Sets

This collection provides prioritized sets of essential infrastructure repositories for offline development and disaster recovery scenarios.

## Quick Start

```bash
# Download only the most critical components (recommended first)
./download_tier1.sh

# Download advanced tools
./download_tier2.sh

# Download specialized tools
./download_tier3.sh

# Or download everything (2-4 hours)
./download_all.sh
```

## Tier Breakdown

### Tier 1: Essential (Download First - ~45 repos)
- **Container Runtime**: Docker, containerd, Podman, runc
- **Kubernetes Core**: API server, kubelet, kubectl, etcd
- **Networking Core**: CNI, Flannel, Calico, Ingress
- **Web Essentials**: Nginx, Apache, Traefik, Caddy
- **Monitoring Basics**: Prometheus, Grafana, Alertmanager
- **Security Core**: cert-manager, OPA, Trivy, Falco

**Why First**: These form the foundation layer. Without these, nothing else works.

### Tier 2: Advanced (Download Second - ~50 repos)
- **Advanced Orchestration**: Helm, ArgoCD, Flux, Kustomize
- **Service Mesh**: Istio, Linkerd, Consul Connect
- **Storage & Advanced Networking**: Rook, CSI drivers, Cilium
- **CI/CD Tools**: Tekton, Jenkins X, Kaniko, Skaffold
- **Advanced Observability**: Jaeger, OpenTelemetry, ELK stack
- **Development Tools**: Minikube, Tilt, Telepresence, k9s

**Why Second**: These build on Tier 1 to provide production-grade capabilities.

### Tier 3: Specialized (Download Last - ~30 repos)
- **Databases & Messaging**: PostgreSQL, Redis, Kafka, RabbitMQ
- **Serverless & Edge**: Knative, OpenFaaS, Virtual Kubelet
- **ML/AI Tools**: Kubeflow, Seldon, KServe
- **Gaming & Media**: Agones, FFmpeg
- **Backup & DR**: Velero, Restic
- **Compliance**: Kube-bench, Kubescape

**Why Last**: Domain-specific tools needed for particular use cases.

## Storage Requirements

- **Tier 1**: ~15-20 GB
- **Tier 2**: ~25-35 GB  
- **Tier 3**: ~15-25 GB
- **Total**: ~55-80 GB

## Network-First Approach

This prioritization assumes you have limited time/bandwidth:

1. **Download Tier 1** - Gets you a working container + K8s environment
2. **Download Tier 2** - Adds production capabilities and advanced tooling
3. **Download Tier 3** - Adds specialized functionality as needed

## Customization

Edit the `.txt` files in `repo_lists/` to add/remove repositories based on your specific needs.

Each category can be downloaded independently:
```bash
python3 downloader.py repo_lists/tier1_essential/containers_runtime.txt --framework containers
```

## Offline Usage

After downloading, these repositories provide:
- Full source code for building from scratch
- Documentation and examples
- Configuration templates
- Deployment manifests
- Complete development environments

Perfect for air-gapped environments, disaster recovery, or deep learning scenarios.
EOF

echo "Repository sets created successfully!"
echo "File structure:"
find repo_lists -name "*.txt" | sort
echo ""
echo "Usage scripts:"
ls -la download_*.sh
echo ""
echo "To get started:"
echo "1. Run: ./download_tier1.sh (essential components)"
echo "2. Run: ./download_tier2.sh (advanced tools)" 
echo "3. Run: ./download_tier3.sh (specialized tools)"
echo ""
echo "Or run: ./download_all.sh (everything - takes 2-4 hours)"

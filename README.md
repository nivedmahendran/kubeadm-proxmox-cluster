# Kubernetes Homelab Cluster (kubeadm on Proxmox)

A 3-node Kubernetes cluster built **from scratch** on my Proxmox homelab using
`kubeadm` — 1 control plane + 2 workers. Built to learn Kubernetes deeply by
doing, and to exercise production-style decisions (firmware, DNS, storage,
networking) rather than following a tutorial end-to-end.

> **Why kubeadm?** I deliberately chose `kubeadm` over a turnkey distribution
> (Talos, k3s, RKE2). kubeadm is the upstream bootstrap tool and exposes the
> actual control-plane lifecycle (etcd, apiserver, kubelet, kubeconfig),
> which is the best way to internalize how Kubernetes is assembled.

## Topology

| Node | Role | IP | vCPU | RAM |
|------|------|----|------|-----|
| `k8s-cp1` | control-plane | 10.10.10.200 | 2 | 4 GB |
| `k8s-worker1` | worker | 10.10.10.203 | 2 | 3 GB |
| `k8s-worker2` | worker | 10.10.10.204 | 2 | 3 GB |

- **Hypervisor:** Proxmox VE (node `pve`, 10.10.10.0/22 LAN)
- **OS:** Ubuntu 24.04 (Noble) cloud image
- **Kubernetes:** v1.36.6 (kubeadm / kubelet / kubectl)
- **Container runtime:** containerd (systemd cgroup driver)
- **CNI:** Calico (`--pod-network-cidr=192.168.0.0/16`)
- **Ingress:** ingress-nginx (Helm)
- **Storage:** local-path-provisioner (dynamic PVs)

## Key decisions & why

### 1. UEFI/OVMF + q35 + modern CPU (the important one)
The **first** template I built used SeaBIOS/i440fx with `vga=serial0`. Every
clone **froze after the kernel loaded** — no disk writes, no network, no
console output. The guest loaded the kernel (~47 MB read) then went silent.

- **Root cause:** the fragile SeaBIOS + serial-console combination with the
  Ubuntu cloud image.
- **Fix:** rebuilt the base template as **UEFI/OVMF, q35 machine,
  x86-64-v2-AES CPU, VGA std**. Clones then booted cleanly every time.

This was my single biggest "aha": the *platform/firmware* can break an
otherwise-correct cluster design.

### 2. DNS was the silent killer
Workers kept stalling in `apt-get update`. The cause was **Tailscale
MagicDNS** injecting `127.0.0.53` (systemd-resolved stub) as the resolver,
which didn't forward external DNS reliably.

- **Fix:** wrote a static `/etc/resolv.conf` pointing at `1.1.1.1` and
  `10.10.10.1`, and disabled systemd-resolved.
- **Baked into the template** so future clones never repeat it.

### 3. Guest agent shipped in the image
The Proxmox shutdown image does **not** include `qemu-guest-agent`, so PVE
couldn't see runtime IPs or talk to guests. I installed and enabled it, and
baked it into the base template.

### 4. Disk headroom
Cloud images default to a tiny root (~2.5 GB). The control plane filled it
during `apt` installs (`No space left on device`). I grew each VM's LVM disk
`+8G` and the filesystem inside (`growpart` + `resize2fs`).

### 5. Calico pod CIDR must match
I initialized with `--pod-network-cidr=192.168.0.0/16` so it matches Calico's
default. Mismatching this is a classic source of `NotReady` nodes.

## What I'd change at 10× traffic / scale

- **Single control plane** is fine for a lab but is a SPOF — I'd add HA
  control-plane replicas + a load balancer in front of the API server.
- **local-path storage** is single-node and non-replicated; for real stateful
  workloads I'd move to a distributed CSI (e.g. Rook/Ceph) or a managed
  provider.
- **MetalLB** instead of pinned `externalIPs` for the LoadBalancer service on
  bare metal.
- **RBAC + namespace isolation** hardening before adding workloads/teammates.
- **Backups**: etcd snapshot policy + IaC for the cluster itself.

## Mistakes I hit (and the fix) — the honest log

| Mistake | Symptom | Fix |
|---------|---------|-----|
| SeaBIOS + `vga=serial0` template | clones froze after kernel load | UEFI/OVMF/q35 rebuild |
| Tailscale MagicDNS resolver | `apt` hung on workers | static `resolv.conf` |
| No guest agent in image | PVE couldn't see runtime IP | install + enable agent |
| Tiny root disk | `No space left on device` | grow VM disk + filesystem |
| No kubeconfig for `ubuntu` | `kubectl` → `localhost:8080` refused | copy `admin.conf` to `~/.kube/config` |
| `kubectl patch --type=merge` on an array | wiped existing entries | use `strategic` (default) |

## How this repo is laid out

```
terraform/          # PVE VM definitions (kubeadm nodes) via the proxmox provider
  main.tf          # node topology (vmid, IP, cores, mem, disk)
  providers.tf
  variables.tf     # template_vmid, subnet, etc.
  outputs.tf
```

## Prerequisites (for a rebuild)

1. Proxmox node with an Ubuntu 24.04 cloud-image template
   (UEFI/OVMF/q35 + guest agent + fixed DNS baked in).
2. `terraform`, `kubeadm`, `kubelet`, `kubectl` on the hosts.
3. Free IPs in the LAN.

## Quickstart (control plane)

```bash
# bootstrap (Calico pod CIDR match required)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# user kubeconfig
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# CNI
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

# Ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

## Verification

```bash
kubectl get nodes -o wide      # expect 3 Ready
kubectl get pods -A            # all Running (Calico, CoreDNS, ingress)
kubectl get storageclass        # local-path provisioner
```

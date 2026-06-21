# Host preparation

Before installing k3s, `server` and `agent` run host preparation automatically. Run it alone with:

```bash
sudo ./install.sh prepare
```

## What it does

| Step | Action |
|------|--------|
| Swap | `swapoff -a` and disable swap in `/etc/fstab` |
| Kernel modules | Load `overlay`, `br_netfilter`; persist in `/etc/modules-load.d/local-k8s.conf` |
| Sysctl | Enable IP forwarding and bridge netfilter in `/etc/sysctl.d/99-local-k8s.conf` |
| Packages | Install `iptables`, `conntrack`, `socat`, `kmod`, `iproute2`, and related tools via apt |
| Firewall | Open k3s ports in UFW when active (6443, 8472, 10250, 2379–2380 on servers) |
| Checks | Verify cgroups, hostname, and available memory |

Skip automatic preparation:

```bash
PREPARE_HOST=false
```

Additional runtime dependencies are installed by the official k3s installer when needed.

## Prerequisites

- Debian, Ubuntu, or another Debian-based distribution
- `curl`, `git`, `bash`, `sudo`
- Root or passwordless sudo
- Control plane reachable on TCP **6443** from worker nodes
- Unique hostname per node (recommended)

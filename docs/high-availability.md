# High availability

For a multi-server control plane with embedded etcd:

1. On the **first** server: set `K3S_CLUSTER_INIT=true` in `config/config.env`, then run `sudo ./install.sh server`.
2. On **additional** servers: set `K3S_URL` and `K3S_TOKEN`, then run `sudo ./install.sh server`.
3. Join workers with `sudo ./install.sh agent` as usual.

See the [k3s HA documentation](https://docs.k3s.io/datastore/ha-embedded) for details.


```
```
                            ┌────────────────────────────────────────────┐
   Lab VLAN 70 (Talos)      │  Cilium Egress Gateway ──▶ UDM Pro ──▶ WAN  │
                            └───────────────▲────────────────────────────┘
                                            │ obfuscated (WATM)
  ┌──────────────┐  SOCKS5   ┌──────────────┴───────────────┐    fetch/rotate   ┌──────────────────┐
  │ research pod │─────────▶ │ water-proxy  (Deployment)     │◀─── /watm/... ────│ watm-server      │
  │ (browse/AI/  │           │  :1080  WATER Dialer + WATM   │                   │ (SpinKube SpinApp)│
  │  scrape)     │           │  ClusterIP svc `water-egress` │                   │  Lab VLAN 70      │
  └──────────────┘           └───────────────────────────────┘                   └──────────────────┘
        set HTTP(S)_PROXY / SOCKS to water-egress:1080                     Spin exposed via Gateway API
                                            │
                                            ▼  (WATM-obfuscated TCP :443)
                                   public VPS  →  water-bridge + microsocks  →  Internet
```

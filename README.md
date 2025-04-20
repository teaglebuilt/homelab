<div align="center">
  <h1>Homelab</h1>
  <img src="https://github.com/teaglebuilt/homelab/actions/workflows/release.yaml/badge.svg">
  <img src="https://badgen.net/badge/UniFi/USW Agg,UAP,USW Max Pro,UDM Pro?list=|&icon=https://docs.golift.io/svg/ubiquiti_color.svg&color=0099ee">
</div>

<div align="center">
  <img src="https://github.com/teaglebuilt/homelab/blob/main/docs/static/img/homelabrack.png" style="width:250px;"/>
</div>

<div align="center">
  <img src="https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white" />
  <img src="https://img.shields.io/badge/NVIDIA-GTX4070-76B900?style=for-the-badge&logo=nvidia&logoColor=white" />
  <img src="https://img.shields.io/badge/Intel%20Core_i9_10th-0071C5?style=for-the-badge&logo=intel&logoColor=white" />
  <img src="https://img.shields.io/badge/Argo%20CD-1e0b3e?style=for-the-badge&logo=argo&logoColor=#d16044" />
  <img src="https://img.shields.io/badge/Raspberry%20Pi-A22846?style=for-the-badge&logo=Raspberry%20Pi&logoColor=white" />
  <img src="https://img.shields.io/badge/Wireshark-1679A7?style=for-the-badge&logo=Wireshark&logoColor=white" />
  <img src="https://img.shields.io/badge/Portainer-13BEF9?style=for-the-badge&logo=portainer&logoColor=white" />
</div>

While inspired by the [K8s@Home](https://k8s-at-home.com/) community, this repository does not follow the standard approach and does not only manage kubernetes related workloads.
You can find more information by visiting the [Docs](https://teaglebuilt.github.io/homelab/) which is in progress and under construction 🚧.

### Communities

<img src="https://discordapp.com/api/guilds/673534664354430999/widget.png?style=banner2">
<img src="https://discordapp.com/api/guilds/969093165669830727/widget.png?style=banner2">


helm install nfs-storage nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace kube-system \
  --set nfs.server=192.168.2.10 \
  --set nfs.path=/var/nfs/shared/ai_storage \
  --set storageClass.name=nfs-ephemeral \
  --set storageClass.defaultClass=false

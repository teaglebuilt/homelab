
variable "proxmox_node" {
  description = <<-EOT
    Cluster node **name exactly as shown in the Proxmox UI** under Datacenter (not merely your LAN DNS name unless they match).

    Wrong node names often surface as bogus **HTTP 596 / SSL certificate verify failed** because pveproxy looks for certs under `/etc/pve/nodes/<name>/`.
    The OS hostname (`hostname -s`), `/etc/pve/datacenter.cfg`, and this value must be consistent — see https://github.com/bpg/terraform-provider-proxmox/issues/1731
  EOT
  type        = string
}

variable "proxmox_endpoint" {
  description = <<-EOT
    Explicit Proxmox API URL (`https://host:8006` or trailing slash acceptable). Leave empty (default) to use `PROXMOX_VE_ENDPOINT` instead.
    Hostname here should ideally match Proxmox's certificate CN/SAN to avoid mismatches upstream.
  EOT
  type        = string
  default     = ""
}

variable "proxmox_ssh_private_key" {
  description = "SSH private **PEM** used for privileged operations against the hypervisor nodes, either inline (`-----BEGIN…`) **or** a path passed through to `file()`."
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "Linux account on each Proxmox node when the provider shells in over SSH."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_node_address_source" {
  description = "`api` (default) resolves node IPs via Proxmox API; switch to `dns` if reachable addresses differ."
  type        = string
  default     = "api"
}

variable "proxmox_tmp_dir" {
  description = "Writable temp dir on hypervisor nodes (`/var/tmp` is the upstream-recommended fallback)."
  type        = string
  default     = "/var/tmp"
}

variable "proxmox_min_tls" {
  description = "Minimum TLS for the Proxmox API client (1.0–1.3). Matches provider default 1.3; set 1.2 only when debugging older TLS stacks."
  type        = string
  default     = "1.3"
}

variable "proxmox_api_insecure_tls" {
  description = <<-EOT
    When true OpenTufu skips verification of **the Proxmox API** certificate (`insecure`).
    Important: repeating **HTTP 596 + SSL routines** often still originates **inside** Proxmox (hostname/node-folder mismatch); `insecure` cannot fix validation errors from pveproxy internals.
    Set `PROXMOX_VE_INSECURE=true` in shells/Task if another tool exports `false`.
  EOT
  type        = bool
  default     = true
}

variable "vm_name" {
  description = "Guest name in Proxmox."
  type        = string
  default     = "nixos"
}

variable "vm_id" {
  description = "Explicit Proxmox VM ID."
  type        = number
}

variable "machine_type" {
  description = "QEMU machine type (\"q35\" is typical on current Proxmox)."
  type        = string
  default     = "q35"
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "cpu_type" {
  description = "QEMU CPU model passed through to Proxmox (\"host\" is common on homelab metal)."
  type        = string
  default     = "host"
}

variable "memory_mib" {
  type    = number
  default = 8192
}

variable "disk_size_gb" {
  type    = number
  default = 64
}

variable "vm_datastore_id" {
  description = "Datastore for the root disk."
  type        = string
  default     = "local-lvm"
}

variable "iso_datastore_id" {
  description = "Datastore where ISO images are stored (often \"local\" rather than \"local-lvm\")."
  type        = string
  default     = "local"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "start_on_boot" {
  description = "Set Proxmox \"Start at boot\" for this guest."
  type        = bool
  default     = true
}

variable "started" {
  description = "Power state after apply."
  type        = bool
  default     = true
}

variable "boot_installer_first" {
  description = "If true, ide2 (CD-ROM) precedes scsi0 until you change ordering in Proxmox or adjust lifecycle."
  type        = bool
  default     = true
}

variable "nixos_iso_url" {
  description = "NixOS minimal installer ISO URL (channel \"latest\" URL tracks the selected release branch)."
  type        = string
  default     = "https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso"
}

variable "nixos_iso_filename" {
  description = "Filename on the Proxmox ISO datastore."
  type        = string
  default     = "nixos-minimal-x86_64.iso"
}

variable "nixos_download_verify_tls" {
  description = "When true, Proxmox verifies TLS for nixos_iso_url. Set false if apply fails with HTTP 596 / certificate verify failed (stale CA bundle on the node is common)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra Proxmox tags in addition to nixos and managed."
  type        = list(string)
  default     = []
}

variable "reuse_existing_iso_download" {
  description = "If true, skips proxmox_download_file and uses existing_iso_file_id for the CD-ROM."
  type        = bool
  default     = false
}

variable "existing_iso_file_id" {
  description = "Used when reuse_existing_iso_download is true. Example format: \"local:iso/nixos-minimal.iso\"."
  type        = string
  default     = ""
}

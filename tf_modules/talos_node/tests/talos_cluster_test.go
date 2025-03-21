package tests

import (
    "os"
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTalosImage(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../../tf_modules/talos_cluster",
        Vars: map[string]interface{}{
            "k8s_api_server_ip":       os.Getenv("MASTER_NODE_IP"),
            "network_gateway":         os.Getenv("PROXMOX_NETWORK_GATEWAY"),
            "master_node_ip":          os.Getenv("MASTER_NODE_IP"),
            "worker_one_node_ip":      os.Getenv("WORKER_ONE_NODE_IP"),
            "worker_two_node_ip":      os.Getenv("WORKER_TWO_NODE_IP"),
            "proxmox_ssh_private_key": os.Getenv("PROXMOX_NODE_TWO_PRIVATE_KEY"),
        },
    }
    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)
    talosSchematic := terraform.Output(t, terraformOptions, "talos_image_factory_schematic")

    assert.NotContains(t, talosSchematic, "siderolabs/nvidia-container-toolkit-production", "❌ NVIDIA extension found in control plane!")
    assert.NotContains(t, talosSchematic, "siderolabs/nonfree-kmod-nvidia-production", "❌ NVIDIA kernel module found in control plane!")
}

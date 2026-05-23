{ config, pkgs, ... }: {
  # Enable X11 windowing system
  services.xserver.enable = true;

  # Enable Desktop Environment (Choose one)
  # Option A: GNOME
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Option B: XFCE (Lighter)
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.desktopManager.xfce.enable = true;

  # Enable sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable qemu-guest agent for Proxmox
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # Better clipboard sharing
}

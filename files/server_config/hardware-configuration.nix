{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub = {
    configurationLimit = 2;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/78FD-AD17"; fsType = "vfat"; };
  fileSystems."/" = { device = "/dev/sda1"; fsType = "btrfs"; options = [ "compress=zstd:15" ]; };
  networking.interfaces.enp0s3.useDHCP = true;
}

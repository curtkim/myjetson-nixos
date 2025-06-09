{ config, pkgs, lib, ... }:

{
  networking.hostName = "xavier";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.kernelModules = [ "iwlwifi" ];

  # AGX Xavier configuration
  hardware.nvidia-jetpack = {
    enable = true;
    som = "xavier-agx";
    carrierBoard = "devkit";
  };

  # # Enable CUDA
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.opengl = {
  #   enable = true;
  #   driSupport = true;
  # };

  # Ollama with CUDA support
  # services.ollama = {
  #   enable = true;
  #   acceleration = "cuda";
  #   environmentVariables = {
  #     OLLAMA_NUM_GPU = "1";
  #     CUDA_VISIBLE_DEVICES = "0";
  #   };
  # };

  environment.systemPackages = with pkgs; [
    git
    tmux
    neovim
    #claude-code
    #nvidia-jetpack.cudaPackages.cudatoolkit
    cudaPackages.cudatoolkit
    python3Packages.torch
  ];

  # Basic system configuration
  system.stateVersion = "24.11";
  
  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.curt = {
    isNormalUser = true;
    description = "curt";
    extraGroups = [ "networkmanager" "wheel" "input" "video" "libvirt"];
  };

  # Allow unfree packages (needed for NVIDIA drivers)
  nixpkgs.config.allowUnfree = true;
}

{
  description = "NixOS configuration for Jetson AGX Xavier";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    jetpack-nixos = {
      url = "github:anduril/jetpack-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, jetpack-nixos, disko, ... }: 
    let
      system = "aarch64-linux";
      # CUDA configuration for Xavier AGX (Compute Capability 7.2)
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = [ "7.2" ];
        };
        overlays = [
          jetpack-nixos.overlays.default
          # Make jetpack CUDA packages the default
          (final: prev: {
            inherit (final.nvidia-jetpack) cudaPackages;
          })
        ];
      };
    in
    {
    nixosConfigurations.xavier = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit pkgs;};
      modules = [
        # Import jetpack-nixos module
        jetpack-nixos.nixosModules.default
        
        # Import disko configuration 
        disko.nixosModules.disko
        ./disko-config.nix
        
        # Main configuration
        ({ config, pkgs, lib, ... }: {
          # System information
          networking.hostName = "xavier";
          
          # Enable flakes
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          
          # Hardware configuration for Jetson AGX Xavier
          hardware.nvidia-jetpack = {
            enable = true;
            som = "xavier-agx";
            carrierBoard = "devkit";
            
            # Enable CUDA support for samples
            configureCuda = true;
            
            # Disable modesetting since we don't need X11
            modesetting.enable = false;
          };
          
          # Boot configuration
          boot = {
            # Support for console output on Xavier AGX
            kernelParams = [ 
              "fbcon=map:1"  # For Xavier AGX console output
              "console=ttyTCU0,115200"  # Serial console
              "console=tty0"  # Display console
            ];
            
            # Additional kernel modules
            kernelModules = [ "nvme" ];
            
            # Bootloader configuration
            loader = {
              systemd-boot.enable = true;
              efi.canTouchEfiVariables = false;  # Xavier AGX limitation
            };
          };
          
          # Network configuration
          networking = {
            useDHCP = lib.mkDefault true;
            wireless.enable = true;  # Enable WiFi
          };
          
          # System packages
          environment.systemPackages = with pkgs; [
            # Basic system tools
            wget
            curl
            git
            vim
            htop
            tree
            file
            
            # CUDA development tools and samples
            cudaPackages.cudatoolkit
            cudaPackages.cuda_nvcc
            cudaPackages.cuda_cudart
            
            # Jetson-specific tools
              #jetpack-nixos.packages.${pkgs.system}.python-jetson or null
            
            # Network tools
            wpa_supplicant
            iw
          ];
          
          # Services
          services = {
            # Enable SSH
            openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };
          };

          # Additional user (optional)
          users.users.curt = {
            isNormalUser = true;
            initialPassword = "nixos";
            extraGroups = [ "wheel" "video" "dialout" ];
          };
          
          # NixOS version
          system.stateVersion = "24.11";
          
          # Hardware-specific optimizations
          
          # Power management and performance
          powerManagement = {
            enable = true;
            cpuFreqGovernor = "performance";
          };
          
          # Custom scripts for Jetson management
          environment.etc = {
            # Custom nvpmodel configuration
            "nvpmodel-xavier.conf" = {
              text = ''
                # Custom nvpmodel configuration for Xavier AGX
                # Mode 0: MAXN (default)
                # Mode 1: Mode 10W
                # Mode 2: Mode 15W
                # Mode 3: Mode 30W ALL
                # Mode 4: Mode 30W 6-core
                # Mode 5: Mode 30W 4-core
                # Mode 6: Mode 30W 2-core
              '';
              mode = "0644";
            };
          };
          
          # Custom systemd services
          systemd.services = {
            # Jetson clocks service to maximize performance
            jetson-clocks = {
              description = "Jetson clocks performance mode";
              wantedBy = [ "multi-user.target" ];
              after = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${pkgs.bash}/bin/bash -c 'echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor || true'";
              };
            };
            
            # Fan control service
            jetson-fan-control = {
              description = "Jetson fan control";
              wantedBy = [ "multi-user.target" ];
              after = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${pkgs.bash}/bin/bash -c 'echo 255 > /sys/devices/pwm-fan/target_pwm || true'";
              };
            };
          };
          
          # Shell aliases for Jetson management
          environment.shellAliases = {
            # Power mode management
            "power-maxn" = "echo 0 | sudo tee /etc/nvpmodel.conf";
            "power-10w" = "echo 1 | sudo tee /etc/nvpmodel.conf";
            "power-15w" = "echo 2 | sudo tee /etc/nvpmodel.conf";
            
            # System monitoring
            "jetson-stats" = "watch -n 1 'cat /sys/class/thermal/thermal_zone*/temp'";
          };
          
          # Environment variables
          environment.variables = {
            CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
            CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
          };
          
          # Disable unnecessary services for console-only setup
          services.xserver.enable = false;
          #services.getty.autologinUser = "nixos";
          
          # Enable container runtime for CUDA applications
          virtualisation = {
            podman = {
              enable = true;
              enableNvidia = true;
            };
          };
        })
      ];
    };
  };
}

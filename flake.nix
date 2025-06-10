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
        inherit system;
        specialArgs = { inherit pkgs; };
        modules = [
          jetpack-nixos.nixosModules.default
          disko.nixosModules.disko
          ./disko-config.nix  # Your existing disko configuration
          {
            # Jetpack configuration
            hardware.nvidia-jetpack = {
              enable = true;
              som = "xavier-agx";
              carrierBoard = "devkit";
              # Enable CUDA configuration automatically
              configureCuda = true;
            };

            # System configuration
            system.stateVersion = "24.11";
            networking.hostName = "xavier";

            # Boot configuration
            boot = {
              # Console support for Xavier AGX
              kernelParams = [ "fbcon=map:1" ];
              loader = {
                systemd-boot.enable = true;
                efi.canTouchEfiVariables = false; # Xavier AGX limitation
              };
            };

            # Network configuration
            networking = {
              networkmanager.enable = true;
              wireless.enable = false; # Use NetworkManager for WiFi
            };

            # No X11/Wayland - console only
            services.xserver.enable = false;

            # Enable SSH for remote access
            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };

            # Python environment with PyTorch and CUDA support
            environment.systemPackages = with pkgs; [
              # Python with CUDA-enabled PyTorch
              (python3.withPackages (ps: with ps; [
                pytorch-bin  # CUDA-enabled PyTorch from jetpack
                torchvision
                torchaudio
                numpy
                matplotlib
                jupyter
                ipython
                pandas
                scikit-learn
                opencv4
              ]))

              # Monitoring and system tools
              nvtop           # GPU monitoring
              htop
              btop
              iotop
              
              # Jetson-specific tools (provided by jetpack-nixos)
              jetson-gpio     # GPIO control
              
              # System utilities
              vim
              git
              curl
              wget
              tmux
              screen
              
              # Network tools
              networkmanager
              wpa_supplicant
            ];

            # Enable CUDA runtime
            hardware.opengl = {
              enable = true;
              driSupport = true;
            };

            # Container support with NVIDIA runtime
            virtualisation = {
              podman = {
                enable = true;
                enableNvidia = true;
              };
            };

            # Jetson performance and power management services
            systemd.services = {
              # Enable jetson_clocks for maximum performance
              jetson-clocks = {
                description = "Jetson Clocks Performance Mode";
                after = [ "multi-user.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${pkgs.nvidia-jetpack.l4t-core}/bin/jetson_clocks";
                  ExecStop = "${pkgs.nvidia-jetpack.l4t-core}/bin/jetson_clocks --restore";
                };
              };

              # NV Power Model service
              nvpmodel = {
                description = "NVIDIA Power Model Service";
                after = [ "multi-user.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  # Set to maximum performance mode (mode 0)
                  ExecStart = "${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -m 0";
                };
              };

              # Fan control service
              nvfancontrol = {
                description = "NVIDIA Fan Control Service";
                after = [ "multi-user.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${pkgs.nvidia-jetpack.l4t-core}/bin/nvfancontrol";
                  Restart = "always";
                  RestartSec = 5;
                };
              };
            };

            # Create convenience scripts for power management
            environment.systemPackages = with pkgs; [
              (writeShellScriptBin "jetson-performance" ''
                #!/bin/bash
                echo "Setting Jetson to maximum performance mode..."
                
                # Set power model to maximum
                sudo ${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -m 0
                
                # Enable all CPU cores
                for i in {4..7}; do
                  echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null
                done
                
                # Set clocks to maximum
                sudo ${pkgs.nvidia-jetpack.l4t-core}/bin/jetson_clocks
                
                # Set fan to maximum
                sudo ${pkgs.nvidia-jetpack.l4t-core}/bin/jetson_clocks --fan
                
                echo "Performance mode enabled!"
                echo "Current power mode:"
                ${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -q
              '')
              
              (writeShellScriptBin "jetson-status" ''
                #!/bin/bash
                echo "=== Jetson AGX Xavier Status ==="
                echo
                echo "Power Model:"
                ${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -q
                echo
                echo "CPU Status:"
                grep -H . /sys/devices/system/cpu/cpu*/online 2>/dev/null | head -8
                echo
                echo "Thermal Status:"
                ${pkgs.nvidia-jetpack.l4t-core}/bin/tegrastats --interval 1000 --logfile /dev/stdout | head -3
                echo
                echo "GPU Memory Usage:"
                nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits
              '')
              
              (writeShellScriptBin "jetson-power-save" ''
                #!/bin/bash
                echo "Setting Jetson to power save mode..."
                
                # Restore saved clocks (if any)
                sudo ${pkgs.nvidia-jetpack.l4t-core}/bin/jetson_clocks --restore
                
                # Set power model to power efficient mode
                sudo ${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -m 2
                
                echo "Power save mode enabled!"
                echo "Current power mode:"
                ${pkgs.nvidia-jetpack.l4t-core}/bin/nvpmodel -q
              '')
            ];

            # User configuration
            users.users.root.hashedPassword = null; # Set password manually
            users.users.xavier = {
              isNormalUser = true;
              extraGroups = [ "wheel" "networkmanager" "gpio" ];
              hashedPassword = null; # Set password manually
            };

            # Enable sudo without password for wheel group
            security.sudo.wheelNeedsPassword = false;

            # Additional kernel modules for CUDA
            boot.kernelModules = [ 
              "nvidia"
              "nvidia_modeset" 
              "nvidia_uvm"
              "nvidia_drm"
            ];

            # Firmware and drivers
            hardware.firmware = with pkgs; [
              nvidia-jetpack.l4t-firmware
            ];

            # Environment variables for CUDA
            environment.variables = {
              CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
              CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
              CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
              EXTRA_LDFLAGS = "-L${pkgs.cudaPackages.cudatoolkit}/lib";
              EXTRA_CCFLAGS = "-I${pkgs.cudaPackages.cudatoolkit}/include";
            };

            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;
          }
        ];
      };
    };
}

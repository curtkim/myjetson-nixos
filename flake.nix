{
  description = "NixOS configuration for NVIDIA Jetson";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    jetpack-nixos = {
      url = "github:anduril/jetpack-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, jetpack-nixos, disko, ... }@inputs: {
    nixosConfigurations = {
      xavier = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          jetpack-nixos.nixosModules.default
          ./configuration.nix
          ./disko-config.nix
          # Overlay to make nvidia-jetpack CUDA packages the default
          {
            nixpkgs.overlays = [
              (final: prev: {
                inherit (final.nvidia-jetpack) cudaPackages;
              })
            ];
          }
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}

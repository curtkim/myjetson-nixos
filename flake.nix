{
  description = "NixOS configuration for NVIDIA Jetson";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      myjetson = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          jetpack-nixos.nixosModules.default
          ./configuration.nix
          ./disko-config.nix
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}

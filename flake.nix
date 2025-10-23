{
  description = "Zig USB builder";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=25.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = {self, zig-overlay, flake-utils, nixpkgs}:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {inherit system;};
      zig = zig-overlay.packages.${system}."0.15.1";
      src = ./.;
      name = "zig-usb";
    in {
      packages.default = derivation {
        inherit system src name;
        builder = "${zig}/bin/zig";
        args = [ "build" ];
      };
    });
}

{
  description = "Zig USB builder";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=25.05";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = {self, zig-overlay, nixpkgs}:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      aarch-pkgs = (import nixpkgs { inherit system; }).pkgsCross.aarch64-multiplatform;
      zig = zig-overlay.packages.${system}."0.15.1";
      pname = "zig-usb";
      version = "0.1.0";
      src = ./.;
    in {
      packages.${system} = {
        default = pkgs.stdenvNoCC.mkDerivation {
          inherit pname src version;
          nativeBuildInputs = [ pkgs.pkg-config zig ];
          buildInputs = with pkgs; [ systemd ];
          buildPhase = ''
                export ZIG_LOCAL_CACHE_DIR=$(pwd)/.zig-cache
                export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
                export PATH=${pkgs.pkg-config}/bin:$PATH
                zig build 
            '';
          installPhase = ''
                mkdir -p $out/bin
                cp zig-out/bin/zig-usb-example $out/bin/zig-usb-example
            '';
        };
        aarch64-musl = pkgs.stdenvNoCC.mkDerivation {
          inherit pname src version;
          nativeBuildInputs = [ pkgs.pkg-config zig ];
          buildInputs = with aarch-pkgs; [ systemd ];
          buildPhase = ''
                export ZIG_LOCAL_CACHE_DIR=$(pwd)/.zig-cache
                export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
                export PATH=${pkgs.pkg-config}/bin:$PATH
                zig build -Dtarget=aarch64-linux-musl
            '';
          installPhase = ''
                mkdir -p $out/bin
                cp zig-out/bin/zig-usb-example $out/bin/zig-usb-example
            '';
        };
        aarch64-gnu= pkgs.stdenvNoCC.mkDerivation {
          inherit pname src version;
          nativeBuildInputs = [ pkgs.pkg-config zig ];
          buildInputs = with aarch-pkgs; [ systemd ];
          buildPhase = ''
                export ZIG_LOCAL_CACHE_DIR=$(pwd)/.zig-cache
                export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
                export PATH=${pkgs.pkg-config}/bin:$PATH
                zig build -Dtarget=aarch64-linux-gnu
            '';
          installPhase = ''
                mkdir -p $out/bin
                cp zig-out/bin/zig-usb-example $out/bin/zig-usb-example
            '';
        };
      };
      devShells.${system} = {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ pkg-config ] ++ zig;
          buildInputs = with pkgs; [ systemd ];
        };
        aarch64 = aarch-pkgs.mkShell {
          nativeBuildInputs = with aarch-pkgs.buildPackages; [
            pkg-config
          ] ++ zig;
          buildInputs = with aarch-pkgs; [
            systemd
          ];
        };
      };
    };
}

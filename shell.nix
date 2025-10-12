with import <nixpkgs> {};

mkShell {
  buildInputs = with pkgs; [
    systemd
  ];
  nativeBuildInputs = with pkgs; [
    pkg-config
  ];
}

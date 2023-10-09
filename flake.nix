{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let overlays = [ ];
            pkgs = import nixpkgs {
              inherit system overlays;
            };
        in
        with pkgs;
        {
          devShells.default = mkShell {
            buildInputs = [
              gnumake
              python312
              pandoc

              # typescript
              pkgs.nodePackages.typescript
              pkgs.nodePackages.typescript-language-server
              pkgs.nodePackages.prettier
            ];

            shellHook = ''
              export GH_USER="$USER"
            '';
          };
        }
      );
}
  

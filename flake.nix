{
  description = "Monitor the health and status of your power devices.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = "wattage";
        version = "1.5.0";
        src = ./.;

        meta = {
          description = "Monitor the health and status of your power devices.";
          homepage = "https://github.com/v81d/wattage";
          license = pkgs.lib.licenses.gpl3Plus;
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "wattage";
        };

        nativeBuildInputs = with pkgs; [
          meson
          ninja
          vala
          pkg-config
          gettext
          glib
          appstream
          desktop-file-utils
          gobject-introspection
          wrapGAppsHook4
          libxml2
        ];

        buildInputs = with pkgs; [
          gtk4
          libadwaita
          libgee
          glib
          blueprint-compiler
          adwaita-icon-theme
        ];

        preFixup = ''
          gappsWrapperArgs+=(
            --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"
          )
        '';
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [self.packages.${system}.default];
        nativeBuildInputs = with pkgs; [
          vala-language-server
          uncrustify
          libfoundry
        ];
      };
    });
}

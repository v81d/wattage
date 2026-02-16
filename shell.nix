{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    meson
    ninja
    vala
    gettext
    pkg-config
  ];

  buildInputs = with pkgs.buildPackages; [
    gtk4
    libadwaita
    libgee
    glib
    gobject-introspection
    appstream
    blueprint-compiler
  ];

  shellHook = ''
    echo -e "\033[1;32mWelcome to the Wattage development environment!\033[0m"
    echo -e "\033[1;34mAvailable aliases:\033[0m"

    build() {
      meson setup build --reconfigure
      meson compile -C build
    }
    export -f build

    install() {
      DESTDIR=staging meson install -C build
      glib-compile-schemas build/staging/usr/local/share/glib-2.0/schemas
    }
    export -f install

    run() {
      GSETTINGS_SCHEMA_DIR=build/staging/usr/local/share/glib-2.0/schemas ./build/staging/usr/local/bin/wattage
    }
    export -f run

    echo -e "  \033[1;33mbuild\033[0m     Build the project in the build/ directory"
    echo -e "  \033[1;33minstall\033[0m   Install the project to the build/staging/ directory"
    echo -e "  \033[1;33mrun\033[0m       Run the project binary at build/staging/usr/local/bin/wattage"

    echo
  '';
}

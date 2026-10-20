{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Use self as a dummy default for both source inputs.
    # Unless overridden, the packages use their own pinned sources.
    # Use --override-input to use your own sources.
    free42 = {
      follows = "";
      flake = false;
    };

    dm42pgm = {
      follows = "";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      free42,
      dm42pgm,
    }:
    let
      inherit (nixpkgs) lib;
    in
    {
      packages = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          packages = self.packages.${system};
          dmcpToolchain = pkgs.callPackage ./dmcp-toolchain { };

          callPackage = pkgs.newScope {
            inherit (dmcpToolchain) stdenv;
            inherit free42-lib;
          };

          free42-lib = callPackage ./free42 { };
          dm42 = callPackage ./dm42pgm { dmcp5 = false; };
          dm42n = callPackage ./dm42pgm { dmcp5 = true; };

          free42Src = if free42.outPath == self.outPath then free42-lib.src else free42;
          dm42pgmSrc = if dm42pgm.outPath == self.outPath then dm42.src else dm42pgm;

          overrideSrc =
            firmwarePackage: src:
            (firmwarePackage.override {
              free42-lib = free42-lib.overrideAttrs { src = free42Src; };
            }).overrideAttrs
              (previousAttrs: {
                inherit src;
                passthru = previousAttrs.passthru // {
                  original = firmwarePackage;
                };
              });
        in
        {
          dmcp-stdenv = dmcpToolchain.stdenv;
          dmcp-gcc = dmcpToolchain.gcc;
          flasher = pkgs.callPackage ./flasher { };

          default = pkgs.symlinkJoin {
            name = "DM42PGM";
            paths = [
              packages.dm42
              packages.dm42n
            ];
          };

          dm42 = overrideSrc dm42 dm42pgmSrc;
          dm42n = overrideSrc dm42n dm42pgmSrc;
        }
      );

      apps = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          packages = self.packages.${system};
          inherit (packages) flasher;
          firmwares = { inherit (packages) dm42 dm42n; };
        in
        {
          default = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "dm42-select-model" ''
                echo 'No default app. Specify #dm42 or #dm42n on the flake reference.' >&2
                exit 1
              ''
            );
          };
        }
        // lib.mapAttrs (model: firmware: {
          type = "app";
          program = toString (
            pkgs.writeShellScript "${model}-flash" ''
              exec ${lib.getExe flasher} \
                ${lib.escapeShellArg "${firmware}/${firmware.firmwareFileName}"} "$@"
            ''
          );
        }) firmwares
      );

      checks = lib.genAttrs lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          packages = self.packages.${system};
          checkHash =
            firmwarePackage:
            pkgs.testers.runCommand {
              name = "${firmwarePackage.name}-firmware-hash";
              hash = firmwarePackage.expectedFirmwareHash;
              script = ''cp ${firmwarePackage}/* "$out"'';
            };
        in
        with packages;
        {
          dm42 = checkHash dm42.original;
          dm42n = checkHash dm42n.original;
        }
      );
    };
}

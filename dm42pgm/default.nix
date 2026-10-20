{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,

  perlPackages,

  free42-lib,

  dmcp5 ? true,
}:

let
  src = fetchFromGitHub {
    owner = "swissmicros";
    repo = "DM42PGM";
    rev = "3270592f2be6f6d0316e1a0f482a1faecc14aaa9";
    hash = "sha256-mZvL6kVjaf2FN2s8MfSx9ZNFLD4MFe/r4/zNjifpZcA=";
  };

  # File hashes of the official firmware files for testers.runCommand.
  # Calculate the hash with, for example:
  # nix hash file DM42-3.26.pgm
  expectedFirmwareHash = {
    dm42 = "sha256-tOFwRCFp72JUQ6GwDsgnESvhaOxFzbFAiknxG1E27V0=";
    dm42n = "sha256-ggmDby5YHMGUsWu03ApvCt8Y+55tyUeUAzPCY97K3Fc=";
  };
in

stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;

  pname = "DM42";
  version = builtins.head (
    builtins.match ''.*#define[[:space:]]+DM42_VERSION[[:space:]]+"([^"]+)".*'' (
      builtins.readFile "${finalAttrs.src}/dm/main.h"
    )
  );

  inherit src;

  passthru = {
    inherit free42-lib;

    objects = callPackage ./objects.nix {
      inherit stdenv dmcp5;
      inherit (finalAttrs) src version makeFlags;
    };

    firmwareFileName = "${finalAttrs.pname}-${finalAttrs.version}.${if dmcp5 then "pg5" else "pgm"}";
    expectedFirmwareHash = with expectedFirmwareHash; if dmcp5 then dm42n else dm42;
  };

  nativeBuildInputs = [
    perlPackages.ArchiveZip
  ];

  makeFlags = [
    # The official DM42n firmware uses libfree42_bcd.a.
    "LIBS=lib/${if dmcp5 then "libfree42_bcd.a" else "libfree42_bcd_rel.a"} lib/gcc111libbid_hard.a"
    "DMCP5=${lib.optionalString dmcp5 "1"}"
    "TARGET=${finalAttrs.pname}-${finalAttrs.version}"
  ];

  # Nix gives sources and objects the same fixed timestamp in the store.
  # Preserve it when copying so Make does not see prerequisites as newer
  # than the cached objects and recompile them.
  unpackCmd = "cp -a ${finalAttrs.passthru.objects} source";

  preBuild = ''
    cp "${finalAttrs.passthru.free42-lib}"/{libfree42_bcd.a,libfree42_bcd_rel.a} lib
  '';

  installPhase = ''
    mkdir -p $out
    cp build/${finalAttrs.passthru.firmwareFileName} "$out/"
  '';
})

{
  lib,
  stdenv,
  fetchFromGitHub,
  buildPackages,

  model ? "dm42n",
}:

assert lib.assertOneOf "model" model [ "dm42" "dm42n" ];

let
  modelConfig = builtins.getAttr model {
    dm42 = {
      pname = "libfree42_bcd_rel";
      cxxFlags = "-Os -DDM42_OLDHW";
    };

    dm42n = {
      pname = "libfree42_bcd";
      cxxFlags = "-O2";
    };
  };
in

stdenv.mkDerivation (finalAttrs: {
  inherit (modelConfig) pname;
  version = lib.fileContents "${finalAttrs.src}/gtk/VERSION";

  src = fetchFromGitHub {
    owner = "swissmicros";
    repo = "free42";
    rev = "a7c705e476cfd6d83d7d8b90042999f386367813";
    hash = "sha256-mXMvnaGlDsT+MK0OJUqJ/SazelfCiB+ZbApvlzg1tf0=";
  };
  sourceRoot = "source/console";

  passthru = {
    intel-lib = buildPackages.callPackage ./intel-lib.nix { inherit (finalAttrs) src; };
    testsEnabled = builtins.pathExists "${finalAttrs.src}/tests/Makefile";
    libraryFileName = "${finalAttrs.pname}.a";
  };

  depsBuildBuild = [ buildPackages.gcc ];

  # console/armbuild builds libraries for both DM42n and DM42 on every run.
  # Set the same release, ARM and BCD options here to build only one model instead.
  # DM42n uses -O2; DM42 uses -Os and -DDM42_OLDHW.
  env = {
    RELEASE = "1";
    ARM_LIB = "1";
    BCD_MATH = "1";
    CXXFLAGS = modelConfig.cxxFlags;
  };

  preBuild = "make clean";
  enableParallelBuilding = true;
  buildFlags = [ "libfree42.a" ];

  # Cross compilation disables checkPhase. Run host tests after the ARM build
  # so test failures also fail the library and firmware builds.
  preInstallPhases = lib.optional finalAttrs.passthru.testsEnabled "nativeCheckPhase";
  nativeCheckPhase =
    let
      inherit (finalAttrs.passthru) intel-lib;
    in
    ''
      make -f ../tests/Makefile -j"$NIX_BUILD_CORES" BUILD_DIR="$TMPDIR/free42-tests" \
        CXX=${buildPackages.gcc}/bin/g++ CPPFLAGS= CXXFLAGS= LDFLAGS= \
        DECIMAL_LIBRARY=${intel-lib}/lib/gcc111libbid.a \
        DECIMAL_INCLUDE=${intel-lib}/include
    '';

  installPhase = ''
    mkdir -p "$out"
    cp libfree42.a "$out/${finalAttrs.passthru.libraryFileName}"
  '';
})

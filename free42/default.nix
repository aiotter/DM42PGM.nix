{
  lib,
  stdenv,
  fetchFromGitHub,
  buildPackages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "free42";
  version = lib.fileContents "${finalAttrs.src}/gtk/VERSION";

  src = fetchFromGitHub {
    owner = "swissmicros";
    repo = "free42";
    rev = "a7c705e476cfd6d83d7d8b90042999f386367813";
    hash = "sha256-mXMvnaGlDsT+MK0OJUqJ/SazelfCiB+ZbApvlzg1tf0=";
  };

  passthru = {
    intel-lib = buildPackages.callPackage ./intel-lib.nix { inherit (finalAttrs) src; };
    testsEnabled = builtins.pathExists "${finalAttrs.src}/tests/Makefile";
  };

  depsBuildBuild = [ buildPackages.gcc ];

  postPatch = ''
    patchShebangs --build console/armbuild
  '';

  # Keep the directory change in a subshell so nativeCheckPhase starts at the source root.
  buildPhase = "(cd console; ./armbuild)";

  # Cross compilation disables checkPhase. Build the tests for the build machine
  # and run them here so test failures also fail firmware builds.
  preInstallPhases = lib.optional finalAttrs.passthru.testsEnabled "nativeCheckPhase";
  nativeCheckPhase =
    let
      inherit (finalAttrs.passthru) intel-lib;
    in
    ''
      make -f tests/Makefile -j"$NIX_BUILD_CORES" BUILD_DIR="$TMPDIR/free42-tests" \
        CXX=${buildPackages.gcc}/bin/g++ CPPFLAGS= CXXFLAGS= LDFLAGS= \
        DECIMAL_LIBRARY=${intel-lib}/lib/gcc111libbid.a \
        DECIMAL_INCLUDE=${intel-lib}/include
    '';

  installPhase = ''
    mkdir -p $out
    mv console/libfree42_bcd.a console/libfree42_bcd_rel.a $out
  '';
})

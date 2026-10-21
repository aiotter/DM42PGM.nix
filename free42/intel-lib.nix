{
  lib,
  stdenv,
  which,
  cctools,
  src,
}:

stdenv.mkDerivation {
  pname = "free42-intel-lib";
  version = "20U1";

  # Include only library build inputs so Free42 code changes do not rebuild the library.
  src = lib.sources.sourceByRegex src [
    "inteldecimal"
    "inteldecimal/IntelRDFPMathLib20U1[.]tar[.]gz"
    "gtk"
    "gtk/build-intel-lib[.]sh"
    "gtk/intel-lib-(linux|unknown-32bit|unknown-64bit)[.]patch"
  ];
  sourceRoot = "source/gtk";

  dontConfigure = true;

  nativeBuildInputs = [ which ] ++ lib.optional stdenv.hostPlatform.isDarwin cctools;

  buildPhase = "MK=make sh build-intel-lib.sh";

  installPhase = ''
    mkdir -p "$out/lib" "$out/include"
    cp gcc111libbid.a "$out/lib/"
    cp IntelRDFPMathLib20U1/LIBRARY/src/*.h "$out/include/"
  '';
}

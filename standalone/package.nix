{ lib
, stdenv
, cmake
, qtbase
, qtdeclarative
, qtsvg
, wrapQtAppsHook
, bash
, jq
, git
, curl
, coreutils
, util-linux
, findutils
, gnugrep
, gnused
, gawk
, inotify-tools
, libnotify
, direnv
, version
, src
}:
stdenv.mkDerivation {
  pname = "nixdatifier";
  inherit version src;

  sourceRoot = "source/standalone";

  nativeBuildInputs = [ cmake wrapQtAppsHook ];
  buildInputs = [ qtbase qtdeclarative qtsvg ];

  # The shell helpers need these. They are appended, so a tool already on the
  # user's PATH (notably `nix` itself and the setuid `pkexec`) always wins.
  qtWrapperArgs = [
    "--suffix PATH : ${lib.makeBinPath [ bash jq git curl coreutils util-linux findutils gnugrep gnused gawk inotify-tools libnotify direnv ]}"
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software NIXDATIFIER_SMOKE_TEST=1 XDG_RUNTIME_DIR=$TMPDIR
    $out/bin/nixdatifier --version
    $out/bin/nixdatifier 2>&1 | tee smoke.log
    grep -q NIXDATIFIER_HOST_LOADED smoke.log
    runHook postInstallCheck
  '';

  meta = {
    description = "NixOS generations, package diffs, flake updates and dev environments in a tray app";
    homepage = "https://github.com/Muddyblack/nixdatifier";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "nixdatifier";
  };
}

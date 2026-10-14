{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  qt6,
  installShellFiles,
  bash,
  nix-update-script,
  # What the shell helpers call. Appended to PATH, so a tool already on the
  # user's PATH (notably `nix` itself and the setuid `pkexec`) always wins.
  jq,
  git,
  curl,
  coreutils,
  util-linux,
  findutils,
  gnugrep,
  gnused,
  gawk,
  inotify-tools,
  libnotify,
  direnv,
  fzf,
  chafa,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "nixdatifier";
  version = "2.1.2";

  src = fetchFromGitHub {
    owner = "Muddyblack";
    repo = "nixdatifier";
    tag = "v${finalAttrs.version}";
    hash = "sha256-l4c7/ZevA9ara3S3Nfrno7b4PlakX8+Mq5HxBhBfU7E=";
  };

  sourceRoot = "${finalAttrs.src.name}/standalone";

  nativeBuildInputs = [
    cmake
    qt6.wrapQtAppsHook
    installShellFiles
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtsvg
  ];

  qtWrapperArgs = [
    "--suffix PATH : ${
      lib.makeBinPath [
        bash
        jq
        git
        curl
        coreutils
        util-linux
        findutils
        gnugrep
        gnused
        gawk
        inotify-tools
        libnotify
        direnv
        fzf
        chafa
      ]
    }"
  ];

  postInstall = ''
    for shell in bash zsh fish; do
      ${lib.getExe bash} $out/share/nixdatifier/package/contents/tools/sh/nixdatifier completion $shell > nixdatifier.$shell
    done
    installShellCompletion --cmd nixdatifier \
      --bash nixdatifier.bash --zsh nixdatifier.zsh --fish nixdatifier.fish
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software NIXDATIFIER_SMOKE_TEST=1 XDG_RUNTIME_DIR=$TMPDIR
    $out/bin/nixdatifier --version
    $out/bin/nixdatifier 2>&1 | tee smoke.log
    grep -q NIXDATIFIER_HOST_LOADED smoke.log
    runHook postInstallCheck
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "NixOS generations, package diffs, flake updates and dev environments in a tray app, with a terminal view";
    homepage = "https://github.com/Muddyblack/nixdatifier";
    changelog = "https://github.com/Muddyblack/nixdatifier/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "nixdatifier";
    maintainers = [ ];
  };
})

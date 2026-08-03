{ pkgs }:
let
  bun_1_3_14 =
    let
      sources = {
        aarch64-darwin = {
          platform = "darwin-aarch64";
          hash = "sha256-2LliIYKK1vl6x6wKt+lYcjQa92MAHogD6CZ2UsJlJiA=";
        };
        x86_64-linux = {
          platform = "linux-x64";
          hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
        };
      };
      source =
        sources.${pkgs.stdenv.hostPlatform.system}
          or (throw "unsupported bun platform: ${pkgs.stdenv.hostPlatform.system}");
    in
    pkgs.bun.overrideAttrs (_: {
      version = "1.3.14";
      src = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-${source.platform}.zip";
        inherit (source) hash;
      };
    });
in
pkgs.buildNpmPackage {
  pname = "omp-cli";
  version = "16.3.12";
  src = ./.;
  npmDepsHash = "sha256-XQvRH7oSuay9EX4j4p7bHNVLtzyy+v4+/tBvLQEGmeM=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/omp-cli
    cp -R node_modules package.json package-lock.json $out/lib/omp-cli/
    printf '%s\n' \
      '#!${pkgs.bash}/bin/sh' \
      "exec ${bun_1_3_14}/bin/bun $out/lib/omp-cli/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js \"\$@\"" \
      > $out/bin/omp
    chmod +x $out/bin/omp

    runHook postInstall
  '';
}

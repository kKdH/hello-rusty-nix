{
  description = "A Nix-flake-based development environment for Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ (import inputs.rust-overlay) ];
        };
        craneLib = (inputs.crane.mkLib pkgs).overrideToolchain (
          p: p.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml
        );
        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src;
          strictDeps = true;
          CARGO_PROFILE = "release";
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        rusty-nix = craneLib.buildPackage (
          commonArgs // {
            inherit cargoArtifacts;
          }
        );
      in
      {
        packages = {
          inherit rusty-nix;
          default = rusty-nix;
        };
        nixosModules.rusty-nix = { lib, config, ... }:
          let
            cfg = config.rusty-nix;
          in
          {
            options.rusty-nix = {
              enable = lib.mkEnableOption "Enables rusty-nix service.";
              port = lib.mkOption {
                type = lib.types.port;
                default = 8121;
              };
              data-directory = lib.mkOption {
                type = lib.types.path;
                default = "/var/lib/rusty-nix/";
              };
              user = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = "rusty";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  default = "rusty";
                };
              };
              service = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = "rusty-nix";
                };
              };
            };
            config = lib.mkIf cfg.enable {
              users.users."${cfg.user.name}" = {
                group = "${cfg.user.group}";
                isSystemUser = true;
                linger = true;
              };
              users.groups."${cfg.user.group}" = {
              };
              systemd.services."${cfg.service.name}" = {
                enable = true;
                description = "The rusty-nix service.";
                restartIfChanged = true;
                environment = {
                  RUSTY_NIX_PORT="${toString(cfg.port)}";
                  RUSTY_NIX_DATA="${cfg.data-directory}";
                };
                unitConfig = {
                  Type = "simple";
                  # ...
                };
                serviceConfig = {
                  ExecStart = "${rusty-nix}/bin/hello-rusty-nix";
                  User = "${cfg.user.name}";
                  Group = "${cfg.user.group}";
                };
                wantedBy = [ "multi-user.target" ];
              };
              systemd.tmpfiles.settings."${cfg.service.name}-data-directory" = {
                  "${cfg.data-directory}" = {
                    d = {
                      user = "${cfg.user.name}";
                      group = "${cfg.user.group}";
                      mode = "0755";
                    };
                };
              };
            };
          };
        devShells.default = craneLib.devShell {
          # additional packages for the dev shell
          packages = with pkgs; [
          ];
        };
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}

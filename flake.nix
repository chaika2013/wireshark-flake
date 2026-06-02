{
  description = "Wireshark nix-darwin module with ChmodBPF support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin }: {

    darwinModules.wireshark = { config, lib, pkgs, ... }:
      let
        cfg = config.wireshark;

        chmodBPFScript = pkgs.writeShellScript "ChmodBPF" ''
          for i in $(seq 0 255); do
            [ -c /dev/bpf$i ] || break
          done
          /usr/bin/chgrp access_bpf /dev/bpf* 2>/dev/null || true
          /bin/chmod g+rw /dev/bpf* 2>/dev/null || true
        '';

        users = builtins.attrNames config.users.users;

      in {
        options.wireshark = {
          enable = lib.mkEnableOption "Wireshark network analyzer";

          chmodBPF = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Install a launchd daemon (org.wireshark.ChmodBPF) that runs at
              boot to set group read/write permissions on /dev/bpf* devices,
              and create the access_bpf group containing all users defined in
              config.users.users.
            '';
          };
        };

        config = lib.mkIf cfg.enable {

          environment.systemPackages = [ pkgs.wireshark ];

          launchd.daemons.ChmodBPF = lib.mkIf cfg.chmodBPF {
            serviceConfig = {
              Label = "org.wireshark.ChmodBPF";
              RunAtLoad = true;
              Program = "${chmodBPFScript}";
            };
          };

          system.activationScripts.postActivation.text = lib.mkAfter (lib.optionalString cfg.chmodBPF ''
            echo "wireshark: setting up access_bpf group..."
            /usr/sbin/dseditgroup -o read access_bpf 2>/dev/null || \
              /usr/sbin/dseditgroup -o create -r "BPF device access" access_bpf 2>/dev/null || true
            ${lib.concatMapStringsSep "\n" (user: ''
              /usr/sbin/dseditgroup -o edit -a ${user} -t user access_bpf 2>/dev/null || true
            '') users}

            echo "wireshark: loading ChmodBPF launchd daemon..."
            /bin/launchctl unload /Library/LaunchDaemons/org.wireshark.ChmodBPF.plist 2>/dev/null || true
            /bin/launchctl load -w /Library/LaunchDaemons/org.wireshark.ChmodBPF.plist
          '');

        };
      };

  };
}

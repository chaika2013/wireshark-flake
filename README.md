# wireshark

A Nix flake providing a [nix-darwin](https://github.com/LnL7/nix-darwin) module that installs Wireshark on macOS and configures the `ChmodBPF` launchd daemon so that non-root users can capture packets on `/dev/bpf*` devices.

## Usage

Add the flake as an input in your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wireshark = {
      url = "github:chaika2013/wireshark-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, wireshark }: {
    darwinConfigurations."my-host" = nix-darwin.lib.darwinSystem {
      modules = [
        wireshark.darwinModules.wireshark
        {
          wireshark.enable = true;
        }
      ];
    };
  };
}
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `wireshark.enable` | `bool` | `false` | Install Wireshark and apply the configuration below. |
| `wireshark.chmodBPF` | `bool` | `true` | Install the `org.wireshark.ChmodBPF` launchd daemon that grants `group read/write` access on `/dev/bpf*` at boot, and add all users defined in `config.users.users` to the `access_bpf` group. |

## How it works

macOS restricts access to BPF (Berkeley Packet Filter) devices (`/dev/bpf*`) to root by default, which prevents Wireshark from capturing packets without `sudo`.

When `wireshark.chmodBPF = true` (the default), this module:

1. **Creates the `access_bpf` group** during `system.activationScripts.postActivation` using `dseditgroup`, and adds every user declared in `config.users.users` to it.
2. **Installs a launchd daemon** (`org.wireshark.ChmodBPF`) that runs at boot and sets `g+rw` permissions on all `/dev/bpf*` devices, making them accessible to members of `access_bpf` without elevated privileges.

This replicates the behaviour of the official Wireshark macOS installer's `ChmodBPF` helper.

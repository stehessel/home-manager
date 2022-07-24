{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.swhkd;

  keybindingsStr = concatStringsSep "\n" (mapAttrsToList
    (hotkey: command:
      optionalString (command != null) ''
        ${hotkey}
          ${command}
      '')
    cfg.keybindings);

in
{
  options.services.swhkd = {
    enable = mkEnableOption "Sxhkd clone for Wayland";

    package = mkOption {
      type = types.package;
      default = pkgs.swhkd;
      defaultText = "pkgs.swhkd";
      description =
        "Package containing the <command>swhkd</command> executable.";
    };

    keybindings = mkOption {
      type = types.attrsOf (types.nullOr types.str);
      default = { };
      description = "An attribute set that assigns hotkeys to commands.";
      example = literalExpression ''
        {
          "super + shift + {r,c}" = "i3-msg {restart,reload}";
          "super + {s,w}"         = "i3-msg {stacking,tabbed}";
        }
      '';
    };

    extraConfig = mkOption {
      default = "";
      type = types.lines;
      description = "Additional configuration to add.";
      example = literalExpression ''
        super + {_,shift +} {1-9,0}
          i3-msg {workspace,move container to workspace} {1-10}
      '';
    };

    systemd.enable = mkEnableOption "swhkd systemd integration";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        (lib.hm.assertions.assertPlatform "services.swhkd" pkgs
          lib.platforms.linux)
      ];

      home.packages = [ cfg.package ];

      xdg.configFile."swhkd/swhkdrc".text =
        concatStringsSep "\n" [ keybindingsStr cfg.extraConfig ];
    }

    (mkIf cfg.systemd.enable {
      systemd.user.services.swhkd = {

        Unit = {
          Description = "swhkd hotkey daemon";
        };

        Service = {
          ExecStart = "${cfg.package}/bin/swhks & /run/wrappers/bin/pkexec ${cfg.package}/bin/swhkd";
          ExecStop = [ "${pkgs.psmisc}/bin/killall swhks" ];
          ExecReload = "${pkgs.procps}/bin/pkill -HUP swhkd";
          Restart = "on-failure";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ]);
}

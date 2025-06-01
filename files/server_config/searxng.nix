{ options, config, lib, pkgs, ... }:
with lib;
let
  runDir = "/run/searxng";
  cfg = config.services.searxng;
  settingsFile = pkgs.writeText "settings.yml"
    (builtins.toJSON cfg.settings);
  generateConfig = ''
    cd ${runDir}
    (
      umask 077
      cp --no-preserve=mode ${settingsFile} settings.yml
    )
    env -0 | while IFS='=' read -r -d ''' n v; do
      sed "s#@$n@#$v#g" -i settings.yml
    done
  '';
  settingType = with types; (oneOf
    [ bool int float str
      (listOf settingType)
      (attrsOf settingType)
    ]) // { description = "JSON value"; };
in
{
  imports = [
    (mkRenamedOptionModule
      [ "services" "searxng" "configFile" ]
      [ "services" "searxng" "settingsFile" ])
  ];

  options = {
    services.searxng = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
      settings = mkOption {
        type = types.attrsOf settingType;
        default = { };
      };
      settingsFile = mkOption {
        type = types.path;
        default = "${runDir}/settings.yml";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.searx;
      };
      runInUwsgi = mkOption {
        type = types.bool;
        default = false;
      };
      uwsgiConfig = mkOption {
        type = options.services.uwsgi.instance.type;
        default = { http = ":8080"; };
      };
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    users.users.searxng =
      { description = "SearxNG daemon user";
        group = "searxng";
        isSystemUser = true;
      };
    users.groups.searxng = { };
    systemd.services.searxng-init = {
      description = "Initialise SearxNG settings";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "searxng";
        RuntimeDirectory = "searxng";
        RuntimeDirectoryMode = "750";
      } // optionalAttrs (cfg.environmentFile != null)
        { EnvironmentFile = builtins.toPath cfg.environmentFile; };
      script = generateConfig;
    };
    systemd.services.searxng = mkIf (!cfg.runInUwsgi) {
      description = "SearxNG server, the meta search engine.";
      wantedBy = [ "network.target" "multi-user.target" ];
      requires = [ "searxng-init.service" ];
      after = [ "searxng-init.service" ];
      serviceConfig = {
        User  = "searxng";
        Group = "searxng";
        ExecStart = "${cfg.package}/bin/searxng-run";
      } // optionalAttrs (cfg.environmentFile != null)
        { EnvironmentFile = builtins.toPath cfg.environmentFile; };
      environment.SEARXNG_SETTINGS_PATH = cfg.settingsFile;
    };
    systemd.services.uwsgi = mkIf (cfg.runInUwsgi)
      { requires = [ "searxng-init.service" ];
        after = [ "searxng-init.service" ];
      };
    services.searxng.settings = {
      # merge NixOS settings with defaults settings.yml
      use_default_settings = mkDefault true;
    };
    services.uwsgi = mkIf (cfg.runInUwsgi) {
      enable = true;
      plugins = [ "python3" ];
      instance.type = "emperor";
      instance.vassals.searxng = {
        type = "normal";
        strict = true;
        immediate-uid = "searxng";
        immediate-gid = "searxng";
        lazy-apps = true;
        enable-threads = true;
        module = "searx.webapp";
        env = [ "SEARXNG_SETTINGS_PATH=${cfg.settingsFile}" ];
        pythonPackages = self: [ cfg.package ];
      } // cfg.uwsgiConfig;
    };
  };
}

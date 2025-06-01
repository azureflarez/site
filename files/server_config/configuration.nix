{ config, pkgs, options, ... }:
let release = "21.11";
in {
  imports = let mailserver-release = "master"; in [
    ./hardware-configuration.nix
    ./network-configuration.nix
    ./searxng.nix
    (builtins.fetchTarball {
         url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${mailserver-release}/nixos-mailserver-${mailserver-release}.tar.gz";
         sha256 = "1i56llz037x416bw698v8j6arvv622qc0vsycd20lx3yx8n77n44";
       })
  ];
  system.stateVersion = "${release}";
  boot.cleanTmpDir = true;
  zramSwap.enable = true;
  services.openssh.enable = true;
  environment.systemPackages = with pkgs; [
    git
    neovim
    tmux
    vim
    wget
  ];
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      # ssh
      22
      # http/s
      80 443
      # Matrix
      8008 8448
      # Mumble
      64738
      # Used for mumble-web signaling (not sure if it needs TCP or UDP)
      20000 20001 20002 20003 20004 20005 20006 20007 20008 20009 20010
    ];
    allowedUDPPorts = [
      # Mumble
      64738
      # Used for mumble-web signaling (not sure if it needs TCP or UDP)
      20000 20001 20002 20003 20004 20005 20006 20007 20008 20009 20010
    ];
  };
  services.searxng.enable = true;
  services.searxng.package = pkgs.searxng;
  services.searxng.runInUwsgi = true;
  services.searxng.settingsFile = "/var/lib/searx/settings.yml";
  services.nginx = {
    enable = true;
    commonHttpConfig = "log_format postdata '{\"ip\":\"$remote_addr\",\"time\":\"$time_iso8601\",\"referer\":\"$http_referer\",\"body\":\"$request_body\",\"ua\":\"$http_user_agent\"}';";
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    virtualHosts =
      let server = {
            "m.server" = "matrix.${config.networking.domain}:443";
          };
          client = {
            "m.homeserver" = { "base_url" = "https://matrix.${config.networking.domain}"; };
            "m.identity_server" = { "base_url" = "https://vector.im"; };
          };
          serverConfig = 
          ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON server}';
          '';
          clientConfig =
          ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON client}';
          '';
      in
    {
      "matrix.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/repo".extraConfig = "return 301 https://${config.networking.domain}$request_uri;";

        locations."/_matrix/maubot/" = {
          proxyPass = "http://127.0.0.1:29316";
          proxyWebsockets = true;
        };
        locations."= /.well-known/matrix/server".extraConfig = serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = clientConfig;
        locations."/".proxyPass = "http://[::1]:8008";
      };
      "search.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:8080";
      };
      "${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        extraConfig = "autoindex on;";
        locations."/".root = "/var/www/${config.networking.domain}/";
        locations."/fdroid/".alias = "/var/lib/fdroid/repo/";
        locations."/src".root = "/var/www/${config.networking.domain}/";
        locations."/src".extraConfig = "index force_dirlisting;";
        locations."/submit_comment".extraConfig = ''
          access_log /var/log/nginx/comments.log postdata;
          proxy_pass https://${config.networking.domain}/submit.htm;
          break;
        '';
        locations."/submit.htm" = {
          extraConfig = ''
            return 200 '<!doctype html><html><head><base href="/"/><link rel="preload" href="style.css" as="style"><title>Success!</title><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><link rel="icon" type="image/jpeg" href="pfp.jpg"><link rel="alternate" type="application/rss+xml" title="RSS" href="https://${config.networking.domain}/blog/index.xml"><link href="style.css" rel="stylesheet" /><script src="main.js"></script><meta http-equiv="refresh" content="10; url=$http_referer" /></head><body onload="documentLoaded()"><hr/><div class="main-body"><p>Success! It may take a while for your comment to get moderated.</p><p>Please wait for 10 seconds until you get redirected back...</p><p>Or just go there <a href="$http_referer">manually</a>.</p></div><hr/></body></html>';
          '';
        };
        
        locations."= /.well-known/matrix/server".extraConfig = serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = clientConfig;
      };
      "mail.${config.networking.domain}" = {
        enableACME = true;
        globalRedirect = "${config.networking.domain}";
      };
      "www.${config.networking.domain}" = {
        enableACME = true;
        globalRedirect = "${config.networking.domain}";
      };
      "sync.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
      };
      "cloud.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
      };
      "git.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://localhost:3310";
      };
      "mumble.${config.networking.domain}" = {
        enableACME = true;
        forceSSL = true;
        root = "/var/www/mumble.${config.networking.domain}";
        locations."/music".extraConfig = "return 301 https://mumble.${config.networking.domain}/music/;";
        locations."/music/".proxyPass = "http://[::1]:8181/";
        locations."/ws" = {
          proxyWebsockets = true;
          proxyPass = "http://[::1]:64737";
        };
      };
    };
  };
  # In case DNS fails (Which happened twice so far... what are you doing Porkbun)
  networking.hosts."127.0.0.1" = let d = config.networking.domain; in [
    "localhost" "${d}" "search.${d}" "cloud.${d}" "www.${d}" "sync.${d}" "git.${d}" "matrix.${d}" "mail.${d}"
  ];

  services.postgresql.enable = true;

  mailserver = {
    enable = true;
    fqdn = "mail.${config.networking.domain}";
    domains = [ "${config.networking.domain}" ];
    certificateScheme = 1;
    certificateFile = config.security.acme.certs."mail.${config.networking.domain}".directory + "/fullchain.pem";
    keyFile = config.security.acme.certs."mail.${config.networking.domain}".directory + "/key.pem";
    recipientDelimiter = "-";
    lmtpSaveToDetailMailbox = "no";
    hierarchySeparator = "/";
  };

  # Allow local connections to noreply account
  mailserver.loginAccounts."noreply@${config.networking.domain}" = { hashedPasswordFile = "/etc/nixos/passwords/02"; };
  services.dovecot2.extraConfig =
    let passwd = builtins.toFile "dovecot2-local-passwd" ''
        noreply@${config.networking.domain}:{plain}totallysafe::::::allow_nets=local,127.0.0.0/8,::1
      '';
    in ''
      passdb {
        driver = passwd-file
        args = ${passwd}
      }
    '';

  services.gitea = {
    enable = true;
    cookieSecure = true;
    database = {
      createDatabase = false;
      passwordFile = "/var/lib/gitea/db_password";
      type = "postgres";
    };
    disableRegistration = true;
    domain = "git.${config.networking.domain}";
    httpPort = 3310;
    rootUrl = "https://git.${config.networking.domain}";
    settings = {
      mailer = {
              ENABLED = true;
              FROM = "Gitea <noreply@${config.networking.domain}>";
              MAILER_TYPE = "smtp";
              HOST = "localhost:587";
              USER = "noreply@${config.networking.domain}";
              PASSWD = "totallysafe";
              SKIP_VERIFY = true;
      };
      service = {
        REGISTER_EMAIL_CONFIRM = true;
      };
    };
  };

  services.matrix-synapse = {
    enable = true;
    app_service_config_files = [
      "/var/lib/discord-bridge/discord-registration.yaml"
      "/var/lib/vk-bridge/vk-registration.yaml"
    ];
    allow_guest_access = true;
    max_upload_size = "100M";
    public_baseurl = "https://matrix.${config.networking.domain}/";
    tls_certificate_path = config.security.acme.certs."matrix.${config.networking.domain}".directory + "/fullchain.pem";
    tls_private_key_path = config.security.acme.certs."matrix.${config.networking.domain}".directory + "/key.pem";
    url_preview_enabled = true;
    server_name = "matrix.${config.networking.domain}";
    listeners = [{
      port = 8008;
      bind_address = "::1";
      type = "http";
      tls = false;
      x_forwarded = true;
      resources = [{
        names = [ "client" "federation" ];
        compress = false;
      }];
    }];
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud23;
    autoUpdateApps.enable = true;
    config = {
      adminpassFile = "/var/lib/nextcloud/admin_password";
      dbpassFile = "/var/lib/nextcloud/db_password";
      dbtype = "pgsql";
      dbhost = "/run/postgresql";
      overwriteProtocol = "https";
    };
    hostName = "cloud.${config.networking.domain}";
    https = true;
  };

  # Mumble server (VoIP)
  services.murmur = {
    enable = true;
    imgMsgLength = 0;
    textMsgLength = 0;
    registerName = "mumble.${config.networking.domain}";
    registerHostname = "mumble.${config.networking.domain}";
    sslCa = config.security.acme.certs."mumble.${config.networking.domain}".directory + "/chain.pem";
    sslCert = config.security.acme.certs."mumble.${config.networking.domain}".directory + "/fullchain.pem";
    sslKey = config.security.acme.certs."mumble.${config.networking.domain}".directory + "/key.pem";
    # clientCertRequired = true;
    extraConfig = ''
      bandwidth=320000
      opusthreshold=0
    '';
  };
  # Allow murmur to read the certificate
  security.acme.certs."mumble.${config.networking.domain}" = {
    group = "nginxandmurmur";
    postRun = "systemctl reload-or-restart murmur";
  };

  # Mumble music bot
  services.botamusique = {
    enable = true;
    settings = {
      youtube_dl = {
        cookiefile = "/var/lib/botamusique/cookie_ydl";
      };
      webinterface = {
        enabled = true;
        listening_addr = "::1";
        listening_port = 8181;
        is_web_proxified = true;
        access_address = "https://mumble.${config.networking.domain}/music";
        auth_method = "token";
        upload_enabled = true;
        max_upload_file_size = "100MB";
        delete_allowed = true;
      };
      bot = {
        bandwidth = 200000;
        volume = 1.0;
        ducking = true;
        ducking_volume = 0.75;
      };
      server.certificate = "/var/lib/botamusique/cert.pem";
    };
  };
  systemd.services.botamusique.wants = [ "murmur.service" ];

  services.cron = {
    enable = true;
    systemCronJobs = [
      # Update F-Droid repo
      "0 0 * * *      fdroid  nix-shell --command \"python3 /var/lib/fdroid/update.py\" -p python3 python3Packages.requests fdroidserver wget jdk11_headless"
    ];
  };

  # TODO Firefox sync server (when they start supporting py3?)
  # Or maybe use Docker?

  # I could package these, but I use many patches for bridges anyway, so I just left it as-is
  systemd.services = {
    discord-bridge = {
      description = "Discord-Matrix bridge";
      wants = [ "matrix-synapse.service" "nginx.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nodejs-14_x pkgs.bash ];
      serviceConfig = {
        User = "discordbridge";
        Group = "discordbridge";
        WorkingDirectory = "/var/lib/discord-bridge/matrix-appservice-discord";
      };
      script = "${pkgs.nodejs-14_x}/bin/npm run start";
    };
    vk-bridge = {
      description = "VK-Matrix bridge";
      wants = [ "matrix-synapse.service" "nginx.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.nodejs-14_x pkgs.bash ];
      environment = { LD_LIBRARY_PATH = "${pkgs.pixman}/lib:${pkgs.cairo}/lib:${pkgs.libpng}/lib:${pkgs.pango.out}/lib:${pkgs.glib.out}/lib:${pkgs.freetype}/lib:${pkgs.libjpeg.out}/lib:${pkgs.giflib}/lib:${pkgs.cairo.out}/lib:${pkgs.pango}/lib"; };
      serviceConfig = {
        User = "vkbridge";
        Group = "vkbridge";
        WorkingDirectory = "/var/lib/vk-bridge/mx-puppet-vk";
      };
      script = "${pkgs.nodejs-14_x}/bin/npm run start";
    };
    maubot = {
      description = "Maubot";
      wants = [ "matrix-synapse.service" "nginx.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = { LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib"; };
      serviceConfig = {
        User = "maubot";
        Group = "maubot";
        WorkingDirectory = "/var/lib/maubot/data";
      };
      script = "${pkgs.python3.withPackages (pks: with pks; [ pkgs.maubot pkgs.pineapplebot feedparser levenshtein python-dateutil pytz ])}/bin/python3 -m maubot";
    };
    #mumble-web-proxy = {
    #  description = "Mumble-Web Proxy";
    #  wants = [ "murmur.service" ];
    #  wantedBy = [ "multi-user.target" ];
    #  serviceConfig = {
    #    User = "mumbleweb";
    #    Group = "mumbleweb";
    #    WorkingDirectory = "/var/lib/mumble-web";
    #  };
    #  script = "/var/lib/mumble-web/proxy --listen-ws 64737 --server mumble.${config.networking.domain} --ice-port-min=20000 --ice-port-max=20010";
    #};
  };
  users.users = {
    user = {
      isNormalUser = true;
      home = "/home/user";
      extraGroups = [ "wheel" ];
    };
    vkbridge = {
      home = "/var/lib/vk-bridge";
      group = "vkbridge";
      isSystemUser = true;
    };
    discordbridge = {
      home = "/var/lib/discord-bridge";
      group = "discordbridge";
      isSystemUser = true;
    };
    maubot = {
      home = "/var/lib/maubot";
      group = "maubot";
      isSystemUser = true;
    };
    ffsyncserver = {
      home = "/var/lib/firefox-sync-server";
      group = "ffsyncserver";
      isSystemUser = true;
    };
    mumbleweb = {
      home = "/var/lib/mumble-web";
      group = "mumbleweb";
      isSystemUser = true;
    };
    fdroid = {
      home = "/var/lib/fdroid";
      group = "fdroid";
      isSystemUser = true;
    };
  };
  users.groups = {
    discordbridge = { };
    vkbridge = { };
    maubot = { };
    ffsyncserver = { };
    mumbleweb = { };
    fdroid = { };
    nginxandmurmur = { members = [ "murmur" "nginx" ]; };
  };

  # Use the specified overlays system-wide
  nix.nixPath = options.nix.nixPath.default ++ [
    "nixpkgs-overlays=/etc/nixos/overlays-compat/"
  ];

  nixpkgs.overlays = [
    (self: super: rec {
      searxng = (pkgs.callPackage ./searxng_pkg.nix { });
      # Official Android SDK is unavailable on arm64, remove apksigner dependency from fdroidserver
      # Also, I don't need apk signing anyway, I just fetch it from upstream
      fdroidserver = super.fdroidserver.overridePythonAttrs (oldAttrs: rec {
        makeWrapperArgs = [ ];
      });
      maubot = with super; let python = python3.override {
        packageOverrides = self: super: {
          # click<8
          click = super.click.overridePythonAttrs (oldAttrs: rec {
            version = "7.1.2"; src = oldAttrs.src.override { inherit version; sha256 = "06kbzd6sjfkqan3miwj9wqyddfxc2b6hi7p5s4dvqjb3gif2bdfj"; };
          });
          # mautrix<0.13
          mautrix = super.mautrix.overridePythonAttrs (oldAttrs: rec {
            version = "0.12.5"; src = oldAttrs.src.override { inherit version; sha256 = "1vm1rsbh2lifa0fsrqxzrq6q0iiww2imrz7v2qs091dawp25q2gp"; };
            propagatedBuildInputs = [ super.aiohttp super.simplejson super.pyramid ];
          });
          # SQLAlchemy<1.4
          sqlalchemy = super.sqlalchemy.overridePythonAttrs (oldAttrs: rec {
            version = "1.3.24"; src = oldAttrs.src.override { inherit version; sha256 = "06bmxzssc66cblk1hamskyv5q3xf1nh1py3vi6dka4lkpxy7gfzb"; };
          });
        };
      };
      in with python.pkgs; buildPythonPackage rec {
        pname = "maubot"; version = "0.2.0"; disabled = pythonOlder "3.7";
        src = fetchPypi { inherit pname version; sha256 = "1ywvrvvq36f1bh4hl9xamj09249px0v4f0v99bgwpr7vpsxrjyhw"; };
        propagatedBuildInputs = [
            mautrix aiohttp yarl sqlalchemy
            alembic CommonMark ruamel-yaml
            attrs bcrypt packaging click
            colorama questionary jinja2
          ]
          ++ [ psycopg2 asyncpg ]
          ++ [ aiosqlite python-olm pycryptodome unpaddedbase64 ];
        passthru.tests = {
          simple = runCommand "${pname}-tests" { } ''
            ${maubot}/bin/mbc --help > $out
          '';
        };
        dontUseSetuptoolsCheck = true;
        pythonImportsCheck = [ "maubot" ];
        meta = with lib; {
          description = "A plugin-based Matrix bot system written in Python";
          homepage = "https://github.com/maubot/maubot/";
          license = licenses.agpl3Plus;
        };
      };
    })
  ];
}

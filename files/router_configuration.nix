{ config, lib, pkgs, ... }:

let
  wan0PciService = "sys-devices-pci0000:00-0000:00:1c.5-0000:03:00.0-net-lan0.device";
  lanMac = "00:11:22:33:44:55";
  wanMac = "00:11:22:33:44:55";
  wanTargetMac = "00:11:22:33:44:55";
  # wlan config is only here just in case I'll want to enable it
  wlanMac = "00:11:22:33:44:55";

  lan4Subnet = "10.0.0.0";
  lan4Mask = "255.255.255.0";
  lan4Cidr = "${lan4Subnet}/24";
  router4 = "10.0.0.1";
  dhcp4Min = "10.0.0.2";
  dhcp4Max = "10.0.0.254";
  bridge4Bits = "24";
  bridge4Cidr = "10.10.10.0/${bridge4Bits}";
  bridge4 = "10.10.10.1";
  vpnGate4 = "10.10.10.2";
  wanGate4 = "10.10.10.3";

  lan6Cidr = "fd00::/64";
  router6 = "fd00::1";
  dhcp6Min = "fd00::2";
  dhcp6Max = "fd00::ff00";
  bridge6Bits = "64";
  bridge6Cidr = "fd01::/${bridge6Bits}";
  bridge6 = "fd01::1";
  vpnGate6 = "fd01::2";
  wanGate6 = "fd01::3";

  wgIps = [ "10.10.10.10/32" "fe80:aaaa::1/128" ];
  wgPubKey = "bm9wZSwgbm8ga2V5cyBoZXJlLCB0cnkgYWdhaW4gbGF0ZXIK";
  wgEndpoint = "13.37.10.10:420";
  wgKeyFile = "/etc/nixos/wireguard_key";

  updateRknBlacklist = with pkgs; writeScript "update-rkn-blacklist" ''
    #! ${bash}/bin/bash
    BLACKLIST=$(${coreutils}/bin/mktemp) || exit 1
    RULESET=$(${coreutils}/bin/mktemp) || exit 1
    
    ${curl}/bin/curl "https://reestr.rublacklist.net/api/v2/ips/csv/" > $BLACKLIST || (${coreutils}/bin/rm $BLACKLIST && exit 1) || exit 1
    ${coreutils}/bin/echo "add element inet global force_vpn4 {" > $RULESET || (${coreutils}/bin/rm $BLACKLIST && exit 1) || exit 1
    ${gnugrep}/bin/grep '\.' $BLACKLIST >> $RULESET
    ${coreutils}/bin/echo "};" >> $RULESET
    ${coreutils}/bin/echo "add element inet global force_vpn6 {" >> $RULESET
    ${gnugrep}/bin/grep '\:' $BLACKLIST >> $RULESET
    ${coreutils}/bin/echo "};" >> $RULESET
    ${coreutils}/bin/rm $BLACKLIST
    ${nftables}/bin/nft -f $RULESET || (${coreutils}/bin/rm $RULESET && exit 1) || exit 1
    ${coreutils}/bin/rm $RULESET
    exit 0
  '';

  nftablesConfig = (lan: lan6: selfs: self6s: extIf: lanIfs: additionalInetChains: trustIps: trustIp6s: extraFwRules:
    let
      mergedLanIfs = lib.concatStringsSep ", " lanIfs;
      mergedSelfs = lib.concatStringsSep ", " selfs;
      mergedSelf6s = lib.concatStringsSep ", " self6s;
      wanPreRules = if trustIps != null
        then let
          mergedIps = lib.concatStringsSep ", " trustIps;
          mergedIp6s = lib.concatStringsSep ", " trustIp6s;
        in ''
          ip saddr { ${mergedIps} } jump inbound_lan; 
          ip6 saddr { ${mergedIp6s} } jump inbound_lan; 
        ''
        else "";
    in ''
      define LAN_SPACE = ${lan}
      define LAN6_SPACE = ${lan6}
      define SELF = { ${mergedSelfs} };
      define SELF6 = { ${mergedSelf6s} };
      define EXT = ${extIf};
      define LAN = { ${mergedLanIfs} };
      
      table netdev filter {
        chain ingress {
          type filter hook ingress devices = { ${mergedLanIfs}, $EXT } priority -500;
      
          # drop fin and syn at the same time
          tcp flags & (fin|syn) == (fin|syn) drop
          # same for syn and rst
          tcp flags & (syn|rst) == (syn|rst) drop
      
          # XMAS packets
          tcp flags & (fin|syn|rst|psh|ack|urg) == (fin|syn|rst|psh|ack|urg) drop
          # NULL packets
          tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop
          # reject packets with irregular MSS
          tcp flags syn tcp option maxseg size 0-500 drop
      
          # Spoofing protection
          ip saddr $SELF drop
          ip6 saddr $SELF6 drop
      
          # drop if coming from the wrong interface
          fib  saddr . iif  oif missing drop
        }
      
        chain ingress_wan {
          type filter hook ingress devices = { $EXT } priority -500;
          # rate limit icmp
          ip protocol icmp limit rate 5/second accept
          ip protocol icmp counter drop
          ip6 nexthdr icmpv6 limit rate 5/second accept
          ip6 nexthdr icmpv6 counter drop
          # only accept packets to local addresses from wan
          fib  daddr . iif  type != local drop
        }
      }
      
      table inet global {
        chain prert {
          type filter hook prerouting priority 0; policy accept;
        }
        chain inbound_wan {
          ${wanPreRules}
          # https://shouldiblockicmp.com/
          # add router-solicitation, router-advertisement and so on if your ISP requires it, mine doesn't
          ip protocol icmp icmp type { destination-unreachable, echo-request, time-exceeded, parameter-problem } accept
          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, echo-request, time-exceeded, parameter-problem, packet-too-big } accept
        }
        chain inbound_lan {
          # I trust my LAN, however you might have different requirements
          accept
        }
        chain inbound {
          type filter hook input priority 0; policy drop;
      
          ct state vmap { established : accept, related : accept, invalid : drop }
      
          # new packet but no syn
          tcp flags & syn != syn ct state new drop
      
          iifname vmap {
            lo : accept,
            $EXT : jump inbound_wan,
            $LAN : jump inbound_lan
          }
        }
        chain forward {
          type filter hook forward priority 0; policy drop;
      
          ${extraFwRules}

          ct state vmap { established : accept, related : accept, invalid : drop }
      
          iifname $LAN accept
        }
        ${additionalInetChains}
        chain postrouting {
          type nat hook postrouting priority 0; policy accept;
          ip saddr $LAN_SPACE oifname $EXT masquerade;
          ip6 saddr $LAN6_SPACE oifname $EXT masquerade;
        }
      }
    ''
  );
in
{
  imports =
    [ ./hardware-configuration.nix
    ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub.device = "nodev"; # or "nodev" for efi only

  networking.hostName = "nixos"; # Define your hostname.

  time.timeZone = "Asia/Tomsk";

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.src_valid_mark" = true;
    "net.ipv4.conf.all.src_valid_mark" = true;
    "net.ipv4.conf.lan0.rp_filter" = 1;
    "net.ipv4.conf.wlan0.rp_filter" = 1;
    "net.ipv4.conf.lan0.src_valid_mark" = true;
    "net.ipv4.conf.wlan0.src_valid_mark" = true;
    "net.netfilter.nf_log_all_netns" = true;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${lanMac}", NAME="lan0"
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${wanMac}", NAME="wan0"
    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${wlanMac}", NAME="wlan0"
  '';

  networking.useDHCP = false;
  networking.interfaces = {
    wan0 = {
      useDHCP = true;
      macAddress = wanTargetMac;
    };
    lan0 = {
      ipv4.addresses = [{
        address = router4;
        prefixLength = 24;
      }];
      ipv6.addresses = [{
        address = router6;
        prefixLength = 64;
      }];
    };
  };
  networking.iproute2 = {
    enable = true;
    rttablesExtraConfig = ''
      1 wan_table
      2 vpn_table
    '';
  };
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = (nftablesConfig
    lan4Cidr lan6Cidr [router4 bridge4] [router6 bridge6] "br0" [ "lan0" "wlan0" ]
    ''
      set force_vpn4 {
        type ipv4_addr;
        flags interval;
        auto-merge;
      }
      set force_vpn6 {
        type ipv6_addr;
        flags interval;
        auto-merge;
      }
      chain prerouting_nat {
        type nat hook prerouting priority 0;
        # redirect all dns queries to unbound
        # my VPN provider (Mullvad) does that too, so the packets wouldn't've
        # reached the destination anyway... DNS over TLS is signed, so don't
        # reroute that though.
        ip saddr $LAN_SPACE meta l4proto { tcp, udp } th dport { 53 } dnat to ${router4}
        ip6 saddr $LAN6_SPACE meta l4proto { tcp, udp } th dport { 53 } dnat to ${router6}
      }
      chain prerouting {
        type filter hook prerouting priority 0; policy accept;
        counter meta mark set ct mark
        mark != 0x0 counter accept
        ip saddr $LAN_SPACE counter meta mark set 0x2
        ip6 saddr $LAN6_SPACE counter meta mark set 0x2
        ip daddr @force_vpn4 counter meta mark set 0x2
        ip6 daddr @force_vpn6 counter meta mark set 0x2
        counter ct mark set mark
      }
    ''
    # give namespaces full local service access
    [ bridge4Cidr ] [ bridge6Cidr ] ""
  );

  services.murmur = {
    enable = true;
    imgMsgLength = 0;
    textMsgLength = 0;
    registerName = "mumble.local";
    registerHostname = "mumble.local";
    bandwidth = 500000;
    bonjour = true;
    extraConfig = "opusThreshold=0";
  };
  services.botamusique = {
    enable = true;
    settings = {
      youtube_dl.cookiefile = "/var/lib/botamusique/cookie_ydl";
      webinterface = {
        enabled = true;
        listening_addr = "127.0.0.1";
        listening_port = 8181;
        is_web_proxified = true;
        access_address = "http://mumble.local";
        auth_method = "none";
        upload_enabled = true;
        max_upload_file_size = "1GB";
        delete_allowed = true;
      };
      bot = {
        bandwidth = 500000;
        volume = 1.0;
        ducking = true;
        ducking_volume = 0.75;
      };
    };
  };
  systemd.services.botamusique.wants = [ "murmur.service" ];
  services.dhcpd4 = {
    enable = true;
    interfaces = [ "lan0" ];
    machines = [ ];
    extraConfig = ''
      option routers ${router4};
      option domain-name-servers ${router4};
      option domain-name "local";
      subnet ${lan4Subnet} netmask ${lan4Mask} {
        range ${dhcp4Min} ${dhcp4Max};
      }
    '';
  };
  services.radvd = {
    enable = true;
    config = ''
      interface lan0 {
        AdvSendAdvert on;
        # MinRtrAdvInterval 30;
        # MaxRtrAdvInterval 100;
        AdvManagedFlag on;
        prefix ${lan6Cidr} {
          AdvOnLink on;
          AdvAutonomous off;
        };
      };
    '';
  };
  services.dhcpd6 = {
    enable = true;
    interfaces = [ "lan0" ];
    machines = [ ];
    extraConfig = ''
      option dhcp6.name-servers ${router6};
      option dhcp6.domain-search "local";
      subnet6 ${lan6Cidr} {
        range6 ${dhcp6Min} ${dhcp6Max};
      }
    '';
  };

  services.avahi = {
    enable = true;
    hostName = "router";
    interfaces = [ "lan0" "wlan0" ];
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      userServices = true;
    };
  };
  networking.resolvconf.extraConfig = ''
    name_servers="${bridge4} ${bridge6}"
  '';
  services.unbound =
    let python = pkgs.python3.withPackages (pkgs: with pkgs; [ pydbus dnspython ]);
  in {
    enable = true;
    package = pkgs.unbound-with-systemd.overrideAttrs(old: {
      preConfigure = "export PYTHON_VERSION=${python.pythonVersion}";
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.swig ];
      buildInputs = old.buildInputs ++ [ python ];
      configureFlags = old.configureFlags ++ [ "--with-pythonmodule" ];
      postPatch = old.postPatch or "" + ''
        substituteInPlace Makefile.in \
          --replace "\$(DESTDIR)\$(PYTHON_SITE_PKG)" "$out/${python.sitePackages}"
      '';
      postInstall = old.postInstall + ''
        wrapProgram $out/bin/unbound \
          --prefix PYTHONPATH : "$out/${python.sitePackages}" \
          --prefix PYTHONPATH : "${python}/${python.sitePackages}" \
          --argv0 $out/bin/unbound
      '';
    });
    localControlSocketPath = "/run/unbound/unbound.ctl";
    resolveLocalQueries = false;
    settings = {
      server = {
        interface = [ "127.0.0.1" "::1" router4 router6 bridge4 bridge6 ];
        access-control =  [
          #"0.0.0.0/0 allow"
          #"::0/0 allow"
          "0.0.0.0/0 refuse"
          "::0/0 refuse"
          "127.0.0.0/8 allow"
          "::1 allow"
          "${lan4Cidr} allow"
          "${lan6Cidr} allow"
          "${bridge4Cidr} allow"
          "${bridge6Cidr} allow"
        ];
        aggressive-nsec = true;
        do-ip6 = false;
        module-config = ''"validator python iterator"'';
        local-zone = ''"local." static'';
        local-data = [
          ''"local. A ${router4}"''
          ''"local. AAAA ${router6}"''
          ''"router.local. A ${router4}"''
          ''"router.local. AAAA ${router6}"''
          ''"mumble.local. A ${router4}"''
          ''"mumble.local. AAAA ${router6}"''
          ''"print.local. A ${router4}"''
          ''"print.local. AAAA ${router6}"''
          ''"printer.local. A ${router4}"''
          ''"printer.local. AAAA ${router6}"''
        ];
      };
      python.python-script = toString (pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/NLnetLabs/unbound/a912786ca9e72dc1ccde98d5af7d23595640043b/pythonmod/examples/avahi-resolver.py";
        sha256 = "0r1iqjf08wrkpzvj6pql1jqa884hbbfy9ix5gxdrkrva09msiqgi";
      });
      remote-control.control-enable = true;
    };
  };

  networking.wireguard.interfaces.wg0 = {
    ips = wgIps;
    peers = [{
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
      publicKey = wgPubKey;
      endpoint = wgEndpoint;
      persistentKeepalive = 60;
    }];
    socketNamespace = "wan";
    interfaceNamespace = "vpn";
    privateKeyFile = wgKeyFile;
    postSetup = with pkgs; ''
      ${iproute2}/bin/ip netns exec vpn ${procps}/bin/sysctl net.ipv4.conf.wg0.rp_filter=1
      ${iproute2}/bin/ip netns exec vpn ${procps}/bin/sysctl net.ipv4.conf.wg0.src_valid_mark=1
    '';
  };

  systemd.services = {
    ping-ipv4 = {
      after = [ "network.target" "network-online.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.iputils}/bin/ping ${vpnGate4}";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
    ping-ipv6 = {
      after = [ "network.target" "network-online.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.iputils}/bin/ping ${vpnGate6}";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
    network-addresses-wan0 = {
      bindsTo = lib.mkForce [ wan0PciService ];
      serviceConfig.NetworkNamespacePath = "/var/run/netns/wan";
    };
    unbound.environment.MDNS_ACCEPT_NAMES = "^.*\.local\.$";
    wan-nftables = {
      after = [ "network.target" "network-online.target" ];
      requires = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
      unitConfig = {
        StopWhenUnneeded = true;
      };
      serviceConfig =
        let setRules = with pkgs;
          let config = writeTextFile {
            name = "nftables-wan";
            text = nftablesConfig bridge4Cidr bridge6Cidr [wanGate4] [wanGate6] "wan0" [ "veth-wan-b" ] ''
              chain prerouting_nat {
                type nat hook prerouting priority 0;
                ip saddr 127.0.0.1 meta l4proto { tcp, udp } th dport { 53, 853 } dnat to ${bridge4}
                ip6 saddr ::1 meta l4proto { tcp, udp } th dport { 53, 853 } dnat to ${bridge6}
              }
            '' null null "iifname wan0 oifname veth-wan-b accept";
          };
          in writeScript "nftables-rules-wan" ''
            #! ${nftables}/bin/nft -f
            flush ruleset
            include "${config}"
          '';
      in {
        Type = "oneshot";
        RemainAfterExit = true;
        NetworkNamespacePath = "/var/run/netns/wan";
        ExecStart = setRules;
        ExecReload = setRules;
      };
    };
    vpn-nftables = {
      after = [ "network.target" "network-online.target" "wireguard-wg0.service" ];
      requires = [ "network-online.target" "wireguard-wg0.service" ];
      wantedBy = [ "default.target" ];
      unitConfig = {
        StopWhenUnneeded = true;
      };
      serviceConfig =
        let setRules = with pkgs;
          let config = writeTextFile {
            name = "nftables-vpn";
            text = nftablesConfig bridge4Cidr bridge6Cidr [vpnGate4] [vpnGate6] "wg0" [ "veth-vpn-b" ] ''
              chain prerouting_nat {
                type nat hook prerouting priority 0;
                ip saddr 127.0.0.1 meta l4proto { tcp, udp } th dport { 53, 853 } dnat to ${bridge4}
                ip6 saddr ::1 meta l4proto { tcp, udp } th dport { 53, 853 } dnat to ${bridge6}
              }
            '' null null "iifname wg0 oifname veth-vpn-b accept";
          };
          in writeScript "nftables-rules-vpn" ''
            #! ${nftables}/bin/nft -f
            flush ruleset
            include "${config}"
          '';
      in {
        Type = "oneshot";
        RemainAfterExit = true;
        NetworkNamespacePath = "/var/run/netns/vpn";
        ExecStart = setRules;
        ExecReload = setRules;
      };
    };
    dhcpcd.serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/wan";
      PIDFile = lib.mkForce "/run/dhcpcd-wan0.pid";
      ExecStart =
        let config = builtins.toFile "dhcpcd.conf" ''
          hostname
          option domain_name_servers, domain_name, domain_search, host_name
          option classless_static_routes, ntp_servers, interface_mtu
          nohook lookup-hostname
          denyinterfaces lan0 ve-* vb-* lo peth* vif* tap* tun* virbr* vnet* vboxnet* sit*
          allowinterfaces wan0
          waitip
        '';
        in lib.mkForce "@${pkgs.dhcpcd}/sbin/dhcpcd dhcpcd --quiet  --config ${config} wan0";
    };
    custom-network-setup-2 = {
      description = "custom network setup 2";
      wantedBy = [ "network.target" ];
      after = [ "network-addresses-lan0.service" ];
      unitConfig = {
        StopWhenUnneeded = true;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = with pkgs; writeScript "custom-network-setup-2-start" ''
          #! ${bash}/bin/bash
          ${iproute2}/bin/ip -4 route add default via ${vpnGate4} table vpn_table
          ${iproute2}/bin/ip -6 route add default via ${vpnGate6} table vpn_table
          ${iproute2}/bin/ip -4 route add ${bridge4Cidr} dev br0 proto kernel scope link src ${bridge4} table vpn_table
          ${iproute2}/bin/ip -6 route add ${bridge6Cidr} dev br0 proto kernel metric 256 pref medium table vpn_table

          ${iproute2}/bin/ip -4 route add default via ${wanGate4} table wan_table
          ${iproute2}/bin/ip -6 route add default via ${wanGate6} table wan_table
          ${iproute2}/bin/ip -4 route add ${bridge4Cidr} dev br0 proto kernel scope link src ${bridge4} table wan_table
          ${iproute2}/bin/ip -6 route add ${bridge6Cidr} dev br0 proto kernel metric 256 pref medium table wan_table

          ${iproute2}/bin/ip -4 route add ${lan4Cidr} dev lan0 proto kernel scope link src ${router4} table vpn_table
          ${iproute2}/bin/ip -6 route add ${lan6Cidr} dev lan0 proto kernel metric 256 pref medium table vpn_table
          ${iproute2}/bin/ip -4 route add ${lan4Cidr} dev lan0 proto kernel scope link src ${router4} table wan_table
          ${iproute2}/bin/ip -6 route add ${lan6Cidr} dev lan0 proto kernel metric 256 pref medium table wan_table

          ${iproute2}/bin/ip -4 route add default via ${vpnGate4}
          ${iproute2}/bin/ip -6 route add default via ${vpnGate6}
        '';
        ExecStop = with pkgs; writeScript "custom-network-setup-2-stop" ''
          #! ${bash}/bin/bash
          ${iproute2}/bin/ip -4 route del default via ${vpnGate4}
          ${iproute2}/bin/ip -6 route del default via ${vpnGate6}
        '';
      };
    };
    custom-network-setup-1 = {
      description = "custom network setup 1";
      before = [ "nftables.service" "custom-nftables.service" "wireguard-wg0.service" "dhcpcd.service" "custom-network-setup-2.service" ];
      wantedBy = [ "network.target" ];
      unitConfig = {
        StopWhenUnneeded = true;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = with pkgs; writeScript "custom-network-setup-start" ''
          #! ${bash}/bin/bash
          ${iproute2}/bin/ip netns add vpn
          ${iproute2}/bin/ip netns add wan
          ${iproute2}/bin/ip link set wan0 netns wan

          ${iproute2}/bin/ip link add br0 type bridge
          ${iproute2}/bin/ip link set br0 up
          ${iproute2}/bin/ip addr add ${bridge4}/${bridge4Bits} dev br0
          ${iproute2}/bin/ip addr add ${bridge6}/${bridge6Bits} dev br0

          ${iproute2}/bin/ip link add veth-vpn-a type veth peer name veth-vpn-b
          ${iproute2}/bin/ip link set veth-vpn-a master br0 up
          ${iproute2}/bin/ip link set veth-vpn-b netns vpn
          ${iproute2}/bin/ip netns exec vpn ${iproute2}/bin/ip link set veth-vpn-b up
          ${iproute2}/bin/ip netns exec vpn ${iproute2}/bin/ip addr add ${vpnGate4}/${bridge4Bits} dev veth-vpn-b
          ${iproute2}/bin/ip netns exec vpn ${iproute2}/bin/ip addr add ${vpnGate6}/${bridge6Bits} dev veth-vpn-b

          ${iproute2}/bin/ip link add veth-wan-a type veth peer name veth-wan-b
          ${iproute2}/bin/ip link set veth-wan-a master br0 up
          ${iproute2}/bin/ip link set dev veth-wan-b netns wan
          ${iproute2}/bin/ip netns exec wan ${iproute2}/bin/ip link set veth-wan-b up
          ${iproute2}/bin/ip netns exec wan ${iproute2}/bin/ip addr add ${wanGate4}/${bridge4Bits} dev veth-wan-b
          ${iproute2}/bin/ip netns exec wan ${iproute2}/bin/ip addr add ${wanGate6}/${bridge6Bits} dev veth-wan-b

          ${iproute2}/bin/ip rule add fwmark 1 table wan_table
          ${iproute2}/bin/ip rule add fwmark 2 table vpn_table

          ${iproute2}/bin/ip netns exec wan ${procps}/bin/sysctl net.ipv4.conf.wan0.rp_filter=1
          ${iproute2}/bin/ip netns exec wan ${procps}/bin/sysctl net.ipv4.conf.wan0.src_valid_mark=1
          ${iproute2}/bin/ip netns exec wan ${procps}/bin/sysctl net.ipv4.conf.all.forwarding=1
          ${iproute2}/bin/ip netns exec wan ${procps}/bin/sysctl net.ipv6.conf.all.forwarding=1
          ${iproute2}/bin/ip netns exec vpn ${procps}/bin/sysctl net.ipv4.conf.all.forwarding=1
          ${iproute2}/bin/ip netns exec vpn ${procps}/bin/sysctl net.ipv6.conf.all.forwarding=1
        '';
        ExecStop = with pkgs; writeScript "custom-network-setup-start" ''
          #! ${bash}/bin/bash
          ${iproute2}/bin/ip rule del fwmark 1 table wan_table
          ${iproute2}/bin/ip rule del fwmark 2 table vpn_table
          ${iproute2}/bin/ip netns exec vpn ${iproute2}/bin/ip link del veth-wan-b
          ${iproute2}/bin/ip link del veth-wan-a
          ${iproute2}/bin/ip netns exec vpn ${iproute2}/bin/ip link del veth-vpn-b
          ${iproute2}/bin/ip link del veth-vpn-a
          ${iproute2}/bin/ip link del br0
          ${iproute2}/bin/ip netns exec wan ${iproute2}/bin/ip link set wan0 netns 1
          ${iproute2}/bin/ip netns del wan
          ${iproute2}/bin/ip netns del vpn
        '';
      };
    };
    update-rkn-blacklist = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = updateRknBlacklist;
      };
    };
  };
  systemd.timers.update-rkn-blacklist = {
    wantedBy = [ "timers.target" ];
    partOf = [ "update-rkn-blacklist.service" ];
    # slightly unusual time to reduce server load
    timerConfig.OnCalendar = [ "*-*-* *:00:20" ];
  };

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    allowFrom = [ "localhost" lan4Cidr lan6Cidr ];
    browsing = true;
    clientConf = ''
      ServerName router.local
    '';
    defaultShared = true;
    drivers = [ pkgs.hplip ];
    startWhenNeeded = false;
  };
  services.nginx = {
    enable = true;
    virtualHosts = {
      "printer.local".locations."/".proxyPass = "http://localhost:631";
      "print.local".locations."/".proxyPass = "http://localhost:631";
      "mumble.local".locations."/".proxyPass = "http://localhost:8181";
    };
  };

  users.defaultUserShell = pkgs.fish;
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" config.services.unbound.group ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    nftables
    rxvt_unicode.terminfo
    tmux
    bind
  ];

  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
  };

  services.fail2ban = {
    enable = true;
    packageFirewall = pkgs.nftables;
    banaction = "nftables-multiport";
    banaction-allports = "nftables-allport";
  };

  boot.kernelParams = [ "consoleblank=60" ];

  system.stateVersion = "21.11";
}


{ lib, ... }
:
{
  options.publicIp = lib.mkOption {
    type = with lib.types; uniq string;
    description = "The server's public IP address";
  };
  options.txtRecords = lib.mkOption {
    type = with lib.types; attrsOf (listOf string);
    description = "TXT records to add into the zone file";
  };
}

{ ... }: {
  # This file is mostly used for secrets, so most of it is omitted
  networking.hostName = "<hostname>";
  networking.domain = "pavluk.org";
  nixpkgs.overlays = [(self: super: {
    pineapplebot = with super; with super.lib; super.python3Packages.buildPythonPackage rec {
      pname = "pineapplebot";
      version = "0.1.0";
      src = fetchFromGitHub {
        owner = "chayleaf";
        repo = "pizzabot_v3";
        rev = "master";
        sha256 = "1421criy7w0x3ma8g8ip2ws8y42v92hdd7x27jylkqax3zwl0vc2";
      };
      sourceRoot = "source/pineapplebot";
      cargoDeps = rustPlatform.fetchCargoTarball {
        inherit src sourceRoot;
        name = "${pname}-${version}";
        sha256 = "14jxgykwg1apy97gy1j8mz7ny2cqg4q9s03a2bk9kx2y6ibm4668";
      };
      nativeBuildInputs = with rustPlatform; [
        cargoSetupHook
        maturinBuildHook
      ];
      doCheck = false;
      doInstallCheck = true;
      pythonImportsCheck = [ "pineapplebot" ];
      PIZZABOT_MAGIC = "THIS_WILL_BE_USED_AS_OWN_MESSAGE_MARKER";
    };
  })];
}

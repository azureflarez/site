{ lib, nixosTests, python3, python3Packages, fetchFromGitHub, fetchpatch }:

with python3Packages;

toPythonModule (buildPythonApplication rec {
  pname = "searxng";
  version = "1.0.0";

  # pypi doesn't receive updates
  src = fetchFromGitHub {
          owner = "searxng";
          repo = "searxng";
          rev = #"f0c77a91d18ff1639f31f930bec34d544ba592c8";
                 "96ab5e57ff92aba4ab0fedeb4e5fbfa09e9fc2e2";
          sha256 = #"0463afnns59jzfllbswphspn5gbpmkv2da4b3h00n8ydwd5fp567";
                    "0is86gp91pc6s7xdd5jjxk8f193ycmvy7qmd0avxby8nsr5wjdvk";
  };

  postPatch = ''
    sed -i 's/==.*$//' requirements.txt
  '';

  preBuild = ''
    export SEARXNG_DEBUG="true";
  '';

  propagatedBuildInputs = [

        setproctitle uvloop httpx-socks async-timeout
    Babel
    certifi
    python-dateutil
    flask
    flaskbabel
    gevent
    grequests
    jinja2
    langdetect
    lxml
    ndg-httpsclient
    pyasn1
    pyasn1-modules
    pygments
    pysocks
    pytz
    pyyaml
    requests
    speaklater
    werkzeug
  ];

  # tests try to connect to network
  doCheck = false;

  pythonImportsCheck = [ "searx" ];

  postInstall = ''
    # Create a symlink for easier access to static data
    mkdir -p $out/share
    ln -s ../${python3.sitePackages}/searxng/static $out/share/
  '';
})

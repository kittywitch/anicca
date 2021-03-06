{ lib, figlet, lolcat, writeShellScriptBin }: { node }:

with lib;

let
  fileStructure = path:
    let
      splitPath = splitString "/" path;
      reversedPath = reverseList splitPath;
    in
    {
      folder = "${concatStringsSep "/" (reverseList (tail reversedPath))}";
      filename = head reversedPath;
      inherit path;
    };
  persistHelper = { values, location }: concatLists (attrValues (
    mapAttrs
      (persist: pathList: map
        (path: {
          from = fileStructure "${optionalString (location != "") "${location}/"}${path}";
          to = fileStructure "${persist}${if location != "" then "/${path}" else "${path}"}";
        })
        pathList
      )
      values));
  attrs = [ "directories" "files" ];
  multiHelper = { location ? "", persistence }: genAttrs attrs (key:
    persistHelper {
      values = mapAttrs (_: v: v.${key}) persistence;
      inherit location;
    }
  );
  genCreator = { paths, isFiles ? false }: concatStringsSep "\n" (map
    (path: ''
      mkdir -pv ${if isFiles then path.to.folder else path.to.path}
      if [[ -${if isFiles then "f" else "d"} "${path.from.path}" ]]; then
        cp -v${optionalString (!isFiles) "r"} ${path.from.path} ${path.to.path}
      else
        echo -e "'${path.from.path}' -/-> '${path.to.path}'"
        ${optionalString isFiles ''
        touch ${path.to.path}
        echo -e "touched: ${path.to.path}"
          ''}
      fi'')
    paths);
  persistence = {
    root = multiHelper { inherit (node.environment) persistence; };
    users = mapAttrs (_: user: multiHelper { inherit (user.home) persistence; location = user.home.homeDirectory; }) node.home-manager.users;
  };
  summarySection = { section, isFiles ? false }: ''
    ${concatStringsSep "\n" (map (path: ''
      if [[ -${if isFiles then "f" else "d"} "${path.from.path}" ]]; then
        echo -e " ~ '${path.from.path}' -> '${path.to.path}'"
      else
        echo -e " + '${path.to.path}'"
      fi
    '') section)}
  '';
  summaryGen = { scope, persist }: ''
    echo -e "''${BLUE}Summary for ${scope}:''${NOCOLOR}\n"
  ''
  + (if length persist.directories > 0 then ''
    echo -e "''${CYAN}Directories:''${NOCOLOR}"
    ${summarySection { section = persist.directories; }}
  '' else ''
    echo -e "''${ORANGE}<!> No directories set.''${NOCOLOR}"
  '') + ''
    echo ""
  '' + (if length persist.files > 0 then ''
    echo -e "''${CYAN}Files:''${NOCOLOR}"
    ${summarySection { section = persist.files; isFiles = true; }}
  '' else ''
    echo -e "''${ORANGE}<!> No files set.''${NOCOLOR}"
  '') + ''echo -e ""'';
  summaries = {
    root = summaryGen {
      scope = "NixOS";
      persist = persistence.root;
    };
    users = mapAttrs
      (username: persist: summaryGen {
        scope = "home-manager/${username}";
        inherit persist;
      })
      persistence.users;
  };
  scripts = {
    root = genAttrs attrs (attr: genCreator { paths = persistence.root.${attr}; isFiles = (attr == "files"); });
    users = mapAttrs
      (username: persist:
        let self = genAttrs attrs (attr: genCreator { paths = persist.${attr}; isFiles = (attr == "files"); }) // {
          runner = ''
            STAGE=$(($STAGE+1))
            echo -e "\n''${CYAN}Stage $STAGE: home-manager/${username} - Directories''${NOCOLOR}"
            ${self.directories}
            STAGE=$((STAGE+1))
            echo -e "\n''${CYAN}Stage $STAGE: home-manager/${username} - Files''${NOCOLOR}"
            ${self.files}
          '';
        }; in self)
      persistence.users;
  };
in
writeShellScriptBin "anicca-${node.networking.hostName}" ''
  NOCOLOR='\033[0m'
  GREEN='\033[0;32m'
  ORANGE='\033[0;33m'
  BLUE='\033[0;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[0;36m'
  COLS=$(tput cols)
  ${figlet}/bin/figlet -w $COLS  -c anicca | ${lolcat}/bin/lolcat -f  -p 0.5
  SUBTITLE="A helper for transitioning to impermanence."
  printf "%b%*s\n\n" ''${PURPLE} $(((''${#SUBTITLE}+$COLS)/2)) "$SUBTITLE"
  ${summaries.root}
  ${concatStringsSep "\n" (attrValues summaries.users)}
  echo -e "''${ORANGE}Are you sure you have everything in order? Type 'yes' if you are sure.''${NOCOLOR}"
  while true; do
    read -p "> " yn
    case $yn in
      [Yy]es) break;;
      * ) exit;;
    esac
  done
  echo -e "\n''${GREEN}Continue signal given. Waiting 5 seconds.''${NOCOLOR}"
  sleep 5
  echo -e "\n''${CYAN}Stage 1: NixOS - Directories''${NOCOLOR}"
  ${scripts.root.directories}
  echo -e "\n''${CYAN}Stage 2: NixOS - Files''${NOCOLOR}"
  ${scripts.root.files}
  STAGE=2
  ${concatStringsSep "\n" (map (user: user.runner) (attrValues scripts.users))}
''

{ lib, figlet, lolcat, writeShellScriptBin }: { node }:

with lib;

let
  fileStructure = path:
    let
      splitPath = splitString "/" path;
      reversedPath = reverseList splitPath;
      filename = head reversedPath;
      folder = "${concatStringsSep "/" (reverseList (tail reversedPath))}";
    in
    {
      inherit filename folder path;
    };
  persistHelper = { values, location }: concatLists (attrValues (
    mapAttrs
      (persist: pathList: map
        (path: {
          from = fileStructure "${if location != "" then "${location}/" else ""}${path}";
          to = fileStructure "${persist}${if location != "" then "/${path}" else "${path}"}";
        })
        pathList
      )
      values));
  multiHelper = { location ? "", persistence }: genAttrs [ "directories" "files" ] (key:
    persistHelper {
      values = mapAttrs (_: v: v.${key}) persistence;
      inherit location;
    }
  );
  dirCreator = dirs: concatStringsSep "\n" (map
    (dir: ''
      mkdir -pv ${dir.to.path}
      if [[ -d "${dir.from.path}" ]]; then
        cp -v ${dir.from.path} ${dir.to.path}
      else
        echo -e "'${dir.from.path}' -/-> '${dir.to.path}'"
      fi'')
    dirs);
  fileCreator = files: concatStringsSep "\n" (map
    (file: ''
      mkdir -pv ${file.to.folder}
      if [[ -f "${file.from.path}" ]]; then
        cp ${file.from.path} ${file.to.folder}
      else
        echo -e "'${file.from.path}' -/-> '${file.to.path}'"
        touch ${file.to.path}
        echo -e "touched: ${file.to.path}"
      fi
    '')
    files);
  persistence = {
    root = multiHelper { inherit (node.environment) persistence; };
    users = mapAttrs (_: v: multiHelper { inherit (v.home) persistence; location = v.home.homeDirectory; }) node.home-manager.users;
  };
  summaryGen = { scope, persist }:
    let
    in
    ''
      echo -e "''${BLUE}Summary for ${scope}:''${NOCOLOR}\n"
    ''
    + (if length persist.directories > 0 then ''
      echo -e "''${CYAN}Directories:''${NOCOLOR}"
      ${concatStringsSep "\n" (map (dir: ''
        if [[ -d "${dir.from.path}" ]]; then
          echo -e " ~ '${dir.from.path}' -> '${dir.to.path}'"
        else
          echo -e " + '${dir.to.path}'"
        fi
      '') persist.directories)}
    '' else ''
      echo -e "''${ORANGE} ! No directories set.''${NOCOLOR}"
    '')
    + (if length persist.files > 0 then ''
      echo -e "''${CYAN}Files:''${NOCOLOR}"
          ${concatStringsSep "\n" (map (file: ''
          if [[ -f "${file.from.path}" ]]; then
            echo -e " ~ '${file.from.path}' -> '${file.to.folder}'"
          else
            echo -e " + '${file.to.path}'"
          fi
        '') persist.files)}
    '' else ''
      echo -e "''${ORANGE} ! No files set.''${NOCOLOR}"
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
    root = {
      directories = dirCreator persistence.root.directories;
      files = fileCreator persistence.root.files;
    };
    users = mapAttrs
      (username: persist: rec {
        directories = dirCreator persist.directories;
        files = fileCreator persist.files;
        runner = ''
          STAGE=$(($STAGE+1))
          echo -e "\n''${CYAN}Stage $STAGE: home-manager/${username} - Directories''${NOCOLOR}"
          ${directories}
          STAGE=$((STAGE+1))
          echo -e "\n''${CYAN}Stage $STAGE: home-manager/${username} - Files''${NOCOLOR}"
          ${files}
        '';
      })
      persistence.users;
  };
in
writeShellScriptBin "anicca-${node.networking.hostName}" ''
  NOCOLOR='\033[0m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  ORANGE='\033[0;33m'
  BLUE='\033[0;34m'
  PURPLE='\033[0;35m'
  CYAN='\033[0;36m'
  LIGHTGRAY='\033[0;37m'
  DARKGRAY='\033[1;30m'
  LIGHTRED='\033[1;31m'
  LIGHTGREEN='\033[1;32m'
  YELLOW='\033[1;33m'
  LIGHTBLUE='\033[1;34m'
  LIGHTPURPLE='\033[1;35m'
  LIGHTCYAN='\033[1;36m'
  WHITE='\033[1;37m'
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

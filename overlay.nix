self: super: let
  pkgs' = import ./pkgs;
  pkgs = builtins.mapAttrs (_: pkg: self.callPackage pkg {}) pkgs';
in pkgs

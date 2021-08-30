{ config, lib, ... }: with lib;

{
  options.anicca = {
    enabled = mkOption {
      type = types.bool;
      readOnly = true;
      description = "Is persistence enabled?";
      default = config.environment.persistence != {};
    };
  };
}

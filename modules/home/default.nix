{
  enabler = ./enabler.nix;

  __functionArgs = {};
  __functor = self: { ... }: {
    imports = with self; [
      enabler
    ];
  };
}

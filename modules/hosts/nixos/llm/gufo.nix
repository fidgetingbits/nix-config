{
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.llama-swap;
in
lib.mkIf cfg.withGufo {

}

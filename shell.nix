# Shell for bootstrapping flake-enabled nix and other tooling
{
  pkgs ?
    # If pkgs is not defined, instanciate nixpkgs from locked commit
    let
      lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
      nixpkgs = fetchTarball {
        url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
        sha256 = lock.narHash;
      };
    in
    import nixpkgs { overlays = [ ]; },
  checks,
  ...
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    NIXPKGS_ALLOW_BROKEN = "1";
    BOOTSTRAP_USER = "aa";
    BOOTSTRAP_SSH_PORT = "10022";
    BOOTSTRAP_SSH_KEY = "~/.ssh/id_yubikey";
    buildInputs = checks.pre-commit-check.enabledPackages;
    nativeBuildInputs = builtins.attrValues {
      inherit (pkgs)
        nix
        home-manager
        git
        just
        pre-commit
        alejandra
        sops
        deadnix
        statix
        git-crypt # encrypt secrets in git not suited for sops
        attic-client # for attic backup
        nh # fancier nix building
        yq-go # jq for yaml, used for build scripts
        flyctl # for fly.io
        bats # for testing
        age # bootstrap script
        ssh-to-age # bootstrap script
        ;
    };
    shellHook =
      checks.pre-commit-check.shellHook or ""
      + ''
        # If we don't already have a .git-crypt.key file and have a git-crypt secret exposed via sops,
        # then decode a copy and place it in the repo
        if [ ! -f .git-crypt.key ] && [ -f ~/.config/sops-nix/secrets/keys/git-crypt ]; then
            base64 -d ~/.config/sops-nix/secrets/keys/git-crypt > .git-crypt.key
            git-crypt unlock .git-crypt.key
        fi

        # Setup fly token if the secret exists
        if [ -f ~/.config/sops-nix/secrets/tokens/fly ]; then
            export FLY_ACCESS_TOKEN=$(cat ~/.config/fly.io/token)
        fi

        hostname_lock="locks/$(hostname).lock"
        if [ ! -f $hostname_lock ]; then
            nix flake update --reference-lock-file $hostname_lock
            git add $hostname_lock
            echo "Created a new lock file at $hostname_lock"
        fi

        # If we don't already have a flake.lock file setup, try to initialize it
        if [ ! -f flake.lock ]; then
            ln -f locks/$(hostname).lock flake.lock
            git --intent-to-add flake.lock
        fi

        if git remote -v | grep gitlab; then
            echo "WARNING: Your git remote is still the old gitlab URL, switch to the new public github repo"
        fi
      '';
  };
}

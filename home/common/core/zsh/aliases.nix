let
  devFolder = "~/dev";
  devTalon = "${devFolder}/talon";
  devNix = "${devFolder}/nix";
in
{
  whichreal = ''function _whichreal(){ (alias "$1" >/dev/null 2>&1 && (alias "$1" | sed "s/.*=.\(.*\).../\1/" | xargs which)) || which "$1"; }; _whichreal'';
  edit = "code -w";
  less = "bat --style=plain";
  cat = "bat --paging=never";
  ldt = "eza -TD"; # list directory tree
  tree = "eza -T";
  gdb = "gdb -q";
  rg = "rg -M300";
  du = "dust";
  # FIXME: Switch this to a function since you always do 'df -h'
  df = "duf";
  calc = "eva";
  c = "clear";
  hd = "hexyl --border none";
  hexdump = "hexyl --border none";
  # Path to real rm and rmdir in coreutils. This is so we can not use rmtrash for big files
  rrm = "/run/current-system/sw/bin/rm";
  rrmdir = "/run/current-system/sw/bin/rmdir";
  rm = "rmtrash";
  rmdir = "rmdirtrash";
  journactl = "journalctl --no-pager";
  unzip = "7z x";
  genpasswd = "bw generate --words 5 --includeNumber --ambiguous --separator '-' -p -c";
  # file searching
  fdi = "fd -I"; # fd with --no-ignore
  biggest = "find . -printf '%s %p\n'|sort -nr|head";
  myip = "dig +short myip.opendns.com @resolver1.opendns.com";

  # git
  gcm = "git commit -m";
  gcmcf = "git commit -m 'chore: update flake.lock'";
  gca = "git commit --amend";
  gcan = "git commit --amend --no-edit";
  gcam = "git commit --amend -m";

  # We use source because we want it to use other aliases, which allow yubikey signing over ssh
  gsr = "git_smart_rebase";
  grst = "git reset --soft ";

  gr = "git restore";
  gra = "git restore :/";
  grs = "git restore --staged";
  grsa = "git restore --staged :/";

  ga = "git add";
  # "git add again" - Re-add changes for anything that was already staged. Useful for pre-commit changes, etc
  gaa = "git update-index --again";
  gau = "git add --update";
  # Only add updates to files that are already staged
  gas = "git add --update $(git diff --name-only --cached)";
  gs = "git status --untracked-files=no";
  gsa = "git status";
  gst = "git stash";
  gstp = "git stash pop";
  gsw = "git switch";
  gswc = "git switch -c";
  gco = "git checkout";
  gf = "git fetch";
  gfa = "git fetch --all";
  gfu = "git fetch upstream";
  gfm = "git fetch origin master";
  gds = "git diff --staged";
  gd = "git diff";
  gp = "git push";
  gpf = "git push --force-with-lease";
  gl = "git log";
  gc = "git clone";

  # FIXME: Could be devshell specific for nix-config
  bump = "bump_lock";

  # lsusb
  lsusb = "cyme --tree";

  # nix
  nr = "nix run .";
  nri = "nix run . --impure";
  nfu = "nix flake update";
  nfui = "nix flake lock --update-input";
  nfm = "nix flake metadata";
  nbp = "nix-build -E 'with import <nixpkgs> {}; pkgs.callPackage ./package.nix {}'"; # nbp: nix build package
  nrp = "nix run -E 'with import <nixpkgs> {}; pkgs.callPackage ./package.nix {}'"; # nrp: nix run package
  nswp = "nix shell nixpkgs#"; # nsw: nix shell with package
  nlg = "sudo nix profile history --profile /nix/var/nix/profiles/system";
  ncs = "REPO_PATH=$PWD nh os switch --no-nom . -- --impure"; # ncs = nix config switch
  nrepl = ''
    nix repl --option experimental-features "pipe-operators" \
    --expr 'rec { pkgs = import <nixpkgs>{}; lib = pkgs.lib; }'
  '';

  dmesg = "sudo dmesg -H";
  # finding
  t = "tree";

  # processes
  p = "ps -ef";
  pg = "ps -ef | rg -i";
  k = "kill";
  k9 = "kill -9";
  kf = "ps -e | fzf | awk '{print $1}' | xargs kill";

  h = "history";

  # folders

  # Directory convenience
  ".h" = "cd ~"; # Because I find pressing ~ tedious"
  cdr = "cd-gitroot";
  ".r" = "cd-gitroot";
  cdpr = "..; cd-gitroot";
  "..r" = "..; cd-gitroot";

  zf = "cdf"; # Fuzzy jump to folder of file under tree
  zd = "cdd"; # Fuzzy jump to directory under tree

  ## talon
  ctc = "cd ${devTalon}/fidgetingbits-talon";
  ctp = "cd ${devTalon}/private";
  cnt = "cd ${devTalon}/neovim-talon";
  ctn = "cd ${devTalon}/talon.nvim";
  ccn = "cd ${devTalon}/cursorless.nvim";
  ccl = "cd ${devTalon}/cursorless";
  ## nix
  cnc = "cd ${devNix}/nix-config";
  cnn = "cd ${devNix}/nixCats-example";
  cns = "cd ${devNix}/nix-secrets";
  cnh = "cd ${devNix}/nixos-hardware";
  cnp = "cd ${devNix}/nixpkgs";

  ## rust cargo
  cr = "cargo run";
  ch = "cargo help";
  cb = "cargo build";
  cbr = "cargo build --release";
  ct = "cargo test";
  cf = "cargo fmt";

  # justfiles
  j = "just";
  # FIXME: These should be devshell-specific aliases for nix-config
  jr = "just rebuild";
  jrt = "just rebuild-trace";
  jl = "just --list";
  jup = "just update";
  jug = "just upgrade";
  jb = "just build-host";

  # direnv
  da = "direnv allow";
  dr = "direnv reload";

  # prevent accidental killing of single characters
  pkill = "pkill -x";

  # easy disassembly
  dis-aarch64 = "r2 -q -a arm -b 64 -c 'pD'";
  dis-arm = "r2 -q -a arm -b 32 -c 'pD'";
  dis-x64 = "r2 -q -a x86 -b 64 -c 'pD'";
  dis-x86 = "r2 -q -a x86 -b 32 -c 'pD'";

  # systemctl services
  # NOTE: this kind of overlaps already with lots of sc-xxx aliases, so maybe revist
  s = "systemctl";
  sst = "systemctl status";
  sus = "systemctl --user status";
  sl = "systemctl list-units --type=service";
  sla = "systemctl list-units --all";
  sul = "systemctl --user list-units --type=service";
  sula = "systemctl --user list-units --all";
  sr = "systemctl restart";
  sur = "systemctl --user restart";

  # journalctl
  jc = "journalctl";
  jcu = "journalctl --user";

  # ssh
  sshnc = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"; # sshnc = ssh no checks
  scpnc = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"; # scpnc = scp no checks
  # Helper if haven't set up explicit host entry
  ssh-unlock = "ssh -i~/.ssh/id_yubikey -oUserKnownHostsFile=/dev/null -oGlobalKnownHostsFile=/dev/null -oport=10022 -lroot";

  # Force alias use with xargs
  # https://unix.stackexchange.com/questions/141367/have-xargs-use-alias-instead-of-binary/244516#244516
  xargs = "xargs ";

  # quick execution of any alias I forget
  kyd = "alias | fzf --height=50% --layout=reverse --info=inline --border --preview 'echo {}' --preview-window=up:3:hidden:wrap --bind '?:toggle-preview' | cut -d'=' -f1 | xargs -I {} zsh -c '{}'";

  # Sometimes touchpad stops working and it seems like cycling this option fixes it
  kb-reset = "sudo modprobe -r hid_multitouch && sudo modprobe hid_multitouch";
}

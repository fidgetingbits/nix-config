# Core home functionality that will only work on Linux
{
  ...
}:
{
  home = {
    # FIXME: These need to be per the user being added to HM for multi-user systems
    # Needs to mvoe to per-user common files
    homeDirectory = "/home/media";
    username = "media";
  };
}

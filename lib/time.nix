# Could somehow integrate, which looks nice
# https://github.com/sivizius/nixfiles/blob/development/libs/core/lib/time/default.nix
rec {
  secondsPerMin = 60;
  secondsPerHour = 60 * secondsPerMin;
  secondsPerDay = 24 * secondsPerHour;
  secondsPerWeek = 7 * secondsPerDay;
  secondsPerYear = 365 * secondsPerDay;

  minutes = n: secondsPerMin * n;
  hours = n: secondsPerHour * n;
  days = n: secondsPerDay * n;
}

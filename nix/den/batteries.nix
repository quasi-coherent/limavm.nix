{ ... }:
{
  # Syntactic sugar that is probably rarely useful.
  den.batteries.toLimaHost = settings: { enable = true; } // settings;
}

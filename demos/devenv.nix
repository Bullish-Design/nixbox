{ ... }:
{
  nixbox.enable = true;
  # The dev addon: provides `nixbox-demo` (headless-browser GIF capture).
  nixbox.playwright.enable = true;
}

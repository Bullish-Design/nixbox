# The importable nixbox devenv module lives at modules/devenv.nix.
# See that file for the actual implementation.
#
# Usage in a repo's devenv.yaml:
#
#   inputs:
#     nixbox:
#       url: path:../nixbox/modules
#       flake: false
#   imports:
#     - nixbox
#
# then set `nixbox.enable = true;` in devenv.nix.
import ./modules/devenv.nix

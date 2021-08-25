# anicca
A helper for transitioning to impermanence

## Pre-requisites
* The use of the impermanence module for NixOS and home-manager.
* Set up dataset(s) or partition(s) for /persist.

## Examples

`nix run -f . pkgs.anicca --arg node "(with import ./.; network.nodes.samhain)" -c anicca-samhain`

![An example of usage](./example/screenshot.png)

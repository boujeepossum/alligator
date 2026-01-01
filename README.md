# WireGuard VPN Server

- Get a droplet on DO
- copy private deploy key to ~/.ssh/deploy_key
- chmod 600 ./deploy_key
- apt update && apt install -y git
- GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key" git clone git@github.com:boujeepossum/alligator.git ~/alligator
- cd ~/alligator && sudo ./setup.sh

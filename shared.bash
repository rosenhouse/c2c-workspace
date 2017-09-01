#!/usr/bin/env bash

function main() {
  function setup_aliases() {
    alias vim=nvim
    alias vi=nvim
    alias ll="ls -al"
    alias be="bundle exec"
    alias bake="bundle exec rake"
    alias drm='docker rm $(docker ps -a -q)'
    alias drmi='docker rmi $(docker images -q)'

    #git aliases
    alias gst="git status"
    alias gd="git diff"
    alias gap="git add -p"
    alias gup="git pull -r"
    alias gp="git push"
    alias ga="git add"
  }

  function setup_environment() {
    export CLICOLOR=1
    export LSCOLORS exfxcxdxbxegedabagacad

    # go environment
    export GOPATH=$HOME/go
    export GOBIN=$GOPATH/bin

    # git duet config
    export GIT_DUET_GLOBAL=true
    export GIT_DUET_ROTATE_AUTHOR=1

    # setup path
    export PATH=$GOBIN:$PATH:/usr/local/go/bin

    export EDITOR=nvim
  }

  function setup_rbenv() {
    eval "$(rbenv init -)"
  }

  function setup_aws() {
    # set awscli auto-completion
    complete -C aws_completer aws
  }

  function setup_fasd() {
    local fasd_cache
    fasd_cache="$HOME/.fasd-init-bash"

    if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache" ]; then
      fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| "$fasd_cache"
    fi

    source "$fasd_cache"
    eval "$(fasd --init auto)"
  }

  function setup_completions() {
    if [ -d $(brew --prefix)/etc/bash_completion.d ]; then
      for F in $(brew --prefix)/etc/bash_completion.d/*; do
        . ${F}
      done
    fi
  }

  function setup_direnv() {
    eval "$(direnv hook bash)"
  }

  function setup_gitprompt() {
    if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
      # git prompt config
      export GIT_PROMPT_SHOW_UNTRACKED_FILES=normal
      export GIT_PROMPT_ONLY_IN_REPO=0
      export GIT_PROMPT_THEME="Custom"

      source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
    fi
  }

  function setup_colors() {
    local colorscheme
    colorscheme="${HOME}/.config/colorschemes/scripts/base16-monokai.sh"
    [[ -s "${colorscheme}" ]] && source "${colorscheme}"
  }



  local dependencies
    dependencies=(
        aliases
        environment
        colors
        rbenv
        aws
        fasd
        completions
        direnv
        gitprompt
      )

  for dependency in ${dependencies[@]}; do
    eval "setup_${dependency}"
    unset -f "setup_${dependency}"
  done
}

function reload() {
  source "${HOME}/.bash_profile"
}

function reinstall() {
  local workspace
  workspace="${HOME}/workspace/routing-workspace"

  if [[ ! -d "${workspace}" ]]; then
    git clone https://github.com/rosenhouse/workspace "${workspace}"
  fi

  pushd "${workspace}" > /dev/null
    git diff --exit-code > /dev/null
    if [[ "$?" = "0" ]]; then
      git pull -r
      bash -c "./install.sh"
    else
      echo "Cannot reinstall. There are unstaged changes in $workspace"
      git diff
    fi
  popd > /dev/null
}

main
unset -f main


gobosh_create_bosh_lite ()
{
    local env_dir=${HOME}/workspace/deployments/lite

    bosh create-env ~/workspace/bosh-deployment/bosh.yml \
    --state $env_dir/state.json \
    -o ~/workspace/bosh-deployment/virtualbox/cpi.yml \
    -o ~/workspace/bosh-deployment/virtualbox/outbound-network.yml \
    -o ~/workspace/bosh-deployment/bosh-lite.yml \
    -o ~/workspace/bosh-deployment/bosh-lite-runc.yml \
    -o ~/workspace/bosh-deployment/jumpbox-user.yml \
    --vars-store $env_dir/creds.yml \
    -v director_name="Bosh Lite Director" \
    -v internal_ip=192.168.50.6 \
    -v internal_gw=192.168.50.1 \
    -v internal_cidr=192.168.50.0/24 \
    -v outbound_network_name="NatNetwork"

    bosh -e 192.168.50.6 --ca-cert <(bosh int $env_dir/creds.yml --path /director_ssl/ca) alias-env vbox
    BOSH_CLIENT="admin"
    BOSH_CLIENT_SECRET="$(bosh int $env_dir/creds.yml --path /admin_password)"
    BOSH_ENVIRONMENT="vbox"
    BOSH_DEPLOYMENT="cf"
    BOSH_CA_CERT="/tmp/bosh-lite-ca-cert"

    export BOSH_CLIENT
    export BOSH_CLIENT_SECRET
    export BOSH_ENVIRONMENT
    export BOSH_DEPLOYMENT
    export BOSH_CA_CERT
    bosh int $env_dir/creds.yml --path /director_ssl/ca > ${BOSH_CA_CERT}

    STEMCELL_VERSION="$(bosh int ~/workspace/cf-deployment/cf-deployment.yml --path=/stemcells/0/version)"
    echo "will upload stemcell ${STEMCELL_VERSION}"
    bosh -e vbox upload-stemcell "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent?v=${STEMCELL_VERSION}"

    bosh -e vbox -n update-cloud-config ~/workspace/cf-deployment/bosh-lite/cloud-config.yml
}

gobosh_delete_bosh_lite ()
{
    local env_dir=${HOME}/workspace/deployments/lite

    bosh delete-env ~/workspace/bosh-deployment/bosh.yml \
    --state $env_dir/state.json \
    -o ~/workspace/bosh-deployment/virtualbox/cpi.yml \
    -o ~/workspace/bosh-deployment/virtualbox/outbound-network.yml \
    -o ~/workspace/bosh-deployment/bosh-lite.yml \
    -o ~/workspace/bosh-deployment/bosh-lite-runc.yml \
    -o ~/workspace/bosh-deployment/jumpbox-user.yml \
    --vars-store $env_dir/creds.yml \
    -v director_name="Bosh Lite Director" \
    -v internal_ip=192.168.50.6 \
    -v internal_gw=192.168.50.1 \
    -v internal_cidr=192.168.50.0/24 \
    -v outbound_network_name="NatNetwork"
}

gobosh_untarget ()
{
  unset BOSH_DIR
  unset BOSH_USER
  unset BOSH_PASSWORD
  unset BOSH_ENVIRONMENT
  unset BOSH_GW_HOST
  unset BOSH_GW_PRIVATE_KEY
  unset BOSH_CA_CERT
  unset BOSH_DEPLOYMENT
  unset BOSH_CLIENT
  unset BOSH_CLIENT_SECRET
}

gobosh_target_lite ()
{
  gobosh_untarget
  local env_dir=${HOME}/workspace/deployments/lite

  pushd $env_dir >/dev/null
    BOSH_CLIENT="admin"
    BOSH_CLIENT_SECRET="$(bosh int ./creds.yml --path /admin_password)"
    BOSH_ENVIRONMENT="vbox"
    BOSH_CA_CERT=/tmp/bosh-lite-ca-cert

    export BOSH_CLIENT
    export BOSH_CLIENT_SECRET
    export BOSH_ENVIRONMENT
    export BOSH_CA_CERT
    bosh int ./creds.yml --path /director_ssl/ca > $BOSH_CA_CERT
  popd 1>/dev/null

  export BOSH_DEPLOYMENT=cf;
}


gobosh_deploy_bosh_lite ()
{
  local env_dir=${HOME}/workspace/deployments/lite

  bosh deploy --no-redact ~/workspace/cf-deployment/cf-deployment.yml \
  -o ~/workspace/cf-deployment/operations/bosh-lite.yml \
  -o ~/workspace/cf-deployment/operations/bypass-cc-bridge.yml \
  -o ~/workspace/cf-deployment/operations/experimental/disable-etcd.yml \
  --vars-store $env_dir/deployment-vars.yml \
  -v system_domain=bosh-lite.com
}

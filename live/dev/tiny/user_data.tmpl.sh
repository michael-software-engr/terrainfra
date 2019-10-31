#!/bin/bash

user_data() {
  local dev_dir='/opt/dev'
  local vm_dir="$dev_dir/asdf/asdf"
  local tool_versions_file="$vm_dir/tool-versions"
  local dev_env_init="$dev_dir/env.sh"

  local deploy_user='deploy'

  local go_ver='1.13.1'
  local go_dev_dir="$dev_dir/go"

  local js_ver='12.12.0'

  local repo='github.com/michael-software-engr/awsexample'
  local app_dir="$vm_dir/installs/golang/$go_ver/packages/src/$repo"
  local bin_fname='bin/server'

  local database_url='${tf_database_url}'

  declare -a tasks=(
    ssh_server
    dns
    wait_until_pkg_repo_update_is_successful
    install_pkgs

    "install_version_manager $vm_dir"
    "install_langs $vm_dir $tool_versions_file golang:$go_ver"
    "install_langs_nodejs $vm_dir $tool_versions_file $js_ver"
    "create_dev_env $dev_env_init $vm_dir $tool_versions_file $go_dev_dir"

    install_go_buffalo
    "install_go_app $repo $app_dir $dev_env_init $bin_fname"
    "create_secrets_file $app_dir $database_url"

    "create_deploy_user $deploy_user"
    "change_owner_to $deploy_user $app_dir"

    "db_stuff ${tf_do_db_stuff} $app_dir $dev_env_init $deploy_user"
    "run_go_app $deploy_user $app_dir $dev_env_init $bin_fname"
  )

  local task=''
  for task in "$${tasks[@]}"; do
    notice "START task '$task'"
    $task
    notice "END task '$task'"
  done
}

_logger() {
  local msg="$${1-}"
  local file="$${2-}"

  local level="$${FUNCNAME[1]-}"

  [ -n "$msg" ] || read msg

  declare -A valid_log_levels=(
    [notice]='info'
    [err]='err'
  )

  declare -a logger_args=( --stderr --tag "$(whoami):aws:user-data" )

  if [ -z "$${valid_log_levels[$level]-}" ]; then
    logger $${logger_args[@]} "... ERROR: invalid log level '$level', valid levels..."
    logger $${logger_args[@]} "... $(declare -p valid_log_levels)"
    exit 1
  fi

  local fac='user'

  logger_args+=( --priority "$fac.$level" )

  [ -n "$msg" ] && logger $${logger_args[@]} "... $msg" || exit

  [ -n "$file" ] || return 0
  local fpath="$(readlink -f "$file")"
  logger $${logger_args[@]} "... START: contents of file '$fpath'..." || exit
  logger $${logger_args[@]} --file "$fpath" || exit
  logger $${logger_args[@]} "... END: contents of file '$fpath'..." || exit
}

err() {
  local msg="$${1-}"
  [ -n "$msg" ] || read msg
  if [ -z "$msg" ]; then
    _logger "ERROR: must pass or pipe error message."
    exit 1
  fi

  local file="$${2-}"

  local error_code="$${error_code-1}"

  _logger "ERROR: $msg" "$file"

  exit "$error_code"
}

notice() {
  local msg="$${1:?ERROR => must pass notice message.}"
  local file="$${2-}"
  [ -n "$msg" ] || read msg

  _logger "$msg" "$file"
}

ssh_server() {
  sed -i 's/^[ ]*#*[ ]*Port 22[ ]*$/Port ${tf_ssh_ingress_port}/' /etc/ssh/sshd_config ||
    err 'failed to change SSH port to "${tf_ssh_ingress_port}".'

  service sshd restart || service ssh restart || err 'failed to restart SSH server.'
}

dns() {
  sed -i 's/^[ ]*#[ ]*DNS[ ]*=[ ]*$/DNS=208.67.222.222 208.67.220.220/' /etc/systemd/resolved.conf ||
    err 'failed to set up DNS server.'

  systemctl restart systemd-resolved.service || systemctl restart systemd-resolved.service ||
    err 'failed to restart DNS service.'
}

wait_until_pkg_repo_update_is_successful() {
  local max_count=10
  local delay=2
  local count=0

  while :; do
    apt-get update && return 0

    count="$((count + 1))"

    if [ "$count" -gt "$max_count" ]; then
      err "count '$count' > max '$max_count', '$FUNCNAME' failed."
    fi
    sleep "$delay"
  done
}

install_pkgs() {
  declare -a packages=(
    # Base
    aptitude xsel strace tree nmap htop git

    # Ruby
    autoconf bison build-essential libssl-dev libyaml-dev libreadline-dev
    zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev
    nodejs

    # Other tools
    postgresql-client postgresql-client-common
  )

  # apt-get update || err 'failed to apt-get update.'
  apt-get install --yes $${packages[@]} || err 'failed to install packages.'
}

install_version_manager() {
  local vm_dir="$${1:?ERROR => must pass version manager dir.}"

  local init="$vm_dir/asdf.sh"
  if [ -f "$init" ]; then
    notice "init file '$init', version manager already installed probably."
    return 0
  fi

  mkdir -p "$vm_dir" || err "failed to mkdir -p '$vm_dir'."

  git clone https://github.com/asdf-vm/asdf.git "$vm_dir" || err 'failed to clone version manager.'
  cd "$vm_dir" || err "failed to cd '$vm_dir'."
  git checkout "$(git describe --abbrev=0 --tags)" || err 'failed to check out latest version manager branch.'
}

install_langs() {
  local vm_dir="$${1:?ERROR => must pass version manager dir.}"
  local tool_versions_file="$${2:?ERROR => must pass tool versions file.}"
  shift
  shift

  local init="$vm_dir/asdf.sh"

  export ASDF_DATA_DIR="$vm_dir"

  set +o errexit
  set +o pipefail
  set +o nounset
  . "$init" || err "failed to source '$init'."
  set -o errexit
  set -o pipefail
  set -o nounset

  local lang_set=''
  local lang=''
  local ver=''
  for lang_set in "$@"; do
    local lang="$(cut -f 1 -d ':' <<<"$lang_set")"
    local ver="$(cut -f 2 -d ':' <<<"$lang_set")"

    if asdf current "$lang" | /bin/grep -q "$ver"; then
      notice "'$lang' '$ver' already installed probably."
      continue
    fi

    asdf plugin-add "$lang" || err "failed to asdf plugin-add '$lang'."

    asdf install "$lang" "$ver" || err "failed to install '$lang' '$ver'."

    ASDF_DEFAULT_TOOL_VERSIONS_FILENAME="$tool_versions_file" \
      asdf global "$lang" "$ver" || err "failed to set global '$lang' to '$ver'."

    ASDF_DEFAULT_TOOL_VERSIONS_FILENAME="$tool_versions_file" \
      asdf current "$lang" | /bin/grep -q "$ver" ||
        err "failed to set global '$lang' to '$ver'."
  done

  asdf reshim || err 'failed asdf reshim.'
}

install_langs_nodejs() {
  local vm_dir="$${1:?ERROR => must pass version manager dir.}"
  local tool_versions_file="$${2:?ERROR => must pass tool versions file.}"
  local js_ver="$${3:?ERROR => must pass JS version to install.}"

  local init="$vm_dir/asdf.sh"

  export ASDF_DATA_DIR="$vm_dir"

  set +o errexit
  set +o pipefail
  set +o nounset
  . "$init" || err "failed to source '$init'."
  set -o errexit
  set -o pipefail
  set -o nounset

  local lang='nodejs'
  local ver="$js_ver"

  if asdf current "$lang" | /bin/grep -q "$ver"; then
    notice "'$lang' '$ver' already installed probably."
    return 0
  fi

  asdf plugin-add "$lang" || err "failed to asdf plugin-add '$lang'."
  bash "$vm_dir/plugins/nodejs/bin/import-release-team-keyring"
  HOME='/root' asdf install "$lang" "$ver" || err "failed to install '$lang' '$ver'."

  ASDF_DEFAULT_TOOL_VERSIONS_FILENAME="$tool_versions_file" \
    asdf global "$lang" "$ver" || err "failed to set global '$lang' to '$ver'."

  ASDF_DEFAULT_TOOL_VERSIONS_FILENAME="$tool_versions_file" \
    asdf current "$lang" | /bin/grep -q "$ver" ||
      err "failed to set global '$lang' to '$ver'."

  asdf reshim || err 'failed asdf reshim.'

  ASDF_DEFAULT_TOOL_VERSIONS_FILENAME="$tool_versions_file" \
    npm install --global yarn || err 'failed to npm install --global yarn.'

  # Because yarn is not added to './shims' for some reason.
  asdf reshim || err 'failed asdf reshim.'
}

create_dev_env() {
  local dev_env_init="$${1:?ERROR => must pass dev init file.}"
  local vm_dir="$${2:?ERROR => must pass version manager dir.}"
  local tool_versions_file="$${3:?ERROR => must pass tool versions file.}"
  local go_dev_dir="$${4:?ERROR => must pass go dev dir.}"

  mkdir -p "$go_dev_dir" || err "failed to mkdir -p '$go_dev_dir'."
  local go_pkg_complete="$go_dev_dir/go-pkg-complete.bash.inc"

  cat <<EOF >"$dev_env_init"
export ASDF_DATA_DIR='$vm_dir'
export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME='$tool_versions_file'

. "\$ASDF_DATA_DIR/asdf.sh"
. "\$ASDF_DATA_DIR/completions/asdf.bash"

export GOPATH="\$(go env GOPATH)"
export GOROOT="\$(go env GOROOT)"

export PATH="\$GOPATH/bin:\$PATH"

[ -n "\$GOPATH" ] || echo 'WARNING: GOPATH is not set.' >&2
[ -n "\$GOROOT" ] || echo 'WARNING: GOPATH is not set.' >&2

. '$go_pkg_complete'
EOF

  cat <<'EOF' >"$go_pkg_complete"
get_go_pkgs_in() {(
    IFS=" "
    gopath="$1"
    word="$2"
    match="$word"
    case "$word" in
  "."|"./"*)
      match="$(go list -e .)$${word:1}"
      ;;
  ".."|"../"*)
      match="$(go list -e ..)$${word:2}"
      ;;
    esac
    for d in "$gopath"/src/"$match"*; do
  [[ "$d" == *"*" ]] && continue
  [[ -d "$d" ]] || continue
  d="$${d/$gopath\/src\/} "
  d="$word$${d:$${#match}}"
  echo -n "$d"
    done
    if [ "$${match: -1}" != "/" ]; then
  for d in "$gopath"/src/"$match"/*; do
      [[ "$d" == *"*" ]] && continue
      [[ -d "$d" ]] || continue
      d="$${d/$gopath\/src\/}/ "
      d="$word$${d:$${#match}}"
      echo -n "$d"
  done
    fi
)}

get_go_pkgs_dup() {(
    word=$1
    IFS=":"
    for g in $GOPATH; do
        get_go_pkgs_in "$g" "$word"
    done
)}


get_go_pkgs() {
    get_go_pkgs_dup $@ | sort | uniq
}

get_go_cmds() {
    for i in build clean env fix fmt generate get install list run test tool version vet save vendor; do
        [[ $i == $1* ]] && echo $i
    done
}

get_go_tools() {
    for i in $(go tool -n); do
        [[ $i == $1* ]] && echo $i
    done
}

go_pkg_complete() {
    set -- $COMP_LINE
    shift

    while [[ $1 == -* ]]; do
          shift
    done

    local cur=$${COMP_WORDS[COMP_CWORD]}
    if grep -q '^\(install\|build\|list\|get\|test\|generate\|vet\|save\|vendor\)$' <<< $1; then
        COMPREPLY=( $(compgen -W "$(get_go_pkgs $cur)" -- $cur) )
        return
    elif grep -q '^\(tool\)$' <<< $1; then
        COMPREPLY=( $(compgen -W "$(get_go_tools $cur)" -- $cur) )
        return
    elif grep -q '^\(run\|fmt\)$' <<< $1; then
        compopt -o default
        COMPREPLY=()
        return
    fi

    case "$1" in
        run)
            COMPREPLY=( $(compgen -A file -G "$cur**/*.go" -- $cur) )
            return
      ;;
    esac

    [[ $2 ]] && return

    COMPREPLY=( $(compgen -W "$(get_go_cmds $cur)" -- $cur) )
}

wgo_pkg_complete() {
    GOPATH=$(wgo env GOPATH) go_pkg_complete $@
}

complete -o nospace -F go_pkg_complete go
complete -o nospace -F wgo_pkg_complete wgo
EOF
}

install_go_buffalo() {
  local container_dir='/usr/local/bin/buffalo.d'
  mkdir "$container_dir" || err "failed to mkdir '$container_dir'"

  cd "$container_dir"
  wget https://github.com/gobuffalo/buffalo/releases/download/v0.14.10/buffalo_0.14.10_linux_amd64.tar.gz
  tar -xvzf buffalo_0.14.10_linux_amd64.tar.gz
  cd ..
  ln -s "$container_dir/buffalo"
}

install_go_app() {
  local repo="$${1:?ERROR => must pass repo.}"
  local app_dir="$${2:?ERROR => must pass app dir.}"
  local dev_env_init="$${3:?ERROR => must pass dev env init file.}"
  local bin_fname="$${4:?ERROR => must pass output bin filename.}"

  if [ -f "$app_dir/main.go" ]; then
    notice "app in '$app_dir' already installed."
    return 0
  fi

  mkdir -p "$app_dir" || err "failed to mkdir -p '$app_dir'."

  git clone "https://$repo" "$app_dir" ||
    err "failed to git clone 'https://$repo' '$app_dir'."

  set +o errexit
  set +o pipefail
  set +o nounset
  . "$dev_env_init" || err "failed to source '$dev_env_init'."
  set -o errexit
  set -o pipefail
  set -o nounset

  local js_dir="$app_dir/assets/js/application/"
  cd "$js_dir" || err "failed to cd '$js_dir'."
  ( yarn install && yarn deploy ) || err 'failed to yarn install and deploy.'

  cd "$app_dir" || err "failed to cd '$app_dir'."

  local gocache="/var/cache/go/$(basename "$app_dir")"
  mkdir -p "$gocache" || err "failed to mkdir -p '$gocache'."

  GOCACHE="$gocache" buffalo build --output "$bin_fname" || return
  sync
}

create_secrets_file() {
  local app_dir="$${1:?ERROR => must pass app dir.}"
  local database_url="$${2:?ERROR => must pass database URL.}"

  local secrets_file="$app_dir/.env"

  cat <<EOF > "$secrets_file" || err "failed to create secrets file '$secrets_file'."
DATABASE_URL=$database_url
EOF
  sync
}

create_deploy_user() {
  local user="$${1:?ERROR => must pass user name.}"

  if id "$user"; then
    notice "user '$user' already exists."
    return 0
  fi

  useradd -m -s /bin/bash "$user" || err "failed to create user '$user'."
}

change_owner_to() {
  local user="$${1:?ERROR => must pass user name.}"
  local app_dir="$${2:?ERROR => must pass app dir.}"

  declare -a dirs=(
    "$vm_dir"
    "$app_dir"
  )

  local dir=''
  for dir in "$${dirs[@]}"; do
    chown "$user:$user" -R "$dir" || err "failed to chown -R '$user:$user' '$dir'."
  done
}

user_exec_go_env() {
  local user="$${1:?ERROR => must pass user.}"
  local dev_env_init="$${2:?ERROR => must pass dev env init file.}"
  local app_dir="$${3:?ERROR => must pass app dir.}"
  shift
  shift
  shift

  [ -d "$app_dir" ] || err "app dir '$app_dir' not a dir."

  set +o errexit
  set +o pipefail
  set +o nounset
  sudo --user "$user" --login bash -c \
    ". '$dev_env_init' && cd '$app_dir' && $@" ||
    err "failed to exec sudo ... '$@'"
  set -o errexit
  set -o pipefail
  set -o nounset
}

db_stuff() {
  local do_db_stuff="$${1-}"
  local app_dir="$${2:?ERROR => must pass app dir.}"
  local dev_env_init="$${3:?ERROR => must pass dev env init file.}"
  local user="$${4:?ERROR => must pass user.}"

  if [ -z "$do_db_stuff" ]; then
    notice 'do_db_stuff is blank, skipping...'
    return
  fi

  declare -a cmds=(
    "echo '... DEBUG: pwd, ls...' && pwd && ls -l --color=auto"
    'go get -u -v github.com/gobuffalo/buffalo-plugins'
    'buffalo plugins install github.com/gobuffalo/buffalo-pop'
    'GO_ENV=production buffalo db migrate status'
    'GO_ENV=production buffalo db migrate'
    'GO_ENV=production buffalo task db:seed:reset'
  )

  local cmd=''
  for cmd in "$${cmds[@]}"; do
    user_exec_go_env "$user" "$dev_env_init" "$app_dir" "$cmd"
  done
}

wait_for_build_output() {
  local build_output_fpath="$${1:?ERROR => must pass build output full path.}"

  local max_count=10
  local delay=2
  local count=0

  while :; do
    [ -x "$build_output_fpath" ] && return 0

    count="$((count + 1))"

    if [ "$count" -gt "$max_count" ]; then
      err "count '$count' > max '$max_count', '$FUNCNAME' failed."
    fi
    sleep "$delay"
  done
}

run_go_app() {
  local user="$${1:?ERROR => must pass user.}"
  local app_dir="$${2:?ERROR => must pass app dir.}"
  local dev_env_init="$${3:?ERROR => must pass go env init.}"
  local bin_fname="$${4:?ERROR => must pass output bin filename.}"

  local build_output_fpath="$app_dir/$bin_fname"
  wait_for_build_output "$build_output_fpath"

  user_exec_go_env "$user" "$dev_env_init" "$app_dir" \
    "GO_ENV=production ADDR=0.0.0.0 PORT=${tf_http_port} $build_output_fpath"
}

set -o errexit
set -o pipefail
set -o nounset

home="$(getent passwd $(whoami) | cut -d: -f6)"
logs_dir="$home/logs"
dstamp=$(date '+%F_%H-%M-%S')
[ -d "$logs_dir" ] || mkdir "$logs_dir"
user_data "$@" 2>&1 | tee "$logs_dir/user-data.$dstamp.log"
unset home
unset logs_dir
unset dstamp
export > "$logs_dir/exports.$dstamp.log"

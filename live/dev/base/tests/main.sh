#!/usr/bin/env bash

main() {
  local pem="${1-}"
  local user="${2-ubuntu}"

  local this_dir="$(dirname "$BASH_SOURCE")"
  [ -n "$pem" ] || pem="$this_dir/../../../../priv/default.pem"

  local prop_name='bastion IP'
  local bastion_ip="$(
    state_value \
      'module.terrainfra_dev_bastion.aws_instance.terrainfra_bastion' \
      public_ip \
      "$prop_name"
  )"
  [ -n "$bastion_ip" ] || error "unable to find '$prop_name' value."

  local bastion_asg_tf_address='module.terrainfra_dev_bastion.aws_security_group.terrainfra_bastion'
  local lines="$(
    terraform state show "$bastion_asg_tf_address" |
    remove_non_printing |
    /bin/grep -A 14 ingress |
    /bin/grep to_port
  )"

  local bastion_ssh_port="$(state_value "$bastion_asg_tf_address" to_port 'bastion SSH port' "$lines")"

  [ -n "$bastion_ssh_port" ] || error 'unable to find bastion SSH port value.'

  test_nslookup "$pem" "$bastion_ip" "$bastion_ssh_port" "$user" 'bastion'
  test_nslookup_asg "$pem" "$bastion_ip" "$bastion_ssh_port" "$user"
  test_http
}

error() {
  local msg="${1:?ERROR, must pass error message.}"

  echo -e "ERROR: $msg" >&2
  exit 1
}

assert_single_match() {
  local lines="${1:?ERROR, must pass output lines.}"
  local name="${2:?ERROR, must pass property name.}"

  [ -n "$lines" ] || error "unable to find '$name'."
  local matches="$(wc -l <<<"$lines")"
  [ "$matches" -eq 1 ] || error "more than 1 ($matches) matches for '$name'...\n$lines"
}

remove_non_printing() {
  sed 's,\x1B\[[0-9;]*[a-zA-Z],,g'
}

tabs_to_spaces() {
  sed 's/[\t]/ /g'
}

trim_trash() {
  tr -d '["]' | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
}

prop_value() {
  local str="${1:?ERROR, must pass string to extract prop value from.}"

  cut -f 2 -d '=' <<<"$str" | trim_trash
}

state_value() {
  local tf_address="${1:?ERROR, must pass Terraform address}"
  local key="${2:?ERROR, must pass key.}"
  local prop_name="${3:?ERROR, must pass prop name.}"
  local lines="${4-}"

  [ -n "$lines" ] || lines="$(
    terraform state show "$tf_address" |
    remove_non_printing |
    /bin/grep "[ ]$key[ ]"
  )"

  assert_single_match "$lines" "$prop_name"

  cut -f 2 -d '=' <<<"$lines" | trim_trash
}

test_nslookup() {
  local pem="${1:?ERROR, must pass PEM file path.}"
  local host_under_test_ip="${2:?ERROR, must pass IP of host under test.}"
  local host_under_test_ssh_port="${3:?ERROR, must pass SSH port of host under test.}"
  local user="${4:?ERROR, must pass user.}"
  local test_name="${5-}"
  local remote_host="${6-nmap.org}"

  local ssh_output=''
  if [ -n "${proxy_ip-}" ]; then
    [ -n "${proxy_ssh_port-}" ] || error 'must set var proxy_ssh_port.'

    ssh_output="$(
      ssh \
        -i "$pem" -p "$host_under_test_ssh_port" "$user"@"$host_under_test_ip" \
        -o "ProxyCommand ssh -W %h:%p -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p '$proxy_ssh_port' -i "$pem" '$user@$proxy_ip'" \
        -q \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
          nslookup -timeout=2 "$remote_host"
    )"
  else
    ssh_output="$(
      ssh \
        -i "$pem" -p "$host_under_test_ssh_port" "$user@$host_under_test_ip" \
        -q \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
          nslookup -timeout=2 "$remote_host"
    )"
  fi

  local got="$(
    echo "$ssh_output" |
      remove_non_printing |
      /bin/grep -m 1 Name: |
      tabs_to_spaces |
      cut -f 2 -d ':' |
      trim_trash
  )"

  [ -n "$got" ] || error 'unable to get nslookup output.'

  if [ "$got" = "$remote_host" ]; then
    local test_msg="$FUNCNAME"
    [ -n "$test_name" ] && test_msg+=" ($test_name)"
    echo "$test_msg: OK"
    return
  fi

  echo "Test failed: got '$got' != expected '$remote_host'"
  exit 1
}

test_nslookup_asg() {
  local pem="${1:?ERROR, must pass PEM file path.}"
  local bastion_ip="${2:?ERROR, must pass IP of host under test.}"
  local bastion_ssh_port="${3:?ERROR, must pass SSH port of host under test.}"
  local user="${4:?ERROR, must pass user.}"

  local prop_name='auto-scaling group name'
  local asg_name="$(
    state_value \
      'module.terrainfra_dev_svcs_app.aws_autoscaling_group.terrainfra' \
      name \
      "$prop_name"
  )"
  [ -n "$asg_name" ] || error "unable to find '$prop_name'."

  declare -a ids="$(
    aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$asg_name" \
      --query AutoScalingGroups[].Instances[].InstanceId \
      --output text
  )"

  local id=''
  local priv_ip=''
  local got=''
  for id in ${ids[@]}; do
    priv_ip="$(
      aws ec2 describe-instances \
        --instance-ids $id \
        --query Reservations[].Instances[].PrivateIpAddress \
        --output text
    )"

    proxy_ip="$bastion_ip" \
      proxy_ssh_port="$bastion_ssh_port" \
      test_nslookup "$pem" "$priv_ip" '22' "$user" "auto-scaling group, $priv_ip"
  done
}

test_http() {
  local prop_name='DNS name'
  local dns_name="$(
    state_value 'module.terrainfra_dev_network.aws_elb.terrainfra[0]' \
      dns_name \
      "$prop_name"
  )"

  [ -n "$dns_name" ] || error "unable to find '$prop_name'."

  local got="$(curl -s "$dns_name")"

  local exp='Meowdy'
  if /bin/grep -q "$exp" <<<"$got"; then
    echo "$FUNCNAME: OK"
    return
  fi

  echo -e "Test failed: exp '$exp' not found in...\n$got"
  exit 1
}

set -o errexit
set -o pipefail
set -o nounset
main "$@"

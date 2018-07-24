#!/bin/sh
# ----------------------------------------------------------------------------
# Written by Rodrigo Jorge <http://www.dbarj.com.br/>
# Available at: https://github.com/dbarj/oci-scripts
# Created on: Jul/2018 by Rodrigo Jorge
# Version 1.00
# ----------------------------------------------------------------------------

# Define paths for oci-cli and jq:
v_oci="/usr/local/bin/oci"
v_jq="/usr/local/bin/jq"

if ! $(which ${v_oci} >&- 2>&-)
then
  echo "Could not find oci-cli binary. Please adapt the path in the script."
  echo "Dowload page: https://github.com/oracle/oci-cli"
  exit 1
fi

if ! $(which ${v_jq} >&- 2>&-)
then
  echo "Could not find jq binary. Please adapt the path in the script."
  echo "Download page: https://github.com/stedolan/jq/releases"
  exit 1
fi

v_cmp_string="--compartment-id ${v_compartment_ocid}"
v_vcn_string="--vcn-id ${v_vcn_ocid}"

if [ -z "$v_compartment_ocid" ]
then
  echo "OCID of compartment not specified. Please export v_compartment_ocid variable with correct value."
  ${v_oci} iam compartment list --all | ${v_jq} -r '.data[] | [.name,.id] | @csv'
  exit 1
else
  v_listvcn=$(${v_oci} network vcn list --all ${v_cmp_string})
  ret=$?
  if [ $ret -ne 0 ]
  then
    echo "OCID of compartment not specified correctly. Please export v_compartment_ocid variable with correct value."
    ${v_oci} iam compartment list --all | ${v_jq} -r '.data[] | [.name,.id] | @csv'
    exit 1
  else
    if [ -z "$v_listvcn" ]
    then
      echo "There is no VCN in this Compartment."
      exit 1
    fi
  fi
fi

if [ -z "$v_vcn_ocid" ]
then
  echo "OCID of VCN not specified. Please export v_vcn_ocid variable with correct value."
  ${v_oci} network vcn list --all ${v_cmp_string} | ${v_jq} -r '.data[] | [."display-name",.id] | @csv'
  exit 1
else
  v_listvcn=$(${v_oci} network vcn get ${v_vcn_string})
  ret=$?
  if [ $ret -ne 0 ]
  then
    echo "OCID of VCN not specified correctly. Please export v_vcn_ocid variable with correct value."
    ${v_oci} network vcn list --all ${v_cmp_string} | ${v_jq} -r '.data[] | [."display-name",.id] | @csv'
    exit 1
  fi
fi

function listSecListsSub ()
{
  [ "$#" -ne 2 ] && return
  local v_arg1="$1"
  local v_arg2="$2"
  local v_out1=$(
${v_oci} network security-list list ${v_vcn_string} ${v_cmp_string} --all | ${v_jq} '.data[] |
"'${v_arg1}'" as $type |
."display-name" as $display |
."lifecycle-state" as $lifecycle | 
."'${v_arg1}'-security-rules"[]? |
."is-stateless" as $stateless |
."protocol" as $protocol | 
"'${v_arg2}'" as $contype |
."'${v_arg2}'" as $'${v_arg2}' |
."tcp-options"."destination-port-range"."min" as $tdmin |
."tcp-options"."destination-port-range"."max" as $tdmax |
."tcp-options"."source-port-range"."min" as $tsmin |
."tcp-options"."source-port-range"."max" as $tsmax |
."udp-options"."destination-port-range"."min" as $udmin |
."udp-options"."destination-port-range"."max" as $udmax |
."udp-options"."source-port-range"."min" as $usmin |
."udp-options"."source-port-range"."max" as $usmax |
{
"display-name": $display,
"lifecycle-state": $lifecycle,
"is-stateless": $stateless,
"type" : $type,
"protocol": $protocol,
"contype": $contype,
"'${v_arg2}'": $'${v_arg2}',
"tcp-destination-port-min": $tdmin,
"tcp-destination-port-max": $tdmax,
"tcp-source-port-min": $tsmin,
"tcp-source-port-max": $tsmax,
"udp-destination-port-min": $udmin,
"udp-destination-port-max": $udmax,
"udp-source-port-min": $usmin,
"udp-source-port-max": $usmax
}' | sed 's/}/},/; 1 s/{/[{/; $s/},/}]/' | ${v_jq} -r '.[] |
[
."display-name",
."lifecycle-state",
."is-stateless",
."type",
."protocol",
."contype",
."'${v_arg2}'",
."tcp-destination-port-min",
."tcp-destination-port-max",
."tcp-source-port-min",
."tcp-source-port-max",
."udp-destination-port-min",
."udp-destination-port-max",
."udp-source-port-min",
."udp-source-port-max"] | @csv'
)
  [ -n "${v_out1}" ] && echo "${v_out1}"
}
###
v_header="display-name,lifecycle-state,is-stateless,type,protocol,contype,IP,tcp-dest-port-min,tcp-dest-port-max,tcp-source-port-min,tcp-source-port-max,udp-dest-port-min,udp-dest-port-max,udp-source-port-min,udp-source-port-max"
v_out1=$(listSecListsSub "ingress" "source")
v_out2=$(listSecListsSub "egress"  "destination")
[ -n "$v_out1" -o -n "$v_out2" ] && echo "$v_header"
[ -n "$v_out1" ] && echo "$v_out1"
[ -n "$v_out2" ] && echo "$v_out2"
exit 0
###
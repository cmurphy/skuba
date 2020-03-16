#!/bin/bash

set -e

susepkg_dir=$(cd "$( dirname "$0" )" && pwd)
tmp_dir=$(mktemp -d -t skuba_XXXX)
rpm_files="${susepkg_dir}/obs_files"
tag="$1" # maybe make this smart enough to get the latest tag

log()   { (>&2 echo ">>> $*") ; }
clean() { log "Cleaning temporary directory ${tmp_dir}"; rm -rf "${tmp_dir}"; }

trap clean ERR

ibs_user=$(osc config https://api.suse.de user | awk '$0=$NF' || echo -n '')
if [[ -n "$ibs_user" ]]
then
    log "Found IBS config; updating IBS"
    ibs_user=${ibs_user//\'}
    branch_project="home:${ibs_user}:caasp_auto_release"
    branch_name="skuba_$tag"
    work_dir="$tmp_dir/ibs_skuba"
    log "Creating IBS branch"
    osc -A 'https://api.suse.de' branch home:comurphy:branches:Devel:CaaSP:4.0:C skuba \
      "$branch_project" "$branch_name"
    osc -A 'https://api.suse.de' co -o "$work_dir" \
      "$branch_project/$branch_name"
    log "Updating IBS branch"
    (
        cd "$work_dir"
        osc rm *.obscpio
        osc service disabledrun # need to use disabledrun even though it's deprecated, see https://github.com/openSUSE/osc/pull/769
        osc add *.obscpio
    )
    osc -A 'https://api.suse.de' ci "$work_dir" \
         -m "$(sed '1,/^$/d;/^$/,$d' "${work_dir}/skuba.changes")"
    log "Creating self-cleaning SR"
    osc -A 'https://api.suse.de' sr \
      -m "Update for release '$tag'" \
      --cleanup --yes \
      "$branch_project" "$branch_name" \
      home:comurphy:branches:Devel:CaaSP:4.0:C skuba
fi

clean

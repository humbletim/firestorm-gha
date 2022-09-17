#!/bin/bash
# helper function for extracting C SOURCE files from old school .dsp projects
# -- humbletim 2022.03.27
#
# usage: _dsp_sourcefiles <dspfile> [optional per-source prefix -- eg: -Tp]
# example:
#   SRCS=$(_dsp_sourcefiles project.dsp -Tp)
#   cl.exe /c $SRCS
function _dsp_sourcefiles() {
  local dspfile=$1 Tp=${2:-}
  local reldir=${Tp}$(dirname $dspfile)/
  test -f $dspfile
  echo "_dsp_sources($dspfile,$reldir)" >&2
  cat $dspfile | \
    grep -Ei '^SOURCE=.*\.(c|cxx|cpp|c+\+|cc)\s*$' | \
    sed -e "s@SOURCE=@${reldir}@;" -e 's@\\@/@g; s@/\./@/@g;'
}

# bash helper to create system-level filesystem links in ubuntu/windows gha runners
# -- 2023.03.20 humbletim

# usage: ht-ln <SOURCE> <destination folder/ or desired link filepath>

function ht-ln() {
  local source="$1" linkfilepath="$2"
  test -e "$source" || { echo "source does not exist '$source'" >&2 ; return 1; }

  # if source is a file an destination a directory then generate link filepath
  test -f "$source" && test -d "$linkfilepath" && linkfilepath="$linkfilepath/$(basename "$source")"

  # verify link folder exists
  test -d "$(dirname "$linkfilepath")" || { echo "link location does not exist '$(dirname "$linkfilepath")'" >&2 ; return 1; }

  # no-op if linkfilepath already exists
  test -e "$linkfilepath" && return 0

  # default to linux style hard links
  local cmd="ln -v \"$source\" \"$linkfilepath\""

  # but on Linux use symbolic links for directories
  test -d "$source" && cmd="ln -vs \"$source\" \"$linkfilepath\""

  # but on Windows / msys use mklink instead
  if [[ "$OSTYPE" == "msys" ]]; then
    local opts=""

    # for files /H hardlinks are used
    test -f "$source" && opts="/H"

    # for directories /J junctions are used; /D (directory symbolic) is another option to consider
    test -d "$source" && opts="/J"

    COMMAND="mklink $opts \"$(/usr/bin/cygpath -wa "$linkfilepath")\" \"$(/usr/bin/cygpath -wa "$source")\""
    cmd="/c/Windows/system32/cmd.exe //C call $(echo "$COMMAND" | /usr/bin/sed 's@/@//@g;s@\\@\\\\@g') "
  fi

  type -t _relativize >/dev/null && _relativize "[ht-ln] $cmd" >&2
  eval "$cmd" || exit $?
}

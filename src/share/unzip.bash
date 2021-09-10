#============================================================================
# Title       : unzip.bash
# Description : bash_completion file for unzip
# Author      : Bart Sjerps <bart@dirty-cache.com>
# License     : GPLv3+
# ---------------------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.
# ---------------------------------------------------------------------------
# Using this completion makes it easier to browse within a zip file for specific
# files.
# Usage:
# Put this file in /etc/bash_completion.d and login again
# unzip [-v|-qc] [TAB] will complete *.zip filenames
# unzip -qc <zipfile> [TAB] will complete files within the ZIP file

_unzip() {
  local cur prev opts cmd
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmd="${COMP_WORDS[1]}"
  ziplist() { unzip -l $1 | awk '/-----/ {p = ++p % 2; next} p {print $NF}' ; }
  case $prev in
    -v|-l) COMPREPLY=($(compgen -o plusdirs -o filenames -f -X '!*.zip' -- $cur)) ;;
    -qc)   COMPREPLY=($(compgen -o plusdirs -o filenames -f -X '!*.zip' -- $cur)) ;;
     *)    COMPREPLY=($(compgen -o plusdirs -o filenames -f -X '!*.zip' -- $cur)) ;;
  esac
  if (( $COMP_CWORD > 2 )); then
    compopt +o plusdirs
    case ${cmd} in
      -qc) COMPREPLY=($(compgen -W "$(ziplist ${prev})" -- ${cur})) ;;
    esac
  fi
  return 0
}
complete -o plusdirs -F _unzip unzip

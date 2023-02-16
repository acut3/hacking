#!/usr/bin/bash
#
# Usage: php_grep_exec.sh [FILE...]
#

# Array of functions to search for
FUNCS=(
    'passthru'
    'system'
    'shell_exec'
    'exec'
    'popen'
    'proc_open'
)

# Array of statements to search for
STATEMENTS=(
    'include'
    'require'
    'require_once'
)

grep_func() {
    i=$1
    shift
    grep --color=auto -Enr --include=*.php '(^|;)\s*'"$i"'\s*\(' "$@"
}

grep_statement() {
    i=$1
    shift
    # Only when a varible is used
    grep --color=auto -Enr --include=*.php '(^|;)\s*'"$i"'(\s+|\().*\$' "$@"
}

{
    for i in "${FUNCS[@]}"
    do
        grep_func "$i" "$@"
    done

    for i in "${STATEMENTS[@]}"
    do
        grep_statement "$i" "$@"
    done
} | sort -t: -k1,1 -k2,2n

#!/usr/bin/bash
#
# Usage: python_grep_exec.sh [FILE...]
#

# Array of functions to search for
FUNCS=(
    'os.popen'
    'os.popen2'
    'os.popen3'
    'os.spawn'
    'os.spawnl'
    'os.spawnle'
    'os.spawnlp'
    'os.spawnlpe'
    'os.spawnp'
    'os.spawnv'
    'os.spawnve'
    'os.spawnvp'
    'os.spawnvpe'
    'os.system'
    'subprocess.Popen'
    'subprocess.call'
    'subprocess.check_call'
    'subprocess.check_output'
    'subprocess.getoutput'
    'subprocess.getstatusoutput'
    'subprocess.run'
)

grep_func() {
    func=$1
    shift
    grep --color=auto -Enr "$func"'\s*\(' "$@"
}

{
    for func in "${FUNCS[@]}"
    do
        grep_func "$func" "$@"
    done
} | sort -t: -k1,1 -k2,2n

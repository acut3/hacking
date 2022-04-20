#!/usr/bin/bash

CFGDIR="$HOME/.config/autorecon"

ROOTDIR="AUTORECON"
RUNDIR_PREFIX="RUN_"
FILE_ROOTDOMAINS="rootdomains.txt"
FILE_BLACKLIST="blacklist.txt"
FILE_EGREP_BLACKLIST="egrep_$FILE_BLACKLIST"

PORTS='21,22,80,443,6379,9200,9443'

FILE_AMASS="amass.out"
FILE_SUBFINDER="subfinder.out"
FILE_SUBDOMAINS="subdomains.txt"
FILE_MASSDNS="massdns.json"
FILE_SUBDOMAINS_A="subdomains_a.txt"
FILE_SUBDOMAINS_CNAME="subdomains_cname.txt"
FILE_SUBDOMAINS_CNAME_NOIP="subdomains_cname_noip.txt"
FILE_SUBDOMAINS_IPS="subdomains_ip.txt"
FILE_MASSCAN="masscan.json"
FILE_SUBDOMAINS_PORT="subdomains_port_*.txt"
FILE_HTTPX="httpx.out"

################################################################################
# Functions
################################################################################

init () {
    [[ ! -d $ROOTDIR ]] && mkdir $ROOTDIR
    cd $ROOTDIR || exit 1
    newdir=$RUNDIR_PREFIX$(date +%Y%m%d)
    [[ ! -d $newdir ]] && mkdir "$newdir"
    cd "$newdir" || exit 1
}

miss () {
    fname=$1
    [[ ! -f "$fname" ]]
}

sorthosts () {
    sort -u -t. -k9,9 -k8,8 -k7,7 -k6,6 -k5,5 -k4,4 -k3,3 -k2,2 -k1,1 "$@"
}

# Get hosts with a given IP, using the massdns json file
hosts4ip () {
    ip=$1
    jq -r 'select(.data.answers[]?.data=="'"$ip"'").name[:-1]' $FILE_MASSDNS
}

# Get IPs with a given port open, using the masscan json file
ips4port () {
    port=$1
    jq -r '.[]|select(.ports[].port=='"$port"').ip' $FILE_MASSCAN
}

# Get hosts with a given port open, using the masscan and massdns json files
hosts4port () {
    port=$1
    {
        for ip in $(ips4port "$port")
        do
            hosts4ip "$ip"
        done
    } | sorthosts
}

# For each port that was found open at least once, create a file with the hosts
# that have this port open
mk_hostsbyport_files () {
    # For each port port that is open on at least one IP
    for port in $(jq '.[].ports[].port' $FILE_MASSCAN | sort -nu)
    do
        out=${FILE_SUBDOMAINS_PORT//\*/$port}
        hosts4port "$port" > "$out"
    done
}

################################################################################
# Main script
################################################################################

init

#===============================================================================
# Subdomain enumeration
#-------------------------------------------------------------------------------

if [[ -e ../$FILE_BLACKLIST ]]
then
    amass_blf="-blf ../$FILE_BLACKLIST"
    awk '{gsub(/\./, "\\.");print "(^|\\.)"$0"$"}' ../$FILE_BLACKLIST > ../$FILE_EGREP_BLACKLIST
else
    amass_blf=""
fi

# amass
outfile=$FILE_AMASS
# shellcheck disable=SC2086
miss $outfile &&
    amass enum -v -passive -df "../$FILE_ROOTDOMAINS" $amass_blf -o $outfile

# subfinder
outfile=$FILE_SUBFINDER
miss $outfile &&
    subfinder -dL "../$FILE_ROOTDOMAINS" -o $outfile

# Put everything together
outfile=$FILE_SUBDOMAINS
if [[ -e ../$FILE_EGREP_BLACKLIST ]]
then
    miss $outfile &&
        sorthosts $FILE_AMASS $FILE_SUBFINDER |
        grep -Evf ../$FILE_EGREP_BLACKLIST > $FILE_SUBDOMAINS
else
    miss $outfile &&
        sorthosts $FILE_AMASS $FILE_SUBFINDER > $FILE_SUBDOMAINS
fi


#===============================================================================
# DNS resolution
#-------------------------------------------------------------------------------

outfile=$FILE_MASSDNS
miss $outfile &&
    massdns -r "$CFGDIR/resolvers.txt" -o J -w $outfile < $FILE_SUBDOMAINS

# Subdomains with an A record
jq -r 'select(.status=="NOERROR").name[:-1]' $FILE_MASSDNS |
    sorthosts > $FILE_SUBDOMAINS_A

# Same, but IPs
jq -r '.data.answers[]?|select(.type=="A").data' $FILE_MASSDNS |
    sort -Vu > $FILE_SUBDOMAINS_IPS

# Subdomains with a CNAME
jq -r '.data.answers | select(.[0]|.type == "CNAME") | [.[0].name[:-1],.[0].data[:-1],.[1:][].data] | join(" ")' $FILE_MASSDNS |
    sort -u -k2 -k1 | column -t > $FILE_SUBDOMAINS_CNAME

# Subdomain with a CNAME that doesn't resolve to an IP
jq -r '.data.answers | select(.[0]?.type == "CNAME") | select(map(select(.type == "A"))|length == 0) | [.[0].name[:-1],.[].data[:-1]] | join(" ")' $FILE_MASSDNS |
    sort -u > $FILE_SUBDOMAINS_CNAME_NOIP

#===============================================================================
# Port scanning
#-------------------------------------------------------------------------------

outfile=$FILE_MASSCAN
miss $outfile &&
    sudo masscan -sS -p $PORTS -iL $FILE_SUBDOMAINS_IPS -oJ $FILE_MASSCAN

mk_hostsbyport_files

#===============================================================================
# HTTP probing
#-------------------------------------------------------------------------------

outfile=$FILE_HTTPX
miss $outfile &&
    cat subdomains_port_80.txt subdomains_port_443.txt |
    sort -u |
    httpx -no-color -status-code -location -title |
    sort -k2,2 -k3,3 -k4,4 > $FILE_HTTPX


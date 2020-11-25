#!/usr/bin/bash

CFGDIR="$HOME/.config/autorecon"

ROOTDIR="AUTORECON"
RUNDIR_PREFIX="RUN_"

PORTS='80,81,300,443,591,593,832,981,1010,1311,2082,2087,2095,2096,2480,3000,3128,3333,4243,4567,4711,4712,4993,5000,5104,5108,5800,6543,7000,7396,7474,8000,8001,8008,8014,8042,8069,8080,8081,8088,8090,8091,8118,8123,8172,8222,8243,8280,8281,8333,8443,8500,8834,8880,8888,8983,9000,9043,9060,9080,9090,9091,9200,9443,9800,9981,12443,16080,18091,18092,20720,28017'

FILE_ROOTDOMAINS="rootdomains.txt"
FILE_AMASS="amass.out"
FILE_SUBFINDER="subfinder.out"
FILE_SUBDOMAINS="subdomains.txt"
FILE_MASSDNS="massdns.json"
FILE_SUBDOMAINS_A="subdomains_a.txt"
FILE_SUBDOMAINS_CNAME="subdomains_cname.txt"
FILE_SUBDOMAINS_IPS="subdomains_ip.txt"
FILE_MASSCAN="masscan.json"
FILE_SUBDOMAINS_PORT="subdomains_port_*.txt"
FILE_HTTPX="httpx.out"

################################################################################
# Functions
################################################################################

init () {
    [[ ! -d $ROOTDIR ]] && mkdir $ROOTDIR
    cd $ROOTDIR
    newdir=$RUNDIR_PREFIX`date +%Y%m%d`
    [[ ! -d $newdir ]] && mkdir $newdir
    cd $newdir
}

miss () {
    fname=$1
    [[ ! -f "$fname" ]]
}

sorthosts () {
    sort -u -t. -k6,6 -k5,5 -k4,4 -k3,3 -k2,2 -k1,1
}

# Get hosts with a given IP, using the massdns json file
hosts4ip () {
    ip=$1
    jq -r 'select(.data.answers[]?.data=="'$ip'").name[:-1]' $FILE_MASSDNS
}

# Get IPs with a given port open, using the masscan json file
ips4port () {
    port=$1
    jq -r '.[]|select(.ports[].port=='$port').ip' $FILE_MASSCAN
}

# Get hosts with a given port open, using the masscan and massdns json files
hosts4port () {
    port=$1
    {
        for ip in `ips4port $port`
        do
            hosts4ip $ip
        done
    } | sorthosts
}

# For each port that was found open at least once, create a file with the hosts
# that have this port open
mk_hostsbyport_files () {
    # For each port port that is open on at least one IP
    for port in `jq '.[].ports[].port' $FILE_MASSCAN | sort -nu`
    do
        out=`echo "$FILE_SUBDOMAINS_PORT" | sed "s/\*/$port/"`
        hosts4port $port > $out
    done
}

################################################################################
# Main script
################################################################################

init

#===============================================================================
# Subdomain enumeration
#-------------------------------------------------------------------------------

# amass
outfile=$FILE_AMASS
miss $outfile &&
    amass enum -passive -df "../$FILE_ROOTDOMAINS" -o $outfile

# subfinder
outfile=$FILE_SUBFINDER
miss $outfile &&
    subfinder -dL "../$FILE_ROOTDOMAINS" -o $outfile

# Put everything together
sort -u $FILE_AMASS $FILE_SUBFINDER > $FILE_SUBDOMAINS


#===============================================================================
# DNS resolution
#-------------------------------------------------------------------------------

outfile=$FILE_MASSDNS
miss $outfile &&
    massdns -r $CFGDIR/resolvers.txt -o J -w $outfile < $FILE_SUBDOMAINS

# Subdomains with an A record
jq -r '.data.answers[]?|select(.type=="A").name[:-1]' $FILE_MASSDNS |
    sort -u > $FILE_SUBDOMAINS_A

# Same, but IPs
jq -r '.data.answers[]?|select(.type=="A").data' $FILE_MASSDNS |
    sort -Vu > $FILE_SUBDOMAINS_IPS

# Subdomains with a CNAME record
jq -r '.data.answers[]?|select(.type=="CNAME").name[:-1]' $FILE_MASSDNS |
    sort -u > $FILE_SUBDOMAINS_CNAME

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


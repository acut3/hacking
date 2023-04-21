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
FILE_REVERSE_DNS="rdns.json"
FILE_REVERSE_PORTS="rports.json"
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

init() {
  [[ ! -d $ROOTDIR ]] && mkdir $ROOTDIR
  cd $ROOTDIR || exit 1
  newdir=$RUNDIR_PREFIX$(date +%Y%m%d)
  [[ ! -d $newdir ]] && mkdir "$newdir"
  cd "$newdir" || exit 1
}

miss() {
  fname=$1
  [[ ! -f "$fname" ]]
}

sorthosts() {
  sort -u -t. -k9,9 -k8,8 -k7,7 -k6,6 -k5,5 -k4,4 -k3,3 -k2,2 -k1,1 "$@"
}

# Given a json file (or stdin), prints something that can be safely eval'ed to
# produce an associative array. The input file must be of the form:
#
# {
#   "key_1": [ "val_1_1", "val_1_2" ],
#   "key_2": [ "val_2_1" ]
# }
#
# in which cas it would print:
#
# (
# ['key_1']='val_1_1
# val_1_2'
# ['key_2']='val_2_1'
# )
#
json2hash() {
  echo '('
  jq -r 'to_entries[] | "[" + (.key|@sh) + "]=" + (.value|join("\n")|@sh)' "$@"
  echo ')'
}

mk_hostsbyport_files() {
  # Create associative arrays for fast resolutions
  local -A RPORTS RDNS
  eval "RPORTS=$(json2hash $FILE_REVERSE_PORTS)"
  eval "RDNS=$(json2hash $FILE_REVERSE_DNS)"

  # For each port that we're found open somewhere
  for port in $(jq -r 'keys_unsorted[]' $FILE_REVERSE_PORTS | sort -nu); do
    out=${FILE_SUBDOMAINS_PORT//\*/$port}
    : > "$out"
    {
      # For each IP with that port open
      for ip in ${RPORTS[$port]}; do
        # Write the corresponding hostnames into the proper per-port file
        echo "${RDNS[$ip]}"
      done
    } | sorthosts > "$out"
  done
}

################################################################################
# Main script
################################################################################

# Used for testing
if [[ "$1" = "test" ]]; then
  rm -rf TEST
  mkdir TEST
  cp -- * TEST
  cd TEST || exit 0
  time mk_hostsbyport_files
  exit 0
fi

init

#===============================================================================
# Subdomain enumeration
#-------------------------------------------------------------------------------

if [[ -e ../$FILE_BLACKLIST ]]; then
  amass_blf="-blf ../$FILE_BLACKLIST"
  awk '{gsub(/\./, "\\.");print "(^|\\.)"$0"$"}' ../$FILE_BLACKLIST >../$FILE_EGREP_BLACKLIST
else
  amass_blf=""
fi

# amass
outfile=$FILE_AMASS
# shellcheck disable=SC2086
miss $outfile &&
  # CommonCrawl is extremely slow
  amass enum -v -passive -exclude CommonCrawl -df "../$FILE_ROOTDOMAINS" $amass_blf -o $outfile

# subfinder
outfile=$FILE_SUBFINDER
miss $outfile &&
  subfinder -dL "../$FILE_ROOTDOMAINS" -o $outfile

# Put everything together
outfile=$FILE_SUBDOMAINS
if [[ -e ../$FILE_EGREP_BLACKLIST ]]; then
  miss $outfile &&
    sorthosts $FILE_AMASS $FILE_SUBFINDER |
    grep -Evf ../$FILE_EGREP_BLACKLIST >$FILE_SUBDOMAINS
else
  miss $outfile &&
    sorthosts $FILE_AMASS $FILE_SUBFINDER >$FILE_SUBDOMAINS
fi

#===============================================================================
# DNS resolution
#-------------------------------------------------------------------------------

outfile=$FILE_MASSDNS
miss $outfile &&
  massdns -r "$CFGDIR/resolvers.txt" -o J -w $outfile <$FILE_SUBDOMAINS

# Generate rDNS file, mapping IPs to a list of names
jq 'reduce (inputs | .name as $q | .data.answers[]? | select(.type == "A") + {q:$q}) as $a ({}; . + {($a.data): (.[$a.data] + [$a.q])})' $FILE_MASSDNS > $FILE_REVERSE_DNS

# Subdomains with an A record
jq -r 'select(.data.answers and ([.data.answers[] | select(.type=="A" and (.data | type=="string"))] | length > 0)).name[:-1]' $FILE_MASSDNS |
  sorthosts >$FILE_SUBDOMAINS_A

# Same, but IPs
jq -r '.data.answers[]?|select(.type=="A").data' $FILE_MASSDNS |
  sort -Vu >$FILE_SUBDOMAINS_IPS

# Subdomains with a CNAME
jq -r '.data.answers | select(.[0]|.type == "CNAME") | [.[0].name[:-1],.[0].data[:-1],.[1:][].data] | join(" ")' $FILE_MASSDNS |
  sort -u -k2 -k1 | column -t >$FILE_SUBDOMAINS_CNAME

# Subdomain with a CNAME that doesn't resolve to an IP
jq -r '.data.answers | select(.[0]?.type == "CNAME") | select(map(select(.type == "A"))|length == 0) | [.[0].name[:-1],.[].data[:-1]] | join(" ")' $FILE_MASSDNS |
  sort -u >$FILE_SUBDOMAINS_CNAME_NOIP


#===============================================================================
# Port scanning
#-------------------------------------------------------------------------------

outfile=$FILE_MASSCAN
miss $outfile &&
  sudo masscan -sS -p $PORTS -iL $FILE_SUBDOMAINS_IPS -oJ $FILE_MASSCAN

# Generage rPorts file, mapping ports to a list of IPs that have them open
jq -r 'reduce (.[] | .ip as $ip | .ports[] | select(.status == "open") | {ip: $ip, port: (.port|tostring)}) as $r ({}; . + {($r.port): (.[$r.port] + [$r.ip])})' $FILE_MASSCAN > $FILE_REVERSE_PORTS

mk_hostsbyport_files

#===============================================================================
# HTTP probing
#-------------------------------------------------------------------------------

outfile=$FILE_HTTPX
miss $outfile &&
  cat subdomains_port_80.txt subdomains_port_443.txt |
  sort -u |
    httpx -no-color -status-code -location -title |
    sort -k2,2 -k3,3 -k4,4 >$FILE_HTTPX

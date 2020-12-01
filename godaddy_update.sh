#!/bin/bash

# Written by Thomas Galea.
# github.com/TDGalea/GoDaddy-Update
#
# You are free to do whatever you like with this script. I simply ask that you preserve my credit and those below.
#
# GoDaddy record update script. When automated (by a cron job, etc.) this script can be used to create a DDNS updater for your GoDaddy domain(s).
# This script supports updating multiple domains and records in one execution, whether under one API key or multiple.
#
# Inspired by the Python script written by Carl Edman (github.com/CarlEdman/godaddy-ddns) which simply did not work for me (and seems to be a dead project)
# and then furthermore by the Bash scripts posted at godaddy.com/community/Managing-Domains/Dynamic-DNS-Updates/td-p/7862, which worked, but had to be hard-coded.

# No arguments passed, or -h.
[[ "$1" == "-h" ]] || [[ -z $1 ]] && \
	printf "Usage:\n" && \
	printf "	$0 {-k key} {-s secret} {-d domain1} {-r record1} [-n] ...\n" && \
	printf "	You must specify all four values at least once. If you specify -n, you can update any entry\n" && \
	printf "	(key, secret, domain, host) for another domain. Any you don't update before the next -n (or end of line) will be reused.\n\n" && \

	printf "	Valid options are:\n" && \
	printf "		-k : API Key. Visit developer.godaddy.com if you need one.\n" && \
	printf "		-s : API Secret. Visit developer.godaddy.com if you need one.\n" && \
	printf "		-d : Domain name (example.com).\n" && \
	printf "		-r : Record. If updating the domain itself, use '@', otherwise, this is used to update hosts under a domain, for example, 'ex' in 'ex.ample.com'.\n" && \
	printf "		-h : Print this help.\n" && \
	exit 0

# Get current external IP address. There are many services that can do this, but icanhazip is the only I currently know of which outputs literally just the IP. No need for ugly regex.
ip=`curl ipv4.icanhazip.com 2>/dev/null`
key=""
sec=""
dom=""
rec=""
ttl=""

# Loop until there are no arguments remaining.
until [[ -z $@ ]];do
	# Loop until current first argument is either -n or blank.
	until [[ "$1" = "-n" ]] || [[ -z $1 ]];do
		case $1 in \
			-k ) [[ ! -z $2 ]] && key=$2 && shift || printf "'$1' has no argument!\n";;
			-s ) [[ ! -z $2 ]] && sec=$2 && shift || printf "'$1' has no argument!\n";;
			-d ) [[ ! -z $2 ]] && dom=$2 && shift || printf "'$1' has no argument!\n";;
			-r ) [[ ! -z $2 ]] && rec=$2 && shift || printf "'$1' has no argument!\n";;
			-t ) [[ ! -z $2 ]] && ttl=$2 && shift || printf "'$1' has no argument!\n";;
			-egg ) printf "¯\\_(ツ)_/¯\n" && shift;;
			 * ) printf "Unrecognised argument '$1'\n" && shift;; \
		esac
		shift
	done

	# If no TTL was specified, use 3600 seconds (1 hour).
	[[ -z $ttl ]] && ttl=3600
	# Make sure all required params are occupied.
	con=1
	[[ -z $key ]] && printf "Missing key! Use '-h' if you need help.\n"    && con=0
	[[ -z $sec ]] && printf "Missing secret! Use '-h' if you need help.\n" && con=0
	[[ -z $dom ]] && printf "Missing domain! Use '-h' if you need help.\n" && con=0
	[[ -z $rec ]] && printf "Missing record! Use '-h' if you need help.\n" && con=0
	# Exit if any were missing.
	[[ $con = 0 ]] && exit 2

	# Find what the current IP of the GoDaddy record is.
	gdip=`curl -s -X GET -H "Authorization: sso-key $key:$sec" "https://api.godaddy.com/v1/domains/$dom/records/A/$rec" 2>/dev/null`
	gdip=`printf "$gdip" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"`

	# Only bother updating if the IPs are actually different.
	[[ "$gdip" = "$ip" ]] && \
		printf "Record '$rec' of domain '$dom' is already up to date.\n" \
	||	(
		printf "Updating record '$rec' of domain '$dom'.\n"
		request='{"data":"'$ip'","ttl":3600}'
		curl -s -X PUT "https://api.godaddy.com/v1/domains/$dom/records/A/$rec" -H "Authorization: sso-key $key:$sec" -H "Content-Type: application/json" -d "[{\"data\": \"$ip\",\"ttl\":$ttl}]" 2>/dev/null
   		)

	shift
done

exit 0

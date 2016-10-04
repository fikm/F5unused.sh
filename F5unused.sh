#!/bin/bash
# 
# Check unused parts of F5 (LTM) configuration
# 
# TODO: # LTM monitors
# TODO: # LTM ssl server profiles
# TODO: # sys cert files

PARTITION="*" # Particular partition ( e.x. "Common" or * - for ALL)

#tmp files
ALL_LIST=$(mktemp ALLXXXX)
US_LIST=$(mktemp USEDXXXX)
UNUSED_LIST=$(mktemp UNUSEDXXXX)

PROGNAME=${0##*/}
VERSION="0.05"
# check parts switch
_CHECK_ALL=1
_NODES=0
_POOLS=0
_POLICIES=0
_CLIENT_SSL=0
_SERVER_SSL=0

get_unused() {
	touch $UNUSED_LIST
	for i in $(cat $ALL_LIST); do
		grep -qE $i\$ $US_LIST
		greprc=$?
		if [[ $greprc -eq 1 ]] ; then
	    		echo $i >> $UNUSED_LIST
	fi
done
}
graceful_exit() { # normal exit function.
  clean_up
  exit
}

clean_up () { # Perform pre-exit housekeeping
	if [ -e $UNUSED_LIST ]; then
		rm $USED_LIST
	fi
	if [ -e $UNUSED_LIST ]; then
		rm $US_LIST
	fi
	if [ -e $ALL_LIST ]; then
		rm $ALL_LIST
	fi
}
	
help_message() {
cat <<- _EOF_
	$PROGNAME ver. $VERSION
	Check unused parts of F5 (LTM) configuration

	Options:
	  -h, --help       Display this help message and exit
	  -d, --debug      Outputs debug information
	  -p, --partition  Check in ... partition only (default is all - or set by $PARTITION)
	  -f, --force      Force delete of unused parts !!!AWARE!!! ( but not supported yet :) )
	  -a, --all        Check all parts (default)
	  -N, --nodes	   Check LTM nodes
	  -P, --pools	   Check LTM pools
	  -O, --policies   Check LTM policies
	  -C, --client-ssl Check LTM client ssl profiles
	  -S, --server-ssl Check LTM server ssl profiles (not supported yet)
	  -q, --quiet	   Quiet mode (only outputs on error)

	_EOF_
}

debug() { # write out debug info if the debug flag has been set
  if [ ${_USE_DEBUG} -eq 1 ]; then
    echo "$@"
  fi
}

# Parse command-line
while [[ -n $1 ]]; do
  case $1 in
    -h | --help)
      help_message; graceful_exit ;;
    -d | --debug)
     _USE_DEBUG=1 ;;
    -f | --force)
     _FORCE=1 ;;
    -a | --all)
     _CHECK_ALL=1 ;;
    -q | --quiet)
     _QUIET=1 ;;
    -p)
      shift; PARTITION="$1" ;;
    -N)
     _CHECK_ALL=0;_NODES=1 ;;
    -P)
     _CHECK_ALL=0;_POOLS=1 ;;	
	-O)
     _CHECK_ALL=0;_POLICIES=1 ;;	
	-C)
     _CHECK_ALL=0;_CLIENT_SSL=1 ;;	
	-S)
     _CHECK_ALL=0;_SERVER_SSL=1 ;;    
    -* | --*)
      usage
      error_exit "Unknown option $1" ;;
    *)
      DOMAIN="$1" ;;
  esac
  shift
done
cat <<- _EOF_
	$PROGNAME ver. $VERSION
	Check unused parts of F5 (LTM) configuration
	use $PROGNAME -h for help
	_EOF_
	
# LTM Policies
if [ ${_POLICIES} -eq 1 ] || [ ${_CHECK_ALL} -eq 1 ]; then
	echo ""
	echo "unused LTM policies"
	## List of used policies
	tmsh list ltm virtual \/$PARTITION\/\* policies | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | grep -v none | sed 's/^ltm\ virtual\ //' | sed 's/\ {\ policies\ {\ /;/' | sed 's/\ {\ }\ }\ }//' | sed 's/\ {\ }\ /\n/g' | cut -d ";" -f2  | sort | uniq > $US_LIST
	## List of all policies
	tmsh list ltm policy \/$PARTITION\/\* | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | cut -d " " -f 3  | sort | uniq > $ALL_LIST
	if [ -e $UNUSED_LIST ]; then
		rm $UNUSED_LIST
	fi
	get_unused
	echo "All policies: " $(cat $ALL_LIST | wc -l)" used: "$(cat $US_LIST | wc -l)" unused: "$(cat $UNUSED_LIST | wc -l)
	if [ -e $UNUSED_LIST ]; then
		echo "(Remove by: tmsh delete ltm policy [policy])" 
		cat $UNUSED_LIST
		clean_up
	fi
fi
# LTM ssl client profiles
if [ ${_CLIENT_SSL} -eq 1 ] || [ ${_CHECK_ALL} -eq 1 ]; then
	echo ""
	echo "unused LTM ssl client profiles"
	## List of used profiles
	tmsh list ltm virtual \/$PARTITION\/\* profiles | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | grep -Po '\/[a-zA-Z]+\/[a-zA-Z-.0-9_]+\ \{\ context\ clien' | cut -d " " -f 1 | sort | uniq > $US_LIST
	## List of all profiles
	tmsh list ltm profile client-ssl \/$PARTITION\/\* cert | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | cut -d " " -f 4 > $ALL_LIST
	if [ -e $UNUSED_LIST ]; then
		rm $UNUSED_LIST
	fi
	get_unused
	echo "All profiles: " $(cat $ALL_LIST | wc -l)" used: "$(cat $US_LIST | wc -l)" unused: "$(cat $UNUSED_LIST | wc -l)
	if [ -e $UNUSED_LIST ]; then
		echo "(Remove by: tmsh delete ltm profile client-ssl [policy])" 
		cat $UNUSED_LIST
		clean_up
	fi
fi
# LTM pools
if [ ${_POOLS} -eq 1 ] || [ ${_CHECK_ALL} -eq 1 ]; then
	echo ""
	echo "unused LTM pools"
	## List of used pools
	tmsh list ltm virtual \/$PARTITION/\* pool | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | grep -Po 'pool\ \K[a-zA-Z-.0-9_\/]+' | grep -v none > $US_LIST
	for i in $(tmsh list ltm policy \/$PARTITION/\* | sed ':a;$!N;/\nltm/!s/\s*\n\s*/ /;ta;P;D' | cut -d " " -f 3  | sort | uniq); do tmsh list ltm policy $i rules | grep -Po '\ pool\ \K[a-zA-Z-.0-9_\/]+' | grep -v none; done >> $US_LIST
	cat $US_LIST | sort | uniq > $US_LIST"_2"
	mv -f $US_LIST"_2" $US_LIST
	## List of all pools
	tmsh list ltm pool \/$PARTITION\/\* one-line | cut -d " " -f 3 > $ALL_LIST
	if [ -e $UNUSED_LIST ]; then
		rm $UNUSED_LIST
	fi
	get_unused
	echo "All pools: " $(cat $ALL_LIST | wc -l)" used: "$(cat $US_LIST | wc -l)" unused: "$(cat $UNUSED_LIST | wc -l)
	if [ -e $UNUSED_LIST ]; then
		echo "(Remove by: tmsh delete ltm pool [pool])" 
		cat $UNUSED_LIST
		clean_up
	fi
fi
# LTM nodes
if [ ${_NODES} -eq 1 ] || [ ${_CHECK_ALL} -eq 1 ]; then
	echo ""
	echo "unused LTM nodes"
	## List of used nodes
	tmsh list ltm pool /$PARTITION/* | grep -Po '\/[a-zA-Z0-9-]+\/[a-zA-Z0-9-.]+\:' | cut -d ":" -f1 > $US_LIST
	## List of all nodes
	tmsh list ltm node \/$PARTITION\/\* one-line | cut -d " " -f 3  > $ALL_LIST
	if [ -e $UNUSED_LIST ]; then
		rm $UNUSED_LIST
	fi
	get_unused
	echo "All nodes: " $(cat $ALL_LIST | wc -l)" used: "$(cat $US_LIST | wc -l)" unused: "$(cat $UNUSED_LIST | wc -l)
	if [ -e $UNUSED_LIST ]; then
		echo "(Remove by: tmsh delete ltm node [node])" 
		cat $UNUSED_LIST
		clean_up
	fi
fi
#
clean_up

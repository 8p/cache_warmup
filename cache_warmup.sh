#!/bin/bash

# vars
verbose=0
grep_date=`date --date="yesterday" +%d/%b/%Y`
url_file="urls_`date +%Y%m%d`.txt"
hitrate=10
concurrency=3
invert_match="(no_cache=1|\.gif|\.jpeg|.jpg)"

# define help function
function help(){
    echo "Website Cache WarmUp";
    echo "parsing apache log, finding and open most hit urls"
    echo "=================================================="
    echo "Usage example:";
    echo "cache-warmup (-l|--logfile) string (-u|--url) string [(-h|--help)] [(-v|--verbose)] [(-c|--concurrency) integer] [--hitrate integer]";
    echo
    echo "Options:";
    echo "-h or --help:                    displays this information";
    echo "-v or --verbose:                 verbose mode on";
    echo "-l or --logfile (string):        apache logfile. required";
    echo "-c or --concurrency (integer):   concurrency (threads)";
    echo "--hitrate (integer):             hitrate in apache log";
    echo "-u or --url (string):            base url with protocol. required";
    exit 1;
}

# execute getopt
ARGS=$(getopt -o "hvl:c:u:" -l "help,verbose,logfile:,concurrency:,hitrate:,url:" -n "Cache WarmUp" -- "$@");

# bad arguments :)
if [ $? -ne 0 ];
then
    help;
fi

eval set -- "$ARGS";

while true; do
    case "$1" in
        -h|--help)
            shift;
            help;
            ;;
        -v|--verbose)
            shift;
                    verbose="1";
            ;;
        -l|--logfile)
            shift;
                    if [ -n "$1" ]; 
                    then
                        logfile="$1";
                        shift;
                    fi
            ;;
        -c|--concurrency)
            shift;
                    if [ -n "$1" ]; 
                    then
                        concurrency="$1";
                        shift;
                    fi
            ;;
        --hitrate)
            shift;
                    if [ -n "$1" ]; 
                    then
                        hitrate="$1";
                        shift;
                    fi
            ;;
        -u|--url)
            shift;
                    if [ -n "$1" ]; 
                    then
                        url="$1";

                        shift;
                    fi
            ;;

        --)
            shift;
            break;
            ;;
    esac
done

# check required arguments
if [ -z "$logfile" ]
then
    echo "logfile is required. use help for more information";
    exit 1
fi

if [ -z "$url" ]
then
    echo "base url is required. use help for more information";
    exit 1
fi

# check if given logfile exists
if [ ! -f $logfile ]
then
    echo "logfile does not exist: $logfile"
    exit 1
fi

# save URLs to temp file
cat $logfile | grep $grep_date | egrep "\.html.* HTTP" | grep -v -E $invert_match | awk '{ print $7 }'  | sort | uniq -c | sort -n -r | awk '$1 >= '"$hitrate" | awk -v url="$url" '{ print url$2 }'  >  $url_file

# check if temp url file has been created
if [ ! -f $url_file ]
then
    echo "missing generated url file ($url_file)"
    exit 1
fi

# look for siege, alternative: wget (no multiple threads)
if which siege >/dev/null; then
    echo "siege found"
    
    reps=`wc -l $url_file | awk '{ print $1 }'`
    arguments="--delay=1 -i --file=$url_file --concurrent=$concurrency --reps=$reps"
    
    if [ $verbose = 1 ]
    then
        arguments="$arguments -v"
    else
        arguments="$arguments -q"
    fi

    echo "executing => siege $arguments"
    
    siege $arguments 
else
    echo "siege not found, using wget"
    
    arguments="--spider -i $url_file"
    
    if [ $verbose = 1 ]
    then
        arguments="$arguments -v"
    else
        arguments="$arguments -q"
    fi
    
    echo "executing => wget $arguments"

    wget $arguments
fi

# remove temp url file
rm $url_file

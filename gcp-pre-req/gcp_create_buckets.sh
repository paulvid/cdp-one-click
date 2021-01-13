#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <prefix> <region>

Description:
    Checks if resource exists (returns yes or no)

Arguments:
    prefix:   prefix for your assets
    region:   region for your buckets
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage
if [[ (${1:-x} == "--help") || ${1:-x} == "-h" ]]; then
    display_usage
    exit 0
fi

# Check the numbers of arguments
if [ $# -lt 2 ]; then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [ $# -gt 2 ]; then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

prefix=$1
region=$2

gsutil mb -c STANDARD -l ${region} -b on gs://$prefix-cdp-logs
gsutil mb -c STANDARD -l ${region} -b on gs://$prefix-cdp-data
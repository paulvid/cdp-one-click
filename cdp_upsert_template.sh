#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <base_dir> <file_name> <template_name> [--help or -h]

Description:
    Upserts a template based on its name

Arguments:
    base_dir:       the base directory of the github code     
    file_name:      name of the json template under cdp-cluster-templates
    template_name:  name of the template as it will appear in CDP (don't use spaces or underscores)
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 3 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 3 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 



# Get variables
base_dir=${1}
name=${3}
content=file://${base_dir}/cdp-cluster-templates/${2}

# Checking if recipe already exist
response=$(${base_dir}/cdp_describe_template.sh ${name} 2> /dev/null | jq -r .recipe.recipeName | wc -l)

if [ $response -ne 0 ]
then
    cdp datahub delete-cluster-templates --cluster-template-names ${name}
fi




cdp datahub create-cluster-template --cluster-template-name ${name} --cluster-template-content ${content}
#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 


 display_usage() { 
	echo "
Usage:
    $(basename "$0") <base_dir> <file_name> <recipe_name> <recipe_type> [--help or -h]

Description:
    Upserts a recipe based on its name

Arguments:
    base_dir:       the base directory of the github code     
    file_name:      name of the recipe script under cdp-recipes
    recipe_name:    name of the recipe as it will appear in CDP (don't use spaces or underscores)
    recipe_type:    recipe type in [POST_CLUSTER_INSTALL, POST_CLOUDERA_MANAGER_START, PRE_CLOUDERA_MANAGER_START, PRE_TERMINATION]
    --help or -h:   displays this help"

}

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 4 ] 
then 
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi 

if [  $# -gt 4 ] 
then 
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi 



# Get variables
base_dir=${1}
name=${3}
content=file://${base_dir}/cdp-recipes/${2}
type=${4}

# Checking if recipe already exist
response=$(${base_dir}/cdp_describe_recipe.sh ${name} 2> /dev/null | jq -r .recipe.recipeName | wc -l)

if [ $response -ne 0 ]
then
    cdp datahub delete-recipes --recipe-names ${name}
fi




cdp datahub create-recipe --recipe-name ${name} --recipe-content ${content} --type ${type}
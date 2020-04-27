#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh

 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [<network_file>] [--help or -h]

Description:
    Creates AWS pre-requisites, CDP environment, data lake and a data hub clusters + tags the instances to the proper Cloudera policies

Arguments:
    parameter_file: location of your parameter json file (template can be found in parameters_template.json)
    network_file:   (optional) location of your auto-generated network json file (setup to \${base_dir}/aws-pre-req/\${prefix}_aws_network.json)"

}


# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $1 == "--help") ||  $1 == "-h" ]] 
then 
    display_usage
    exit 0
fi 


# Check the numbers of arguments
if [  $# -lt 1 ] 
then 
    echo "Not enough arguments!"  >&2
    display_usage
    exit 1
fi 

if [  $# -gt 2 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

# Parsing arguments
parse_parameters ${1}



    
# Creating environment
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating AWS CDP environment for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 1. Environment
if [[ "$create_network" = "yes" ]]
then

    network_file=${2}
    igw_id=$(cat ${network_file} | jq -r .InternetGatewayId)
    vpc_id=$(cat ${network_file} | jq -r .VpcId)
    subnet_id1a=$(cat ${network_file} | jq -r .Subnets[0])
    subnet_id1b=$(cat ${network_file} | jq -r .Subnets[1])
    subnet_id1c=$(cat ${network_file} | jq -r .Subnets[2])
    route_id=$(cat ${network_file} | jq -r .RouteTableId)
    knox_sg_id=$(cat ${network_file} | jq -r .KnoxGroupId)
    default_sg_id=$(cat ${network_file} | jq -r .DefaultGroupId)
    result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" $subnet_id1a $subnet_id1b $subnet_id1c $vpc_id $knox_sg_id $default_sg_id 2>&1 > /dev/null)
    handle_exception $? $prefix "environment creation" "$result"
else
    result=$($base_dir/cdp_create_aws_env.sh $prefix $credential $region "$key" 2>&1 > /dev/null)
    handle_exception $? $prefix "environment creation" "$result"
fi

sleep 200 # to avoid environment not found exception

env_status=$($base_dir/cdp_describe_env.sh  $prefix | jq -r .environment.status)


spin='🌑🌒🌓🌔🌕🌖🌗🌘'
while [ "$env_status" != "AVAILABLE" ]
do 
    i=$(( (i+1) %8 ))
    printf "\r${spin:$i:1}  $prefix: environment status: $env_status                             "
    sleep 2
    env_status=$($base_dir/cdp_describe_env.sh  $prefix | jq -r .environment.status)
done

printf "\r${CHECK_MARK}  $prefix: environment status: $env_status                             "
echo ""

# 2. IDBroker mappings
result=$($base_dir/cdp_aws_create_group_iam.sh $base_dir $prefix 2>&1 > /dev/null)
handle_exception $? $prefix "idbroker mappings creation" "$result"

echo "${CHECK_MARK}  $prefix: idbroker mappings set"
echo ""
echo ""
echo "CDP environment for $prefix created!"
echo ""


# Creating datalake
echo "⏱  $(date +%H%Mhrs)"
echo ""
echo "Creating CDP datalake for $prefix:"
underline="▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
for ((i=1;i<=$prefix_length;i++))
do
    underline=${underline}"▔"
done
echo ${underline}
echo ""

# 3. Datalake
result=$($base_dir/cdp_create_aws_datalake.sh $base_dir $prefix 2>&1 > /dev/null)
handle_exception $? $prefix "datalake creation" "$result"

dl_status=$($base_dir/cdp_describe_dl.sh  $prefix | jq -r .datalake.status)

spin='🌑🌒🌓🌔🌕🌖🌗🌘'
while [ "$dl_status" != "RUNNING" ]
do 
    i=$(( (i+1) %8 ))
    printf "\r${spin:$i:1}  $prefix: datalake status: $dl_status                              "
    sleep 2
    dl_status=$($base_dir/cdp_describe_dl.sh  $prefix | jq -r .datalake.status)
done


printf "\r${CHECK_MARK}  $prefix: datalake status: $dl_status                             "

# 4. Creating user workload password
result=$($base_dir/cdp_set_workload_pwd.sh ${workload_pwd} 2>&1 > /dev/null)
handle_exception $? $prefix "workload password setup" "$result"

echo "" 
echo "${CHECK_MARK}  $prefix: workload password setup " 

# 5. Syncing users
result=$($base_dir/cdp_sync_users.sh $prefix  2>&1 > /dev/null)
if [ $? -ne 255 ] 
then
    handle_exception $? $prefix "syncing users" "$result"
    echo "${CHECK_MARK}  $prefix: user sync launched "  
else 
    echo "${CHECK_MARK}  $prefix: user sync was already in progress "  
fi

# 6. Tag FreeIPA Instance

for i in $(aws ec2 describe-instances  --filters "Name=tag:owner,Values=$1" "Name=iam-instance-profile.arn,Values=arn:aws:iam::${AWS_ACCOUNT_ID}:instance-profile/${prefix}-log-role" "Name=tag:Name,Values=*freeipa*" | jq -r .Reservations[].Instances[].InstanceId); do
    aws ec2 create-tags  --resources $i --tags Key=enddate,Value=$END_DATE   Key=project,Value="${PROJECT}"
    echo "" 
    echo "${CHECK_MARK}  $prefix: freeipa instance tagged " 
done

echo ""
echo ""
echo "CDP datalake for $prefix created!"
echo ""
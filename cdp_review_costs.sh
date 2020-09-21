#!/bin/bash 
source $(cd $(dirname $0); pwd -L)/common.sh
 display_usage() { 
	echo "
Usage:
    $(basename "$0") <parameter_file> [--help or -h]

Description:
    Verifies compliance with Cloudera policies and evaluates costs per environment

Arguments:
    parameter_file: location of your parameter json file"

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

if [  $# -gt 1 ] 
then 
    echo "Too many arguments!"  >&2
    display_usage
    exit 1
fi 

sdx_cost_hourly=0
sdx_cost_daily=0
dh_cost_hourly=0
dh_cost_daily=0
ml_cost_hourly=0
ml_cost_daily=0
op_cost_hourly=0
op_cost_daily=0
total_dh_cost_hourly=0
total_dh_cost_daily=0
total_ml_cost_hourly=0
total_ml_cost_daily=0
total_op_cost_hourly=0
total_op_cost_daily=0
parse_parameters ${1}

# echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
# echo "┃ Evaluating costs and compliance ┃"
# echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
# echo ""




#AWS 
if [[ ${cloud_provider} == "aws" ]]
then


# 1. SDX Costs

    SDX_NUM_ELEMENTS=$(jq '.config.sdx | length' cost/aws_sdx_instances.json)
    SDX_NUM_ELEMENTS=$((SDX_NUM_ELEMENTS-1))

    for i in $(seq 0 ${SDX_NUM_ELEMENTS});
    do
        INSTANCE_TYPE=$(jq -r ".config.sdx[${i}].instanceTypes[].size" cost/aws_sdx_instances.json)
        OUTPUT=$(curl -s 'https://ec2.shop?format=json' | jq ".Prices[] | select(.InstanceType==\"${INSTANCE_TYPE}\")".Cost)
        if [ ${#OUTPUT} -eq 0 ]; then OUTPUT=0; fi
        sdx_cost_hourly=$(ruby -e "total_cost=(${sdx_cost_hourly}+${OUTPUT});puts total_cost")
    done

    sdx_cost_daily=$(ruby -e "total_cost=(${sdx_cost_hourly}*24);puts total_cost")


# 2. dh costs
for item in $(echo ${datahub_list} | jq -r '.[] | @base64'); do
        _jq() {
        echo ${item} | base64 --decode | jq -r ${1}
        }
        definition=$(_jq '.definition')
        custom_script=$(_jq '.custom_script')
        for row in $(cat $base_dir/cdp-cluster-definitions/${cloud_provider}/$definition | jq -r '.instanceGroups[] | @base64'); do
            _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
            }
            node_count=$(_jq '.nodeCount')
            instance_type=$(_jq '.template.instanceType')
            OUTPUT=$(curl -s 'https://ec2.shop?format=json' | jq ".Prices[] | select(.InstanceType==\"${instance_type}\")".Cost)

            #OUTPUT="$(cat cost/aws_pricing_calculator_version_0.01.json | jq ".config.regions[] | select(.region==\"${region}\").instanceTypes[].sizes[] | select (.size==\"${instance_type}\").valueColumns[].prices.USD" | bc -l | xargs printf "%.3f")"
            if [ ${#OUTPUT} -eq 0 ]; then OUTPUT=0; fi
            dh_cost_hourly=$(ruby -e "total_cost=(${dh_cost_hourly}+(${OUTPUT}*${node_count}));puts total_cost")
        done

    dh_cost_daily=$(ruby -e "total_cost=(${dh_cost_hourly}*24);puts total_cost")
    total_dh_cost_hourly=$(ruby -e "total_cost=(${total_dh_cost_hourly}+${dh_cost_hourly});puts total_cost")
    total_dh_cost_daily=$(ruby -e "total_cost=(${total_dh_cost_daily}+${dh_cost_daily});puts total_cost")
done 

# 3. ML costs
for item in $(echo ${ml_workspace_list} | jq -r '.[] | @base64'); do
    _jq() {
      echo ${item} | base64 --decode | jq -r ${1}
    }
    
    definition=$(_jq '.definition')
    
    for row in $(cat $base_dir/cml-workspace-definitions/${cloud_provider}/$definition | jq -r '.instanceGroups[] | @base64'); do
            _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
            }
            minInstances=$(_jq '.autoscaling.minInstances')
            maxInstances=$(_jq '.autoscaling.maxInstances')
            avgInstances=$(ruby -e "avg=((${minInstances}+${maxInstances})/2);puts avg")
            instanceType=$(_jq '.instanceType')
            OUTPUT=$(curl -s 'https://ec2.shop?format=json' | jq ".Prices[] | select(.InstanceType==\"${instanceType}\")".Cost)
            #OUTPUT="$(cat cost/aws_pricing_calculator_version_0.01.json | jq ".config.regions[] | select(.region==\"${region}\").instanceTypes[].sizes[] | select (.size==\"${instanceType}\").valueColumns[].prices.USD" | bc -l | xargs printf "%.3f")"
            if [ ${#OUTPUT} -eq 0 ]; then OUTPUT=0; fi
            ml_cost_hourly=$(ruby -e "total_cost=(${ml_cost_hourly}+(${OUTPUT}*${avgInstances}));puts total_cost")
    done
    ml_cost_daily=$(ruby -e "total_cost=(${ml_cost_hourly}*24);puts total_cost")
    total_ml_cost_hourly=$(ruby -e "total_cost=(${total_ml_cost_hourly}+${ml_cost_hourly});puts total_cost")
    total_ml_cost_daily=$(ruby -e "total_cost=(${total_ml_cost_daily}+${ml_cost_daily});puts total_cost")

done

# 4. OP costs
for item in $(echo ${op_db_list} | jq -r '.[] | @base64'); do
    _jq() {
      echo ${item} | base64 --decode | jq -r ${1}
    }

    OPDB_NUM_ELEMENTS=$(jq '.config.opdb | length' cost/aws_opdb_instances.json)
    OPDB_NUM_ELEMENTS=$((SDX_NUM_ELEMENTS-1))

    for i in $(seq 0 ${SDX_NUM_ELEMENTS});
    do
        INSTANCE_TYPE=$(jq -r ".config.opdb[${i}].instanceTypes[].size" cost/aws_opdb_instances.json)
        OUTPUT=$(curl -s 'https://ec2.shop?format=json' | jq ".Prices[] | select(.InstanceType==\"${INSTANCE_TYPE}\")".Cost)
        if [ ${#OUTPUT} -eq 0 ]; then OUTPUT=0; fi
        op_cost_hourly=$(ruby -e "total_cost=(${op_cost_hourly}+${OUTPUT});puts total_cost")
    done

    op_cost_daily=$(ruby -e "total_cost=(${op_cost_hourly}*24);puts total_cost")
    total_op_cost_hourly=$(ruby -e "total_cost=(${total_op_cost_hourly}+${op_cost_hourly});puts total_cost")
    total_op_cost_daily=$(ruby -e "total_cost=(${total_op_cost_daily}+${op_cost_daily});puts total_cost")

    
done


# 4. Totals
echo ""
echo "Deployment estimated costs:"
echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
printf "\n💰 Total SDX cost/hour:     $%0.2f" ${sdx_cost_hourly}
printf "\n💰 Total datahub cost/hour: $%0.2f" ${total_dh_cost_hourly}
printf "\n💰 Total ml cost/hour:      $%0.2f" ${total_ml_cost_hourly}
printf "\n💰 Total op cost/hour:      $%0.2f" ${total_op_cost_hourly}
printf "\n                            ▔▔▔▔▔▔"
printf "\n                            $%0.2f" $(ruby -e "total_cost=(${sdx_cost_hourly}+${total_dh_cost_hourly}+${total_ml_cost_hourly}+${total_op_cost_hourly});puts total_cost")
echo ""
printf "\n💰 Total SDX cost/day:      $%0.2f" ${sdx_cost_daily}
printf "\n💰 Total datahub cost/day:  $%0.2f" ${total_dh_cost_daily}
printf "\n💰 Total ml cost/day:       $%0.2f" ${total_ml_cost_daily}
printf "\n💰 Total op cost/day:       $%0.2f" ${total_op_cost_daily}
printf "\n                            ▔▔▔▔▔▔"
printf "\n                            $%0.2f" $(ruby -e "total_cost=(${sdx_cost_daily}+${total_dh_cost_daily}+${total_ml_cost_daily}+${total_op_cost_daily});puts total_cost")
echo ""
printf "\nPlease remember to delete your assets (run cdp_delete_all_the_things.sh) when you're finished!\n"
echo ""
read -p "Do you agree to delete all these assets when you're finished? (Y for Yes, N for No)" -n 1 -r

    # Cost Calculator
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo ""
        echo ""
        echo "💥 You must agree to delete your assets when you're finished!"  >&2
        exit 2
    fi

echo ""
# echo ""
# echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
# echo "┃ Costs and compliance evaluated ┃"
# echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
# echo ""



fi

#Azure
if [[ ${cloud_provider} == "az" ]]
then

printf "💰 Estimated costs for Azure coming soon! 💰"

fi
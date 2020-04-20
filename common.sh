#####################
# Arguments:        #
#   $1 -> retcode   #
#   $2 -> prefix    #
#   $2 -> operation #
#   $3 -> error     #
#####################
handle_exception()
{
    if [ "$1" -ne "0" ]; then
        prefix=$2
        operation=$3
        error=$4
        echo ""
        echo "🚫  $prefix: error during operation: $operation"
        echo ""
        echo "Error details:"
        echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
        echo "$error"
        echo ""
        
        exit $1
    fi
}

#########################
# Arguments:            #
#   $1 -> param value   #
#   $2 -> required flag #
#   $3 -> default value #
#########################
handle_null_param()
{
    param_value=$1
    required=$2
    default_value=$3

    if [[ ${param_value} == "null" ]]; then
        if [[ ${required} == "yes" ]]; then
            echo ""
            echo "🚫  error during parsing parameters"
            echo ""
            echo "Error details:"
            echo "▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
            echo "required parameter is null"
            echo ""
            exit 1
        else
           echo ${default_value}
        fi
    else 
        if [[ ${required} == "no" ]]; then
            echo ${param_value}
        fi
    fi
}


#########################
# Arguments:            #
#   $1 -> file to parse #
#########################
parse_parameters() 
{
    # Parsing arguments

    # File to parse
    param_file=${1}

    # Required parameters
    prefix=$(cat ${param_file} | jq -r .required.prefix)
    handle_null_param "$prefix" "yes" 0

    credential=$(cat ${param_file} | jq -r .required.credential)
    handle_null_param "$credential" "yes" 0

    region=$(cat ${param_file} | jq -r .required.region)
    handle_null_param "$region" "yes" 0

    key=$(cat ${param_file} | jq -r .required.key)
    handle_null_param "$key" "yes" 0

    workload_pwd=$(cat ${param_file} | jq -r .required.workload_pwd)
    handle_null_param "$workload_pwd" "yes" 0

    datahub_list=$(cat ${param_file} | jq -r .required.datahub_list)
    ml_workspace_list=$(cat ${param_file} | jq -r .required.ml_workspace_list)

    # Optional parameters
    cloud_provider=$(cat ${param_file} | jq -r .optional.cloud_provider)
    cloud_provider=$(handle_null_param "$cloud_provider" "no" "aws")

    cloud_profile=$(cat ${param_file} | jq -r .optional.cloud_profile)
    cloud_profile=$(handle_null_param "$cloud_profile" "no" "default")

    cdp_profile=$(cat ${param_file} | jq -r .optional.cdp_profile)
    cdp_profile=$(handle_null_param "$cdp_profile" "no" "default")

    end_date=$(cat ${param_file} | jq -r .optional.tags.end_date)
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        default_date=$(date -d "$dt +3 day" "+%m%d%Y")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        default_date=$(date -v+3d "+%m%d%Y")
    else 
        default_date="05202020"
    fi

    
    end_date=$(handle_null_param "$end_date" "no" "$default_date")

    default_project=$prefix"_one_click_project"
    project=$(cat ${param_file} | jq -r .optional.tags.project)
    project=$(handle_null_param "$project" "no" "$default_project")

    generate_credential=$(cat ${param_file} | jq -r .optional.generate_credential)
    generate_credential=$(handle_null_param "$generate_credential" "no" "no")

    external_id=$(cat ${param_file} | jq -r .optional.external_id)
    external_id=$(handle_null_param "$external_id" "no" "not_provided")

    generate_minimal_cross_account=$(cat ${param_file} | jq -r .optional.generate_minimal_cross_account)
    generate_minimal_cross_account=$(handle_null_param "$generate_minimal_cross_account" "no" "no")

    create_network=$(cat ${param_file} | jq -r .optional.create_network)
    create_network=$(handle_null_param "$create_network" "no" "no")

    # Calculated parameters
    base_dir=$(cd $(dirname $0); pwd -L)
    sleep_duration=3
    prefix_length=$(echo ${prefix} | awk '{print length}')

    # Export defaults
    export CDP_PROFILE=$cdp_profile
    export END_DATE=$end_date
    export PROJECT=$project

    if [[ ${cloud_provider} == "az" ]]
    then
        export AZURE_STORAGE_CONTRIBUTOR_GUID="ba92f5b4-2d11-453d-a403-e96b0029c9fe"
        export AZURE_STORAGE_OWNER_GUID="b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
        export AZURE_VM_CONTRIBUTOR_GUID="9980e02c-c2be-4d73-94e8-173b1dc7cf3c"
        export AZURE_MANAGED_IDENTITY_OPERATOR_GUID="f1a07417-d97a-45cb-824c-7a7467783830"
    fi

    if [[ ${cloud_provider} == "aws" ]]
    then
        export AWS_PROFILE=${cloud_profile}
        export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
    fi
    
    owner=$(cdp iam get-user | jq -r .user.email)
    workload_user=$(cdp iam get-user | jq -r .user.workloadUsername)

    CHECK_MARK="✅"
}

run_pre_checks() 
{
    result=$(cdp --version 2>&1 > /dev/null)
    handle_exception $? $prefix "cdp cli verification" "$result"
 
    if [ $(command -v jq | wc -l) -eq 0 ]
    then
        handle_exception 1 $prefix "jq verification" "jq is not installed"
    fi

    if [[ ${cloud_provider} == "aws" ]]
    then
        result=$(aws iam get-user 2>&1 > /dev/null)
        handle_exception $? $prefix "aws cli verification" "$result"
    fi

    if [[ ${cloud_provider} == "az" ]]
    then
        result=$(az --version 2>&1 > /dev/null)
        handle_exception $? $prefix "az cli verification" "$result"
    fi
}

print_params()
{
    echo "REQUIRED:"
    echo "param_file: $param_file"
    echo "base_dir: $base_dir"
    echo "prefix: $prefix"
    echo "credential: $credential"
    echo "region: $region"
    echo "key: $key"
    echo "workload_pwd: $workload_pwd"
    echo "datahub_list: $datahub_list"
    echo "ml_workspace_list: $ml_workspace_list"
    echo ""
    echo "OPTIONAL:"
    echo "cloud_provider: $cloud_provider"
    echo "cloud_profile: $cloud_profile"
    echo "cdp_profile: $cdp_profile"
    echo "end_date: $end_date"
    echo "project: $project"
    echo ""
    echo "CALCULATED / EXPORTED:"
    echo "sleep_duration: $sleep_duration"
    echo "prefix_length: $prefix_length"
    echo "CDP_PROFILE: $CDP_PROFILE"
    echo "END_DATE: $END_DATE"
    echo "PROJECT: $PROJECT"
    echo "AZURE_STORAGE_CONTRIBUTOR_GUID: $AZURE_STORAGE_CONTRIBUTOR_GUID"
    echo "AZURE_STORAGE_OWNER_GUID: $AZURE_STORAGE_OWNER_GUID"
    echo "AZURE_VM_CONTRIBUTOR_GUID: $AZURE_VM_CONTRIBUTOR_GUID"
    echo "AZURE_MANAGED_IDENTITY_OPERATOR_GUID: $AZURE_MANAGED_IDENTITY_OPERATOR_GUID"
    echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
    echo "AWS_PROFILE: $AWS_PROFILE"
    echo "owner: $owner"
    echo "workload_user: $workload_user"

}
#!/bin/bash 
 if ! [ -z ${DEV_CLI+x} ]
then
    shopt -s expand_aliases
    alias cdp="cdp 2>/dev/null"
fi 
source $(cd $(dirname $0); pwd -L)/../common.sh

function display_usage() {
  echo "Usage: $(basename "$0") <parameter_file> [--help or -h]"
}

if [[ ( $1 == "--help") ||  $1 == "-h" || $# != 1 ]]; then
  display_usage
  exit 0
fi

param_file=$1
parse_parameters ${param_file}

# Getting assets
rm -rf /tmp/opdb-demo 2>&1 > /dev/null
mkdir /tmp/opdb-demo
cd /tmp/opdb-demo
git clone https://github.com/shlomitub28/flask-phoenix.git --quiet
echo "${CHECK_MARK}  $prefix: repository cloned"

# Preparing assets
cd /tmp/opdb-demo/flask-phoenix/
pip3 install -r requirements.txt 2>&1 > /dev/null
echo "${CHECK_MARK}  $prefix: libraries installed"


env_crn=$(cdp environments describe-environment --environment-name ${prefix}-cdp-env  2>/dev/null | jq -r .environment.crn)
all_dbs=$(cdp opdb list-databases | jq -r '.databases[] | select(.environmentCrn=="'${env_crn}'") | .databaseName' 2>/dev/null)
first_db=$(echo $all_dbs | head -1)
hue_endpoint=$(cdp opdb describe-database --environment-name ${prefix}-cdp-env --database-name ${first_db} | jq -r .databaseDetails.hueEndpoint)
phoenix_endpoint=$(echo $hue_endpoint | sed "s|/hue/|/cdp-proxy-api/avatica|g")
cd /tmp/opdb-demo/flask-phoenix/app/
sed "s/<cod workload username>/${workload_user}/g;s/<cod workload pw>/${workload_pwd}/g;s/<cod thin jdbc url>/${phoenix_endpoint}/g" schema.py > tmp
mv tmp schema.py
python3 setup.py
echo "${CHECK_MARK}  $prefix: setup complete!"
echo "${CHECK_MARK}  $prefix: Go to /tmp/opdb-demo/flask-phoenix/app/; run FLASK_APP=app.py python3 -m flask run --port=8888 --host=127.0.0.1  --reload --with-threads --debugger"



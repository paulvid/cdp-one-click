# CDP setup in one click

This repository contains a set of scripts that will create CDP minimal assets for demo in one wrapper script, including:
* Cloud pre-requisites (bucket, policies, roles, network)
* Cloud CDP Environmment
* CDP Data Lake
* Any CDP Data Hub cluster definition


# Pre-Requisites

## AWS
* AWS CLI ([Instructions](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html))
    * You must run `aws configure` after install, and ensure your region is set
* AWS ssh key ([Instructions](https://docs.aws.amazon.com/opsworks/latest/userguide/security-settingsshkey.html)); Alternatively, you can use the `field` or `_field` keys setup in our AWS SE accounts

## Azure
* Azure CLI ([Instructions](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-macos?view=azure-cli-latest))
    * Use `az login` after install to login
* ssh Key: you will need to paste the public key into your parameters file

_Note: Azure CML is not supported yet, so don't add it in your parameters file :)_

## CDP
* CDP CLI ([Instructions](https://docs.cloudera.com/management-console/cloud/cli/topics/mc-cli-client-setup.html))

* CDP Credential ([Instructions](https://docs.cloudera.com/management-console/cloud/credentials-aws/topics/mc-create-credentialrole.html))
    * You must set your `Workload Password` in your `CDP Profile` ([Shortcut](https://console.cdp.cloudera.com/iam/index.html#/my-account))
    * You must generate a `CLI Access Key` in your `CDP Profile`, and configure it to your local `CDP CLI` ([Shortcut](https://console.cdp.cloudera.com/iam/index.html#/my-account))


# Parameters file format

## Detailed format

<pre>
{
    <b><em>Required parameters: </em></b>
    "required": {
                
        <b><em>Prefix used for cdp assets creation: </em></b> 
        "prefix":         "pvi",
        
        <b><em>Name of credential to use: </em></b>
        "credential":     "pvidal-aws-se-credential",

        <b><em>Region to use (should also be the default region of your cloud provider cli profile): </em></b>
        "region":         "us-east-1",
        
        <b><em>ssh key to use for cdp instances setup: </em></b>
        "key":            "field",

        <b><em>Workload password to use in CDP: </em></b>
        "workload_pwd":   "cdpw0rksh0p",

        <b><em>Array of datahub to setup (can be empty): </em></b>
        "datahub_list": [

            <b><em>Element 1: </em></b>
            {
                <b><em>Definition from cdp-cluster-definitions folder: </em></b>
                "definition": "data-mart.json",

                <b><em>Custom script from cdp-dh-custom-scripts folder: </em></b>
                "custom_script": ""
            },

            <b><em>Element 2: </em></b>
            {
                <b><em>Definition from cdp-cluster-definitions folder: </em></b>
                "definition": "cdp-mod-workshop.json",

                <b><em>Custom script from cdp-dh-custom-scripts folder: </em></b>
                "custom_script": "cdp_mod_wkp.sh"
            },
        ],

        <b><em>Array of ml workspaces to setup (can be empty): </em></b>
        "ml_workspace_list": [

            <b><em>Element 1: </em></b>
            {
                <b><em>Definition from cml-workspace-definitions folder: </em></b>
                "definition": "small_workspace.json",

                <b><em>Flag to enable monitoring, governance and model metrics (possible values yes or no): </em></b>
                "enable_workspace": "no"
            }

        ]
    },

    <b><em>Optional (defaulted) parameters (can be empty): </em></b>
    "optional": {

        <b><em>Cloud provider (default: aws, possible values: aws, az): </em></b>
        "cloud_provider": "aws", 

        <b><em>Cloud provider cli profile (only supported in AWS) (default: default): </em></b>
        "cloud_profile":    "default",

        <b><em>CDP cli profile (default: default): </em></b>
        "cdp_profile":    "default",

        <b><em>Flag to create cdp credential or not (default: no, possible values: yes, no) </em></b>
        "generate_credential": "no",

        <b><em>NOT SUPPORTED YET Flag to generate minimal cross account role policy or not (default: no, possible values: yes, no) </em></b>
        "generate_minimal_cross_account": "no",

        <b><em>Flag to create network in cloud provider or not (only supported in AWS) (default: no, possible values: yes, no) </em></b>
        "create_network": "no",

        <b><em>CIDR to open in your security group of your network (port 443, 22 and 9443 will be open to this) </em></b>
        "sg_cidr": "0.0.0.0/0",

         <b><em>Use CCM for env deployment (default: no, possible values: yes, no) </em></b>
        "use_ccm": "no",

        <b><em>Tags to setup: </em></b>
        "tags": {

            <b><em>End date tag (default: today's date +3 days): </em></b>
            "end_date":       "04102020",
            <b><em>End date tag (default: [prefix]_one_click_project): </em></b>
            "project":        "pvi_test"
        },

    }

}
</pre>

## Parameters file samples

See `parameters_sample` folder


# Doing all the things (full wrapper)

## Creation

Run the source target wrapper script:

```
cdp_create_all_the_things.sh <your_param_file> 
```

## Deletion

Run the deletion script:
```
cdp_delete_all_the_things.sh <your_param_file>
```

# Doing some of the things (individual wrappers)

## AWS things

### Pre-requisites
```
cdp_aws_pre_reqs.sh.sh <your_param_file>
```

### SDX
```
cdp_aws_sdx.sh <your_param_file> [<network_file>]
```


## Azure things

### Pre-requisites
```
cdp_az_pre_reqs.sh.sh <your_param_file>
```

### SDX
```
cdp_az_sdx.sh <your_param_file>
```

## CDP things

### Datahub
```
cdp_create_datahub_things.sh <your_param_file>
```


### ML 
```
cdp_create_ml_things.sh <your_param_file> 
```

### Starting / Stopping (work in progress)
```
cdp_stop_all_the_things.sh <your_param_file> 
```

```
cdp_start_all_the_things.sh <your_param_file> 
```

# Development Optional flags

Note: some flags require dev cli, not for public consumption, use at your own risk

`--no-cost-check`: removes cost check
`--no-db-ha`: does not create DB HA backend
`--no-sync-users`: does launch sync users to free-ipa

# Future Improvements

* Add support for Azure ML
* Add support for minimal set of policies for AWS
* Add dynamic definition updates 
* Create a nifi flow wrapper?


# Author & Contributors

**Paul Vidal** - [LinkedIn](https://www.linkedin.com/in/paulvid/)

**Dan Chaffelson** - [LinkedIn](https://www.linkedin.com/in/danielchaffey/)

**Chris Perro** - [LinkedIn](https://www.linkedin.com/in/christopher-perro/)

**André Araújo** - [LinkedIn](https://www.linkedin.com/in/asdaraujo/)

**Nathan Anthony** - [LinkedIn](https://www.linkedin.com/in/nateanth/)

**Steffen Maerkl** - [LinkedIn](https://www.linkedin.com/in/steffen-maerkl-0b862650/)

**Mike Riggs** - [LinkedIn](https://www.linkedin.com/in/mriggs/)

**Ryan Cicak** - [LinkedIn](https://www.linkedin.com/in/ryan-cicak-66221a47/)

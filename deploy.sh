#!/bin/bash
# Shell script to deploy OpenShift 3.6 on Microsoft Azure
# Magnus Glantz, sudo@redhat.com, 2017

# Assign first argument to be Azure Resource Group
GROUP=$1
PRIVATE_SSH_KEY_FILE=$2

# Test group variable
if test -z $GROUP; then
        echo "Usage: $0 <unique name for Azure resource group> [ <private ssh key> ]"
        exit 1
fi

<<<<<<< HEAD
if [ -z "$PRIVATE_SSH_KEY_FILE" -o ! -f "$PRIVATE_SSH_KEY_FILE" ]; then
  if [ -f ~/.ssh/id_rsa -a -f ~/.ssh/id_rsa.pub ]; then
    PRIVATE_SSH_KEY_FILE=~/.ssh/id_rsa
    PUBLIC_SSH_KEY="$( cat ~/.ssh/id_rsa.pub )"
    echo -e "Using \e[1;33m'~/.ssh/id_rsa'\e[0m and \e[1;33m'~/.ssh/id_rsa.pub'\e[0m for SSH key files."
		read -p "Do you want to use this keypair to access your azure VMs? (y/n)" ANSWER
		case $ANSWER in
			n|N)
				echo -e "Please specify the SSH key to use, when running \e[1;33m'deploy.sh'\e[0m."
				exit 1
			;;
		esac
  else
i    echo -e "No SSH key found in \e[1;33m'~/.ssh/id_rsa.pub'\e[0m. Generating key."
     echo -e "Using \e[1;33m'./id_rsa'\e[0m and \e[1;33m'./id_rsa.pub'\e[0m for SSH key files."
i    ssh-keygen -t rsa -N '' -f ./id_rsa
i    PUBLIC_SSH_KEY="$(cat ./id_rsa.pub)"
  fi
else
  echo -e "Using \e[1;33m'${PRIVATE_SSH_KEY_FILE}'\e[0m and \e[1;33m'${PRIVATE_SSH_KEY_FILE}.pub'\e[0m for SSH key files."
  PUBLIC_SSH_KEY="$(cat ${PRIVATE_SSH_KEY_FILE}.pub )"
fi

=======
>>>>>>> 449035ae8595f3bf238e688e5f35741f764155ce
OK=0
if [ -f ./deploy.cfg ]; then
	. ./deploy.cfg
  if echo ${LOCATION} | egrep '^usgov' >/dev/null; then
    MS_FQDN=cloudapp.usgovcloudapi.net
  else
    MS_FQDN=cloudapp.azure.com
  fi
	if test -z $RHN_ACCOUNT; then
		OK=1
	elif test -z $OCP_USER; then
		OK=1
	elif test -z $OCP_PASSWORD; then
		OK=1
	elif test -z $SUBSCRIPTION_POOL; then
		OK=1
	elif test -z $LOCATION; then
		OK=1
  elif test -z $RHN_PASSWORD; then
    echo "Please type your red hat password, finish with [enter]:"
    read -s
    RHN_PASSWORD=$REPLY
	fi
  if test -z $MASTER_DNS; then
    MASTER_DNS="${GROUP}master"
    if dig $MASTER_DNS.${LOCATION}.${MS_FQDN}|grep -v ";"|grep "IN A"|awk '{ print $5 }'|grep [0-9] >/dev/null; then
      echo "Error: $MASTER_DNS.${LOCATION}.${MS_FQDN} already exists. Select other name."
      exit 1
    fi
	fi
  if test -z $INFRA_DNS; then
    INFRA_DNS="${GROUP}apps"
    if dig $INFRA_DNS.${LOCATION}.${MS_FQDN}|grep -v ";"|grep "IN A"|awk '{ print $5 }'|grep [0-9] >/dev/null; then
      echo "Error: $INFRA_DNS.${LOCATION}.${MS_FQDN} already exists. Select other name."
      exit 1
    fi
	fi
	if test -z $KEYVAULTRESOURCEGROUP; then
		KEYVAULTRESOURCEGROUP=${GROUP}
	fi
	if test -z $KEYVAULTNAME; then
		KEYVAULTNAME=${GROUP}KeyVaultName
	fi
	if test -z $KEYVAULTSECRETNAME; then
		KEYVAULTSECRETNAME=${GROUP}SecretName
	fi
else
	OK=1
fi

if [ "$OK" -eq 1 ]; then
	echo "Missing variable values: Edit the deploy.cfg file"
	exit 1
fi

echo "Generating deployment configuration."
cat > azuredeploy.parameters.json << EOF
{
        "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
                "_artifactsLocation": {
                        "value": "https://raw.githubusercontent.com/mglantz/ocp39-azure-simple/master/"
                },
                "masterVmSize": {
                        "value": "Standard_DS4_v2"
                },
                "nodeVmSize": {
                        "value": "Standard_DS3_v2"
                },
                "openshiftClusterPrefix": {
                        "value": "ocp"
                },
		"openshiftMasterPublicIpDnsLabel": {
			"value": "$MASTER_DNS"
		},
		"infraLbPublicIpDnsLabel": {
			"value": "$INFRA_DNS"
		},
		"masterInstanceCount": {
			"value": $MASTERCOUNT
		},
		"nodeInstanceCount": {
			"value": $NODECOUNT
		},
		"dataDiskSize": {
			"value": $DISKSIZE
		},
		"adminUsername": {
			"value": "$OCP_USER"
		},
		"openshiftPassword": {
			"value": "$OCP_PASSWORD"
		},
		"cloudAccessUsername": {
			"value": "$RHN_ACCOUNT"
		},
		"cloudAccessPassword": {
			"value": "$RHN_PASSWORD"
		},
		"cloudAccessPoolId": {
			"value": "$SUBSCRIPTION_POOL"
		},
		"sshPublicKey": {
			"value": "$PUBLIC_SSH_KEY"
		},
		"keyVaultResourceGroup": {
			"value": "$KEYVAULTRESOURCEGROUP"
		},
		"keyVaultName": {
			"value": "$KEYVAULTNAME"
		},
		"keyVaultSecret": {
			"value": "$KEYVAULTSECRETNAME"
		},
		"defaultSubDomainType": {
			"value": "$DOMAINTYPE"
		},
		"defaultSubDomain": {
			"value": "$CUSTOMDOMAIN"
		}
	}
}
EOF

echo "Deploying OpenShift Container Platform."

# Create Azure Resource Group
azure group create $GROUP $LOCATION

# Create Keyvault in which we put our SSH private key
azure keyvault create -u ${GROUP}KeyVaultName -g $GROUP -l $LOCATION

# Put SSH private key in key vault
azure keyvault secret set -u ${GROUP}KeyVaultName -s ${GROUP}SecretName --file $PRIVATE_SSH_KEY_FILE

# Enable key vault to be used for deployment
azure keyvault set-policy -u ${GROUP}KeyVaultName --enabled-for-template-deployment true

# Launch deployment of cluster, after this it’s just waiting for it to complete. 
# azuredeploy.parameters.json needs to be populated with valid values first, before you run this.
azure group deployment create --name ${GROUP} --template-file azuredeploy.json -e azuredeploy.parameters.json --resource-group $GROUP --nowait

echo
echo "Deployment initiated. Allow 40-50 minutes for a deployment to succeed."
echo "The cluster will be reachable at:"
echo -e "\e[1;33mhttps://$MASTER_DNS.${LOCATION}.${MS_FQDN}:8443\e[0m"
echo
echo "Waiting for Bastion host IP to get allocated."

while true; do
	if azure network public-ip show $GROUP bastionpublicip|grep "Ip Address"|cut -d':' -f3|grep [0-9] >/dev/null; then
		break
	else
		sleep 5
	fi
done

<<<<<<< HEAD
echo "You can SSH into the cluster by accessing it's bastion host:"
bastionip=`azure network public-ip show $GROUP bastionpublicip|grep 'Ip Address'|cut -d':' -f3|grep [0-9]|sed 's/ //g'`
echo -e "\e[1;33mssh -i $PRIVATE_SSH_KEY_FILE ${OCP_USER}@${bastionip}\e[0m\n"
=======
echo "You can SSH into the cluster by accessing its bastion host:"
bastionip=`azure network public-ip show $GROUP bastionpublicip|grep 'Ip Address'|cut -d':' -f3|grep [0-9]|sed 's/ //g'`
echo -e "\e[1;33mssh ${bastionip}\e[0m\n"
>>>>>>> 449035ae8595f3bf238e688e5f35741f764155ce
echo "Once your SSH key has been distributed to all nodes, you can then jump passwordless from the bastion host to all nodes."
echo "To SSH directly to the master, use port 2200:"
echo -e "\e[1;33mssh $MASTER_DNS.${LOCATION}.${MS_FQDN} -p 2200\e[0m\n"
echo "For troubleshooting, check out /var/lib/waagent/custom-script/download/[0-1]/stdout or stderr on the nodes"





#!/bin/bash
# Integrate Fortify ScanCentral Static AppSec Testing (SAST) into your AWS Codestar pipeline

# *** Configuration ***

# The following environment variables must be defined
export FCLI_DEFAULT_SC_SAST_CLIENT_AUTH_TOKEN=$FCLI_DEFAULT_SC_SAST_CLIENT_AUTH_TOKEN
# export FCLI_DEFAULT_SSC_USER=$FCLI_DEFAULT_SSC_USER
# export FCLI_DEFAULT_SSC_PASSWORD=$FCLI_DEFAULT_SSC_PASSWORD
export FCLI_DEFAULT_SSC_CI_TOKEN=$FCLI_DEFAULT_SSC_CI_TOKEN
export FCLI_DEFAULT_SSC_URL=$FCLI_DEFAULT_SSC_URL
ssc_app_version_id=$SSC_APP_VERSION_ID

# Local variables (modify as needed)
scancentral_client_version='23.1.0'
fcli_version='v2.0.0'
#fcli_sha='6af0327561890bf46e97fab309eb69cd9b877f976f687740364a08d83fc7e020'

# Local variables (DO NOT MODIFY)
fortify_tools_dir="/root/.fortify/tools"	
scancentral_home=$fortify_tools_dir/ScanCentral	
fcli_home=$fortify_tools_dir/fcli
fcli_install='fcli-linux.tgz'

# *** Execution ***

# Download Fortify CLI 
wget "https://github.com/fortify-ps/fcli/releases/download/$fcli_version/fcli-linux.tgz"
fcli_sha=$(sha256sum fcli-linux.tgz)

e=$?        # return code last command
if [ "${e}" -ne "0" ]; then
	echo "ERROR: Failed to download Fortify CLI - exit code ${e}"
	exit 100
fi

# Verify integrity
sha256sum -c <(echo "$fcli_sha")
e=$?        # return code last command
if [ "${e}" -ne "0" ]; then
	echo "ERROR: Fortify CLI hash does not match - exit code ${e}"
	exit 100
fi

mkdir -p $fcli_home/bin
tar -xvzf "$fcli_install" -C $fcli_home/bin
export PATH=$fcli_home/bin:$scancentral_home/bin:${PATH}

fcli tool sc-client install -y -v $scancentral_client_version -d $scancentral_home

echo Setting connection with Fortify Platform
# USE --INSECURE WHEN YOUR SSL CERTIFICATES ARE SELF GENERATED/UNTRUSTED
fcli ssc session login --url $FCLI_DEFAULT_SSC_URL -t $FCLI_DEFAULT_SSC_CI_TOKEN
fcli ssc session list

fcli sc-sast session login --ssc-url $FCLI_DEFAULT_SSC_URL -t $FCLI_DEFAULT_SSC_CI_TOKEN -c $FCLI_DEFAULT_SC_SAST_CLIENT_AUTH_TOKEN
fcli sc-sast session list

scancentral -help
scancentral package -bt mvn -o package.zip

#fcli sc-sast scan start --appversion=$ssc_app_version_id --upload --sensor-version=$scancentral_client_version --package-file=package.zip --store='?'
fcli sc-sast scan start --publish-to=$ssc_app_version_id --sensor-version=$scancentral_client_version --ssc-ci-token $FCLI_DEFAULT_SSC_CI_TOKEN --package-file=package.zip --store='?'

# fcli sc-sast scan wait-for '?' --interval=30s
# #fcli ssc appversion-vuln count --appversion=$SSC_APP_VERSION_ID

echo Terminating connection with Fortify Platform
fcli sc-sast session logout --no-revoke-token
fcli ssc session logout --no-revoke-token
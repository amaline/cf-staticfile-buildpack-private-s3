#!/bin/bash
#
#   PROGRAM: deploy.sh
#   PURPOSE: Creates a github release and uploads nginx binary in gzip tar format to github.  This version modified to 
#            build the artifact name using the VERSION file as input.
#
#   EXIT CODES:
#               128 - repository tag already exists.  update circle.yml with new version number.
#               100 - no release ID was returned from github when release creation was attempted.
#               200 - artifact upload failed
#
##################################################################################################################################

echo "GITHUB_PROJECT    = $GITHUB_PROJECT"
echo "GITHUB_RELEASE    = $GITHUB_RELEASE"
echo "PROJECT_REPOSITORY= $PROJECT_REPOSITORY"
echo "CIRCLE_ARTIFACTS  = $CIRCLE_ARTIFACTS"
echo "REPOSITORY        = $REPOSITORY"

export VERSION=`cat $REPOSITORY/VERSION`
echo "VERSION           = $VERSION"

export ARTIFACT_NAME=`echo $ARTIFACT_NAME|sed -e "s/VERSION/${VERSION}/"`
echo "ARTIFACT_NAME     = $ARTIFACT_NAME"

export RELEASE_NAME="Release ${GITHUB_RELEASE} for custom staticfile buildpack build"
export RELEASE_DESC="Cloud Foundry staticfile buildpack with a custom version of nginx that includes the aws authentication module for accessing private S3 buckets."

echo "Exiting on any error"
set -e

# fails with exit code 128
echo "Create tag ${GITHUB_RELEASE}"
git tag ${GITHUB_RELEASE}

echo "Push tag to github repository ${GITHUB_PROJECT}"
git push https://${GITHUB_TOKEN}@${PROJECT_REPOSITORY} --tags

#echo "Sleep 15 seconds for api to recognize tag because eventual consistancy I think... [race condition]"
#sleep 15

echo "Creating release..."

echo "  build create release json"
echo -e "{\n\"tag_name\": \"${GITHUB_RELEASE}\",\n\"target_commitish\": \"master\",\n\"name\": \"${RELEASE_NAME}\",\n\"body\": \"${RELEASE_DESC}\",\n\"draft\": false,\n\"prerelease\": false\n}" > json.json

echo "  issuing command to github to create release"
curl -# -XPOST -H 'Content-Type:application/json' -H 'Accept:application/json' --data-binary @json.json https://api.github.com/repos/${GITHUB_PROJECT}/releases?access_token=${GITHUB_TOKEN} -o response.json

echo "  pulling release id from response"
RELEASE_ID=`cat response.json | jq '.id'`
if [ "$RELEASE_ID" == "null" ]
then
   echo -n "ERROR: No Release ID returned.  Returned message="
   cat response.json |jq '.errors[0].message'
   exit 100
fi

echo
echo "Upload ${CIRCLE_ARTIFACTS}/${ARTIFACT_NAME} to github release ${GITHUB_RELEASE} ID=${RELEASE_ID}"
echo

curl -# -XPOST -H "Authorization: bearer ${GITHUB_TOKEN}" -H "Content-Type: application/octet-stream" --data-binary @${CIRCLE_ARTIFACTS}/${ARTIFACT_NAME} https://uploads.github.com/repos/${GITHUB_PROJECT}/releases/${RELEASE_ID}/assets?name=${ARTIFACT_NAME} -o assetuploadresponse.json

UPLOADED=`cat assetuploadresponse.json | jq '.state'`
if [ $UPLOADED == '"uploaded"' ];then
  echo "asset uploaded"
else
  echo "upload failed"
  cat assetuploadresponse.json
  exit 200
fi

echo
echo "Removing create release json command file and response file"
rm json.json response.json
echo "Job Complete"

exit 0
#!/bin/bash
#
#   PROGRAM: deploy.sh
#   PURPOSE: Creates a github release and uploads nginx binary in gzip tar format to github
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
echo "ARTIFACT_NAME     = $ARTIFACT_NAME"

echo "Exiting on any error"
set -e

# fails with exit code 128
echo "Create tag ${GITHUB_RELEASE}"
git tag ${GITHUB_RELEASE}

echo "Push tag to github repository ${GITHUB_PROJECT}"
git push https://${GITHUB_TOKEN}@${PROJECT_REPOSITORY} --tags

echo "Sleep 15 seconds for api to recognize tag because eventual consistancy I think... [race condition]"
sleep 15

echo "Creating release..."

echo "  build create release json"
echo -e "{\n\"tag_name\": \"${GITHUB_RELEASE}\",\n\"target_commitish\": \"master\",\n\"name\": \"release ${GITHUB_RELEASE} for custom nginx build\",\n\"body\": \"release ${GITHUB_RELEASE} for custom nginx build for cloud foundry s3 proxy\",\n\"draft\": false,\n\"prerelease\": false\n}" > json.json

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
#!/usr/bin/env bash
set -eo pipefail

for variant in "fatjar-openjdk8" "fatjar-openjdk11" "fatjar-openjdk17" "war-openjdk8" "war-openjdk11" "war-tomcat8-openjdk8" "war-tomcat8-openjdk11"; do
  docker run -u root -v $(pwd)/variants/${variant}:/repository "${ECR_REPO}/baseimage-${variant}:${IMAGE_LABEL}" /bin/sh -c "apk info -v | sort > /repository/package-versions && chmod 755 /repository/package-versions"
done

git config --global user.name "Github Actions"
git config --global user.email "github-actions@opintopolku.fi"
git diff $(pwd)/package-versions
git commit -a -m 'Update alpine packages'
git push origin "HEAD:${GITHUB_REF_NAME}"
curl -H "Content-Type: application/json" -X POST \
   --data "{\"flow_token\": \"${PILVIKEHITYS_FLOW_TOKEN}\", \"event\": \"message\", \"content\": \"Baseimage: alpine packages updated by Github Actions\"}" \
   https://api.flowdock.com/messages

#!/usr/bin/env bash
set -eo pipefail

for variant in "fatjar-openjdk8" "fatjar-openjdk11" "fatjar-openjdk17" "war-openjdk8" "war-openjdk11" "war-tomcat8-openjdk8" "war-tomcat8-openjdk11" "fatjar-openjdk8-corretto" "fatjar-openjdk11-corretto" "fatjar-openjdk17-corretto" "war-openjdk8-corretto" "war-openjdk11-corretto" "war-tomcat8-openjdk8-corretto" "war-tomcat8-openjdk11-corretto"; do
  docker run -u root -v $(pwd)/variants/${variant}:/repository "${ECR_REPO}/baseimage-${variant}:${IMAGE_LABEL}" /bin/sh -c "apk info -v | sort > /repository/package-versions && chmod 755 /repository/package-versions"
  git diff $(pwd)/variants/${variant}/package-versions
done

git config --global user.name "Github Actions"
git config --global user.email "github-actions@opintopolku.fi"
git commit -a -m 'Update alpine packages' || true
git push origin "HEAD:${GITHUB_REF_NAME}"
curl -H "Content-Type: application/json" -X POST \
   --data "{\"text\": \"Baseimage: alpine packages updated by Github Actions\"}" \
   ${PILVIKEHITYS_SLACK_TOKEN}

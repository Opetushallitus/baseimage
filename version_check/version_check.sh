#!/usr/bin/env bash
set -eo pipefail

echo "${ECR_REPO}/${ARTIFACT_NAME}:ci-${TRAVIS_BUILD_NUMBER}"

if [ "${TRAVIS_EVENT_TYPE}" = "cron" ]
then
  for variant in "fatjar-openjdk8" "fatjar-openjdk11" "war-openjdk8" "war-openjdk11"; do
    docker run -v ${TRAVIS_BUILD_DIR}/variants/${variant}:/repository "${ECR_REPO}/baseimage-${variant}:ci-${TRAVIS_BUILD_NUMBER}" /bin/sh -c "apk info -v | sort > /repository/package-versions && chmod 755 /repository/package-versions"
  done

  git diff ${TRAVIS_BUILD_DIR}/variants/fatjar-openjdk8/package-versions
  git checkout ${TRAVIS_BRANCH}
  sudo apt-get update
  sudo apt-get install -y python3 python3-pip python3-setuptools
  sudo pip3 install -r $(dirname $0)/requirements.txt
  python3 $(dirname $0)/version_check.py
else
  echo "Version check skipped (non scheduled build)"
fi
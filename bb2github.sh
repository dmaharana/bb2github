#!/bin/bash

#save git user credentials
# the git credentials have to provided once
git config --global credential.helper store

#define source URLs file
SRC_URL_FILE="input.txt"
#define target base URL
TRG_BASE_URL="https://github.com"
# set the URL for an organization
#  POST /orgs/:org/repos
# Refer: https://developer.github.com/v3/repos/#create
GITHUB_REPO_CREATE_API="https://api.github.com/user/repos"
WAIT_SECONDS=5
PRIVATE_REPO="false"
RETRY_COUNT=3

#add the GITHUB user and password as environment variables
# export GITHUB_USER=user_id
# export GITHUB_PASS=psswd

#define local base directory
BASE_DIR="/c/project"

if [ ! -d "$BASE_DIR" ]; then
   mkdir $BASE_DIR
fi

# for each source URL
for src_repo_url in `cat $SRC_URL_FILE`;do
        # change directory to base directory
        echo "Change directory to base directory ${BASE_DIR}"
	cd "${BASE_DIR}"

        # get the repo name
        repo_name=$(basename -s .git "${src_repo_url}")
        echo "Repo name is '${repo_name}'"

        echo "Checking if local repo exists '${repo_name}'"
        if [ ! -d "$repo_name" ]; then
           # clone locally
           echo "Clone repository ${src_repo_url}"
	   git clone ${src_repo_url}
           # cd cloned repo
           echo "Change directory to ${repo_name}"
           cd ${repo_name}
        else
           echo "Change directory to ${repo_name}"
           cd ${repo_name}
           echo "Updating the local repo"
           git pull --all
        fi

        #checkout all branches
        for remote in `git branch -r | grep -v master `; do git checkout --track $remote ; done

        # create github repo
        target_repo_url="${TRG_BASE_URL}/${GITHUB_USER}/${repo_name}.git"
        echo "Create github repo ${target_repo_url}"
        curl -X POST -k -u ${GITHUB_USER}:${GITHUB_PASS} ${GITHUB_REPO_CREATE_API} -d "{\"name\":\"${repo_name}\"}"
        # curl -X POST -k -u ${GITHUB_USER}:${GITHUB_PASS} ${GITHUB_REPO_CREATE_API} -d "{\"name\":\"${repo_name}\",\"private\":\"${PRIVATE_REPO}\"}"
        
        # wait for GITHUB to replicate the repos on its cluster
        echo "wait for a few seconds"
        sleep ${WAIT_SECONDS}

        # git push git_repo_url --all
        echo "Push all branches to target repository ${target_repo_url}"
        local_retry_count=$RETRY_COUNT
        while [ $local_retry_count -gt 0 ];do
                git push ${target_repo_url} --all
                push_ret_code=$?
                echo "GIT push return code: ${push_ret_code}"
                if [ $push_ret_code -ne 0 ]; then
                    local_retry_count=$((local_retry_count-1))
                else
                    local_retry_count=0
                fi
        done

        # git push --tags git_repo_url --all
        local_retry_count=$RETRY_COUNT
        echo "Push all tags to target repository ${target_repo_url}"
        while [ $local_retry_count -gt 0 ];do
                git push ${target_repo_url} --tags
                push_ret_code=$?
                if [ $local_retry_count -ne 0 ]; then
                    local_retry_count=$((local_retry_count-1))
                else
                    local_retry_count=0
                fi
        done
done

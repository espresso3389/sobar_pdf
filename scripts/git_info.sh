#!/bin/bash -e

pushd $1
name=$2

data=($(git for-each-ref --format='%(refname) %(objectname)' --sort='-committerdate'))
branch=${data[0]##*/}
commit=${data[1]:0:6}
rev=$(git log --oneline | wc -l | awk '{print $1}')

echo "Rev=${rev}, Commit=${commit}, Branch=${branch}"

export ${name}COMMIT=$commit
export ${name}BRANCH=$branch
export ${name}REV=$rev

# Update GitHub Actions environment variables
if [ "$GITHUB_ENV" != "" ]; then
    echo "${name}COMMIT=$commit" >> $GITHUB_ENV
    echo "${name}BRANCH=$branch" >> $GITHUB_ENV
    echo "${name}REV=$rev" >> $GITHUB_ENV
fi

popd

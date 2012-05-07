WORKSPACE=$1
REPO_BRANCH=$2

vendor/cm/get-prebuilts

cd $WORKSPACE/$REPO_BRANCH

#device patch
cd vendor/cm
git apply $WORKSPACE/$REPO_BRANCH/patch/vendor-cm

#camera patch
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-camera

#memory patch
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-memory
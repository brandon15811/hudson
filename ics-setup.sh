WORKSPACE=$1
REPO_BRANCH=$2

echo "Exec'ing vendor/cm/get-prebuilts"
vendor/cm/get-prebuilts

cd $WORKSPACE/$REPO_BRANCH

#device patch
echo "Patching vendor/cm"
cd vendor/cm
git apply $WORKSPACE/$REPO_BRANCH/patch/vendor-cm

#camera patch
echo "Patching Camera"
cd $WORKSPACE/$REPO_BRANCH
cd frameworks/base
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-camera

#memory patch
echo "Patching memory"
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-memory
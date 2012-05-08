WORKSPACE=$1
REPO_BRANCH=$2

vendor/cm/get-prebuilts

cd $WORKSPACE/$REPO_BRANCH

#device patch
echo "Adding Atrix/Olympus to vendorsetup.sh"
cd vendor/cm
#echo "add_lunch_combo cm_olympus-userdebug" >> vendorsetup.sh

#camera patch
echo "Patching Camera"
cd $WORKSPACE/$REPO_BRANCH
cd frameworks/base
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-camera

#memory patch
echo "Patching memory"
git apply $WORKSPACE/$REPO_BRANCH/patch/frameworks-base-memory
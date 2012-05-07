vendor/cyanogen/get-rommanager
#mkdir -p vendor/cyanogen/proprietary && touch vendor/cyanogen/proprietary/RomManager.apk
sudo mount --bind /home/ubuntu/system/ $WORKSPACE/$REPO_BRANCH/device/motorola/olympus/system
cd $WORKSPACE/$REPO_BRANCH/device/motorola
./local-extract-files.sh

#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    echo $1
    exit 1
  fi
}

if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

REPO_BRANCH=ics

if [ -z "$RECOVERY_IMAGE_URL" ]
then
  echo RECOVERY_IMAGE_URL not specified
  exit 1
fi

if [ -z "$SYNC_PROTO" ]
then
  SYNC_PROTO=http
fi

# colorization fix in Jenkins
export CL_PFX="\"\033[34m\""
export CL_INS="\"\033[32m\""
export CL_RST="\"\033[0m\""

cd $WORKSPACE
rm -rf $WORKSPACE/../recovery/archive
mkdir -p $WORKSPACE/../recovery/archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=~/bin:$PATH

export USE_CCACHE=1
export BUILD_WITH_COLORS=0

# make sure ccache is in PATH
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilt/$(uname|awk '{print tolower($0)}')-x86/ccache"

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

. build/envsetup.sh

echo Building unpackbootimg.
lunch generic_armv5-userdebug
# fix up the path to not force darwin stupidly
make -j4 out/host/linux-x86/bin/unpackbootimg

UNPACKBOOTIMG=$(ls out/host/**/bin/unpackbootimg)
if [ -z "$UNPACKBOOTIMG" ]
then
  echo unpackbootimg not found
  exit 1
fi

echo Retrieving recovery image.
rm -rf /tmp/recovery.img /tmp/recovery
curl $RECOVERY_IMAGE_URL > /tmp/recovery.img
check_result "Recovery image download failed."

echo Unpacking recovery image.
mkdir -p /tmp/recovery
unpackbootimg -i /tmp/recovery.img -o /tmp/recovery
check_result "unpacking the boot image failed."
pushd .
cd /tmp/recovery
mkdir ramdisk
cd ramdisk
gunzip -c ../recovery.img-ramdisk.gz | cpio -i
check_result "unpacking the boot image failed (gunzip)."
popd

function getprop {
  cat /tmp/recovery/ramdisk/default.prop | grep $1= | cut -d = -f 2
}

MANUFACTURER=$(getprop ro.product.manufacturer)
MANUFACTURER=$(echo $MANUFACTURER | sed s/-//g)
DEVICE=$(getprop ro.product.device)
DEVICE=$(echo $DEVICE | sed s/-//g)

if [ -z "$MANUFACTURER" ]
then
  echo ro.product.manufacturer not found, using default
  MANUFACTURER=unknown
fi

if [ -z "$DEVICE" ]
then
  echo ro.product.device not found, using default
  echo THIS IS GENERALLY BAD BAD BAD BAD BAD.
  DEVICE=unknown
fi

echo MANUFACTURER: $MANUFACTURER
echo DEVICE: $DEVICE

build/tools/device/mkvendor.sh $MANUFACTURER $DEVICE /tmp/recovery.img

if [ ! -z "$RECOVERY_FSTAB_URL" ]
then
  curl $RECOVERY_FSTAB_URL > device/$MANUFACTURER/$DEVICE/recovery.fstab
  check_result "recovery.fstab download failed"
fi

if [ ! -z "$BOARD_CUSTOM_GRAPHICS_URL" ]
then
  curl $BOARD_CUSTOM_GRAPHICS_URL > device/$MANUFACTURER/$DEVICE/graphics.c
  check_result "graphics.c download failed"
  echo >> device/$MANUFACTURER/$DEVICE/BoardConfig.mk
  echo BOARD_CUSTOM_GRAPHICS:= ../../../device/$MANUFACTURER/$DEVICE/graphics.c >> device/$MANUFACTURER/$DEVICE/BoardConfig.mk
fi

lunch cm_$DEVICE-userdebug
check_result "lunch failed."

if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "20.0" ]
then
  ccache -M 20G
fi

# only clobber product, not host
rm -rf out/target/product
make -j4 recoveryzip recoveryimage
check_result "Build failed."

if [ -f $OUT/utilties/update.zip ]
then
  cp $OUT/utilties/update.zip $WORKSPACE/../recovery/archive/recovery.zip
fi
if [ -f $OUT/recovery.img ]
then
  cp $OUT/recovery.img $WORKSPACE/../recovery/archive
fi

cp /tmp/recovery.img $WORKSPACE/../recovery/archive/inputrecovery.img

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/../recovery/archive

echo Zipping up device tree.
zip -ry $WORKSPACE/../recovery/archive/"android_device_"$MANUFACTURER"_"$DEVICE.zip device/$MANUFACTURER/$DEVICE

echo This recovery was built for:
echo MANUFACTURER: $MANUFACTURER
echo DEVICE: $DEVICE
echo If this is not the recovery you were building, please check the other builds.
echo
echo 'You can download the recovery image and other artifacts by clicking "Status" in the menu on the left.'

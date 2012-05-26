#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    echo $1 step failed !
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

if [ -z "$CLEAN_TYPE" ]
then
  echo CLEAN_TYPE not specified
  exit 1
fi

if [ -z "$REPO_BRANCH" ]
then
  echo REPO_BRANCH not specified
  exit 1
fi

if [ -z "$LUNCH" ]
then
  echo LUNCH not specified
  exit 1
fi

if [ -z "$RELEASE_TYPE" ]
then
  echo RELEASE_TYPE not specified
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

rm -rf $WORKSPACE/archive
mkdir -p $WORKSPACE/archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=/mnt/bin:~/bin:$PATH

export USE_CCACHE=1
export BUILD_WITH_COLORS=0

#REPO=$(which repo)
if [ -z "$REPO" ]
then
  mkdir -p ~/bin
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
fi


# make sure ccache is in PATH
export PATH="$PATH:/opt/local/bin/:$PWD/prebuilt/$(uname|awk '{print tolower($0)}')-x86/ccache"

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

HUDSON_DIR=$WORKSPACE/hudson

echo "About to do $HUDSON_DIR/$REPO_BRANCH-setup.sh"
cd $WORKSPACE/$REPO_BRANCH
if [ -f $HUDSON_DIR/$REPO_BRANCH-setup.sh ]
then
  echo "Doing $HUDSON_DIR/$REPO_BRANCH-setup.sh"
  $HUDSON_DIR/$REPO_BRANCH-setup.sh $WORKSPACE $REPO_BRANCH
fi

cd $WORKSPACE/$REPO_BRANCH
echo "We are ready to build in $WORKSPACE/$REPO_BRANCH"

. build/envsetup.sh
lunch $LUNCH
check_result "lunch failed."

# save manifest used for build (saving revisions as current HEAD)
repo manifest -o $WORKSPACE/archive/manifest.xml -r

rm -f $OUT/cm-*.zip*

UNAME=$(uname)

if [ "$RELEASE_TYPE" = "CM_NIGHTLY" ]
then
  if [ "$REPO_BRANCH" = "gingerbread" ]
  then
    export CYANOGEN_NIGHTLY=true
  else
    export CM_NIGHTLY=true
  fi
elif [ "$RELEASE_TYPE" = "CM_SNAPSHOT" ]
then
  export CM_SNAPSHOT=true
elif [ "$RELEASE_TYPE" = "CM_RELEASE" ]
then
  if [ "$REPO_BRANCH" = "gingerbread" ]
  then
    export CYANOGEN_RELEASE=true
  else
    export CM_RELEASE=true
  fi
fi

if [ ! -z "$CM_EXTRAVERSION" ]
then
  export CM_SNAPSHOT=true
fi

if [ ! -z "$GERRIT_CHANGES" ]
then
  export CM_SNAPSHOT=true
  IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
  if [ -z "$IS_HTTP" ]
  then
    python $WORKSPACE/hudson/repopick.py $GERRIT_CHANGES
    check_result "gerrit picks failed."
  else
    python $WORKSPACE/hudson/repopick.py $(curl $GERRIT_CHANGES)
    check_result "gerrit picks failed."
  fi
fi

if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "20.0" ]
then
  ccache -M 20G
fi

rm -f $OUT/*.zip*
make $CLEAN_TYPE
mka bacon recoveryzip recoveryimage checkapi
check_result "Build failed."

cp $OUT/cm-*.zip* $WORKSPACE/archive
if [ -f $OUT/utilties/update.zip ]
then
  cp $OUT/utilties/update.zip $WORKSPACE/archive/recovery.zip
fi
if [ -f $OUT/recovery.img ]
then
  cp $OUT/recovery.img $WORKSPACE/archive
fi

# archive the build.prop as well
ZIP=$(ls $WORKSPACE/archive/cm-*.zip)
unzip -c $ZIP system/build.prop > $WORKSPACE/archive/build.prop

# CORE: save manifest used for build (saving revisions as current HEAD)
rm -f .repo/local_manifest.xml
repo manifest -o $WORKSPACE/archive/core.xml -r

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/archive

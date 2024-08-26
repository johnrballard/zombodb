#! /bin/bash
#
# Copyright 2018-2023 ZomboDB, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


PGVER=$1
IMAGE=$2
PGRX_VERSION=$3
DEBUG=$4

if [ "x${PGVER}" == "x" ] || [ "x${IMAGE}" == "x" ] ; then
	echo 'usage:  ./package.sh <PGVER> <image>'
	exit 1
fi

if [[ ${IMAGE} == *"amazonlinux"* ]] ||[[ ${IMAGE} == *"fedora"* ]] || [[ ${IMAGE} == *"centos"* ]]; then
	PKG_FORMAT=rpm
elif [[ ${IMAGE} == *"alpine"* ]]; then
	PKG_FORMAT=apk
else
	PKG_FORMAT=deb
fi

set -x

OSNAME=$(echo ${IMAGE} | cut -f3-4 -d-)
VERSION=$(cat zombodb.control | grep default_version | cut -f2 -d\')


PG_CONFIG_DIR=$(dirname $(grep ${PGVER} ~/.pgrx/config.toml | cut -f2 -d= | cut -f2 -d\"))
export PATH=${PG_CONFIG_DIR}:${PATH}

#
# update Rust to the latest version
#
whoami
pwd
ls -la
rustup update || exit 1

#
# ensure cargo-pgrx is the correct version and compiled with this Rust version
#
cargo install cargo-pgrx --version $PGRX_VERSION --locked

#
# build the extension
#
if [ "$DEBUG" == "true" ] ; then
  cargo pgrx package --debug || exit $?
else
  cargo pgrx package --profile artifacts || exit $?
fi

#
# cd into the package directory
#
ARTIFACTDIR=/artifacts

if [ "$DEBUG" == "true" ] ; then
  BUILDDIR=/build/target/debug/zombodb-pg${PGVER}
else
  BUILDDIR=/build/target/artifacts/zombodb-pg${PGVER}
fi

#
# copy over the sql/releases/zombodb--pg${PGVER} the caller should have already made with `prepare-release.sh`
#
cp -v sql/releases/zombodb--${VERSION}.sql  ${BUILDDIR}$(pg_config --sharedir)/extension/ || exit $?

# move into the build directory

cd ${BUILDDIR} || exit $?

if [ "$DEBUG" == "false" ] ; then
  # strip the binaries to make them smaller
  find ./ -name "*.so" -exec strip {} \;
fi

#
# then use 'fpm' to build either a .deb, .rpm or .apk
#

## hack for when we installed ruby via rvm.  if it doesn't work we don't care
source ~/.rvm/scripts/rvm

# architecture name
UNAME=$(uname -m)
DEBUNAME=${UNAME}
if [ "${DEBUNAME}" == "x86_64" ]; then
    # name used for .deb packages is different for historical reasons
    DEBUNAME="amd64"
fi

if [ "${PKG_FORMAT}" == "deb" ]; then
	fpm \
		-s dir \
		-t deb \
		-n zombodb-${PGVER} \
		-v ${VERSION} \
		--deb-no-default-config-files \
		-p ${ARTIFACTDIR}/zombodb_${OSNAME}_pg${PGVER}-${VERSION}_${DEBUNAME}.deb \
		-a ${DEBUNAME} \
		. || exit 1

elif [ "${PKG_FORMAT}" == "rpm" ]; then
	fpm \
		-s dir \
		-t rpm \
		-n zombodb-${PGVER} \
		-v ${VERSION} \
		--rpm-os linux \
		-p ${ARTIFACTDIR}/zombodb_${OSNAME}_pg${PGVER}-${VERSION}_1.${UNAME}.rpm \
		-a ${UNAME} \
		. || exit 1

elif [ "${PKG_FORMAT}" == "apk" ]; then
	fpm \
		-s dir \
		-t apk \
		-n zombodb-${PGVER} \
		-v ${VERSION} \
		-p ${ARTIFACTDIR}/zombodb_${OSNAME}_pg${PGVER}-${VERSION}.${UNAME}.apk \
		-a ${UNAME} \
		. \
		|| exit 1

else
	echo Unrecognized value for PKG_FORMAT:  ${PKG_FORMAT}
	exit 1
fi


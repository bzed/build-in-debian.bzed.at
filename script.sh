#!/bin/sh

# |_     o  |  _|--- o __ --- _| _ |_  o  _ __    |_  _  _  _|    _ _|_
# |_)|_| |  | (_|    | | |   (_|(/_|_) | (_|| | o |_) /_(/_(_| o (_| |_
#
#    based on the code of
#_                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
#
#
#               Documentation: <http://build-in-debian.bzed.at>


## Copyright ##################################################################
#
# Copyright © 2017 Bernd Zeimetz <bernd@bzed.de>
# Copyright © 2015, 2016 Chris Lamb <lamby@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Functions ##################################################################

set -eu

Info () {
	echo "I: ${*}" >&2
}

Error () {
	echo "E: ${*}" >&2
}

## Configuration ##############################################################

SOURCE="${TRAVIS_REPO_SLUG}"

Info "Starting build of ${SOURCE} using build-in-debian.bzed.at"

TRAVIS_DEBIAN_MIRROR="${TRAVIS_DEBIAN_MIRROR:-http://ftp.de.debian.org/debian}"
TRAVIS_DEBIAN_BUILD_DIR="${TRAVIS_DEBIAN_BUILD_DIR:-/build}"
TRAVIS_DEBIAN_NETWORK_ENABLED="${TRAVIS_DEBIAN_NETWORK_ENABLED:-false}"

#### Dependencies and Build command ###########################################
if [ "${TRAVIS_DEBIAN_BUILD_DEPENDENCIES:-}" = "" ]
then
	Info "Automatically using build-essential as the only build dependency"
        TRAVIS_DEBIAN_BUILD_DEPENDENCIES="build-essential"
fi
if [ "${TRAVIS_DEBIAN_BUILD_COMMAND:-}" = "" ]
then
	Info "Automatically using 'make' as build command"
        TRAVIS_DEBIAN_BUILD_COMMAND="make"
fi


#### Distribution #############################################################

TRAVIS_DEBIAN_BACKPORTS="${TRAVIS_DEBIAN_BACKPORTS:-false}"
TRAVIS_DEBIAN_EXPERIMENTAL="${TRAVIS_DEBIAN_EXPERIMENTAL:-false}"

if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
then
	Info "Using sid as Debian distribution"

	TRAVIS_DEBIAN_DISTRIBUTION="sid"
fi
if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
then
	Info "Using sid as Debian distribution"

	TRAVIS_DEBIAN_DISTRIBUTION="sid"
fi

# Detect codenames
case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	oldstable)
		TRAVIS_DEBIAN_DISTRIBUTION="wheezy"
		;;
	stable)
		TRAVIS_DEBIAN_DISTRIBUTION="jessie"
		;;
	testing)
		TRAVIS_DEBIAN_DISTRIBUTION="stretch"
		;;
	unstable|master)
		TRAVIS_DEBIAN_DISTRIBUTION="sid"
		;;
	experimental)
		TRAVIS_DEBIAN_DISTRIBUTION="sid"
		TRAVIS_DEBIAN_EXPERIMENTAL="true"
		;;
esac

case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	sid)
		TRAVIS_DEBIAN_SECURITY_UPDATES="${TRAVIS_DEBIAN_SECURITY_UPDATES:-false}"
		;;
	*)
		TRAVIS_DEBIAN_SECURITY_UPDATES="${TRAVIS_DEBIAN_SECURITY_UPDATES:-true}"
		;;
esac


## Print configuration ########################################################

Info "Using distribution: ${TRAVIS_DEBIAN_DISTRIBUTION}"
Info "Backports enabled: ${TRAVIS_DEBIAN_BACKPORTS}"
Info "Experimental enabled: ${TRAVIS_DEBIAN_EXPERIMENTAL}"
Info "Security updates enabled: ${TRAVIS_DEBIAN_SECURITY_UPDATES}"
Info "Will use extra repository: ${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-<not set>}"
Info "Extra repository's key URL: ${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-<not set>}"
Info "Will build under: ${TRAVIS_DEBIAN_BUILD_DIR}"
Info "Using mirror: ${TRAVIS_DEBIAN_MIRROR}"
Info "Network enabled during build: ${TRAVIS_DEBIAN_NETWORK_ENABLED}"
Info "Build Dependencies: ${TRAVIS_DEBIAN_BUILD_DEPENDENCIES}"
Info "Build Command: ${TRAVIS_DEBIAN_BUILD_COMMAND}"


cat >Dockerfile <<EOF
FROM debian:${TRAVIS_DEBIAN_DISTRIBUTION}
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION} main" > /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION} main" >> /etc/apt/sources.list
EOF

if [ "${TRAVIS_DEBIAN_BACKPORTS}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" >> /etc/apt/sources.list
EOF
fi

if [ "${TRAVIS_DEBIAN_SECURITY_UPDATES}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb http://security.debian.org/ ${TRAVIS_DEBIAN_DISTRIBUTION}/updates main" >> /etc/apt/sources.list
RUN echo "deb-src http://security.debian.org/ ${TRAVIS_DEBIAN_DISTRIBUTION}/updates main" >> /etc/apt/sources.list
EOF
fi

if [ "${TRAVIS_DEBIAN_EXPERIMENTAL}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} experimental main" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} experimental main" >> /etc/apt/sources.list
EOF
fi

EXTRA_PACKAGES=""

case "${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-}" in
	https:*)
		EXTRA_PACKAGES="${EXTRA_PACKAGES} apt-transport-https"
		;;
esac

if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-}" != "" ]
then
	EXTRA_PACKAGES="${EXTRA_PACKAGES} wget gnupg"
fi

cat >>Dockerfile <<EOF
RUN apt-get update && apt-get dist-upgrade --yes
RUN apt-get install --yes --no-install-recommends ${EXTRA_PACKAGES}

WORKDIR $(pwd)
COPY . .
EOF

if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-}" != "" ]
then
	cat >>Dockerfile <<EOF
RUN wget -O- "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL}" | apt-key add -
EOF
fi

# We're adding the extra repository only after the essential tools have been
# installed, so that we have apt-transport-https if the repository needs it.
if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-}" != "" ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_EXTRA_REPOSITORY}" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_EXTRA_REPOSITORY}" >> /etc/apt/sources.list
RUN apt-get update
EOF
fi

if [ "${TRAVIS_DEBIAN_BACKPORTS}" = "true" ]
then
        cat >>Dockerfile <<EOF
RUN echo "Package: *" >> /etc/apt/preferences.d/travis_debian_net
RUN echo "Pin: release a=${TRAVIS_DEBIAN_DISTRIBUTION}-backports" >> /etc/apt/preferences.d/travis_debian_net
RUN echo "Pin-Priority: 500" >> /etc/apt/preferences.d/travis_debian_net
EOF
fi

cat >>Dockerfile <<EOF
RUN env DEBIAN_FRONTEND=noninteractive apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes ${TRAVIS_DEBIAN_BUILD_DEPENDENCIES}

RUN rm -f Dockerfile
RUN git checkout .travis.yml || true
RUN mkdir -p ${TRAVIS_DEBIAN_BUILD_DIR}

RUN git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
RUN git fetch
RUN for X in \$(git branch -r | grep -v HEAD); do git branch --track \$(echo "\${X}" | sed -e 's@.*/@@g') \${X} || true; done

CMD ${TRAVIS_DEBIAN_BUILD_COMMAND}
EOF

Info "Using Dockerfile:"
sed -e 's@^@  @g' Dockerfile

TAG="build-in-debian.bzed.at/${SOURCE}"

Info "Building Docker image ${TAG}"
docker build --tag=${TAG} .

Info "Removing Dockerfile"
rm -f Dockerfile

CIDFILE="$(mktemp --dry-run)"
ARGS="--cidfile=${CIDFILE}"

if [ "${TRAVIS_DEBIAN_NETWORK_ENABLED}" != "true" ]
then
	ARGS="${ARGS} --net=none"
fi

Info "Running build"
docker run --env=DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-}" ${ARGS} ${TAG}

Info "Removing container"
docker rm "$(cat ${CIDFILE})" >/dev/null
rm -f "${CIDFILE}"

                                                                     
# |_     o  |  _|--- o __ --- _| _ |_  o  _ __    |_  _  _  _|    _ _|_
# |_)|_| |  | (_|    | | |   (_|(/_|_) | (_|| | o |_) /_(/_(_| o (_| |_


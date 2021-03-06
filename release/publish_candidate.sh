#!/bin/sh -e

# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

EMAIL_TPL=../email/vote_release.txt

if test -n "$1"; then
    candidate_dir=$1
else
    echo "error: no candidate directory"
    exit
fi

if test -n "$2"; then
    branch=$2
else
    echo "error: no branch"
    exit
fi

if test -n "$3"; then
    version=$3
else
    echo "error: no version"
    exit
fi

if test -n "$4"; then
    candidate=$4
else
    echo "error: no candidate number"
    exit
fi

log () {
    printf "\033[1;31m$1\033[0m\n"
}

cd `dirname $0`

basename=`basename $0`

log "Creating temporary directory..."

tmp_dir=`mktemp -d /tmp/$basename.XXXXXX` || exit 1

echo $tmp_dir

build_file=$tmp_dir/build.mk

cat > $build_file <<EOF
SVN_URL=https://dist.apache.org/repos/dist/dev/couchdb

TMP_DIR=$tmp_dir

SVN_DIR=\$(TMP_DIR)/svn

EMAIL_TPL=$EMAIL_TPL

EMAIL_FILE=\$(TMP_DIR)/email.txt

BRANCH=$branch

VERSION=$version

CANDIDATE=$candidate

PACKAGE=apache-couchdb-\$(VERSION)

CANDIDATE_DIR=$candidate_dir

CANDIDATE_URL=\$(SVN_URL)/source/\$(VERSION)/rc.\$(CANDIDATE)

CANDIDATE_TGZ_FILE=\$(CANDIDATE_DIR)/\$(PACKAGE).tar.gz

SVN_TGZ_FILE=\$(SVN_DIR)/\$(PACKAGE).tar.gz

COMMIT_MSG_DIR="Add \$(VERSION)-rc.\$(CANDIDATE) dir"

COMMIT_MSG_FILES="Add \$(VERSION)-rc.\$(CANDIDATE) files"

GPG=gpg --armor --detach-sig \$(GPG_ARGS)

SVN=svn --config-dir \$(SVN_DOT_DIR) --no-auth-cache

all: checkin

checkin: sign
	cd \$(SVN_DIR) && svn add \$(SVN_TGZ_FILE)
	cd \$(SVN_DIR) && svn add \$(SVN_TGZ_FILE).asc
	cd \$(SVN_DIR) && svn add \$(SVN_TGZ_FILE).ish
	cd \$(SVN_DIR) && svn add \$(SVN_TGZ_FILE).md5
	cd \$(SVN_DIR) && svn add \$(SVN_TGZ_FILE).sha
	cd \$(SVN_DIR) && svn status
	sleep 10
	cd \$(SVN_DIR) && svn ci -m \$(COMMIT_MSG_FILES)

sign: copy
	cd \$(SVN_DIR) && \
	    \$(GPG) < \$(PACKAGE).tar.gz > \$(PACKAGE).tar.gz.asc
	cd \$(SVN_DIR) && \
	    md5sum \$(PACKAGE).tar.gz > \$(PACKAGE).tar.gz.md5
	cd \$(SVN_DIR) && \
	    sha1sum \$(PACKAGE).tar.gz > \$(PACKAGE).tar.gz.sha

copy: check
	cp \$(CANDIDATE_TGZ_FILE) \$(SVN_TGZ_FILE)
	cp \$(CANDIDATE_TGZ_FILE).ish \$(SVN_TGZ_FILE).ish

check: \$(SVN_DIR)
	test -s \$(CANDIDATE_TGZ_FILE)
	test -s \$(CANDIDATE_TGZ_FILE).ish

\$(SVN_DIR): \$(SVN_DOT_DIR)
	svn mkdir --parents \$(CANDIDATE_URL) -m \$(COMMIT_MSG_DIR)
	sleep 10
	svn co \$(CANDIDATE_URL) \$@

email: \$(EMAIL_FILE)

\$(EMAIL_FILE): \$(EMAIL_TPL)
	sed -e "s|%BRANCH%|\$(BRANCH)|g" \
	    -e "s|%VERSION%|\$(VERSION)|g" \
	    -e "s|%CANDIDATE%|\$(CANDIDATE)|g"  \
	    -e "s|%CANDIDATE_URL%|\$(CANDIDATE_URL)|g" \
	    -e "s|%PACKAGE%|\$(PACKAGE)|g" > \
	    \$@ < \$<
EOF

log "Adding candidate to the release dist directory..."

make -f $build_file

log "Generating email template..."

make -f $build_file email

email_file=$tmp_dir/email.txt

echo "Email text written to:" $email_file

echo "Files in: $tmp_dir"

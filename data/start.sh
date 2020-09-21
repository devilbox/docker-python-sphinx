#!/bin/sh

set -e
set -u


###
### Default Variables
###
DEFAULT_SPHINX_PROJECT="."
DEFAULT_SPHINX_BUILD_DIR="_build/html"
DEFAULT_SPHINX_PORT=8000
DEFAULT_NEW_UID=1000
DEFAULT_NEW_GID=1000


# -------------------------------------------------------------------------------------------------
# Optional Environment variables
# -------------------------------------------------------------------------------------------------

###
### Custom project directory?
###
PROJECT="/shared/httpd"
if ! env | grep '^SPHINX_PROJECT=' >/dev/null; then
	echo "[INFO] Keeping SPHINX_PROJECT at default: ${DEFAULT_SPHINX_PROJECT}"
else
	echo "[INFO] Setting SPHINX_PROJECT to: ${SPHINX_PROJECT}"
	DEFAULT_SPHINX_PROJECT="${SPHINX_PROJECT}"

	if [ "${SPHINX_PROJECT}" != "." ]; then
		PROJECT="/shared/httpd/${SPHINX_PROJECT}"
	fi
fi


###
### Custom listening port?
###
if ! env | grep '^SPHINX_PORT=' >/dev/null; then
	echo "[INFO] Keeping internal Sphinx port at default: ${DEFAULT_SPHINX_PORT}"
else
	echo "[INFO] Setting internal Sphinx port to: ${SPHINX_PORT}"
	DEFAULT_SPHINX_PORT="${SPHINX_PORT}"
fi


###
### Custom build dir?
###
if ! env | grep '^SPHINX_BUILD_DIR=' >/dev/null; then
	echo "[INFO] Keeping SPHINX_BUILD_DIR at default: ${DEFAULT_SPHINX_BUILD_DIR}"
else
	echo "[INFO] Setting SPHINX_BUILD_DIR to: ${SPHINX_BUILD_DIR}"
	DEFAULT_SPHINX_BUILD_DIR="${SPHINX_BUILD_DIR}"
fi


###
### Adjust uid/gid
###
if ! env | grep '^NEW_UID=' >/dev/null; then
	echo "[INFO] Keeping NEW_UID at default: ${DEFAULT_NEW_UID}"
else
	echo "[INFO] Setting NEW_UID to: ${NEW_UID}"
	DEFAULT_NEW_UID="${NEW_UID}"
fi

if ! env | grep '^NEW_GID=' >/dev/null; then
	echo "[INFO] Keeping NEW_GID at default: ${DEFAULT_NEW_GID}"
else
	echo "[INFO] Setting NEW_GID to: ${NEW_GID}"
	DEFAULT_NEW_GID="${NEW_GID}"
fi

sed -i'' "s|^devilbox:.*$|devilbox:x:${DEFAULT_NEW_GID}:devilbox|g" /etc/group
ETC_GROUP="$( grep '^devilbox' /etc/group )"
echo "[INFO] /etc/group: ${ETC_GROUP}"

sed -i'' "s|^devilbox:.*$|devilbox:x:${DEFAULT_NEW_UID}:${DEFAULT_NEW_GID}:Linux User,,,:/home/devilbox:/bin/ash|g" /etc/passwd
ETC_PASSWD="$( grep '^devilbox' /etc/passwd )"
echo "[INFO] /etc/passwd: ${ETC_PASSWD}"

chown "${DEFAULT_NEW_UID}:${DEFAULT_NEW_GID}" /home/devilbox
chown "${DEFAULT_NEW_UID}:${DEFAULT_NEW_GID}" /shared/httpd
PERM_HOME="$( ls -ld /home/devilbox )"
PERM_DATA="$( ls -ld /shared/httpd )"
echo "[INFO] ${PERM_HOME}"
echo "[INFO] ${PERM_DATA}"


# -------------------------------------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------------------------------------

##
## Check project directory
##
if [ ! -d "${PROJECT}" ]; then
	>&2 echo "[WARN] <project> directory does not exist: ${PROJECT}"
fi

su -c "
	set -e
	set -u

	if [ ! -d \"${PROJECT}\" ]; then
		echo \"[INFO] Creating project dir: ${PROJECT}\"
		mkdir -p \"${PROJECT}\"
	fi


	if [ ! -d \"${PROJECT}/venv\" ]; then
		echo \"[INFO] Creating Python virtual env: ${PROJECT}/venv\"
		cd \"${PROJECT}\"
		virtualenv venv
	fi

	if [ ! -d \"${PROJECT}/${DEFAULT_SPHINX_BUILD_DIR}\" ]; then
		echo \"[INFO] Creating build dir: ${PROJECT}/${DEFAULT_SPHINX_BUILD_DIR}\"
		mkdir -p \"${PROJECT}/${DEFAULT_SPHINX_BUILD_DIR}\"
	fi" devilbox


# -------------------------------------------------------------------------------------------------
# Entrypoint
# -------------------------------------------------------------------------------------------------

if [ "${#}" -gt "0" ]; then
	exec su -c "
		set -e
		set -u

		cd \"${PROJECT}\"

		. venv/bin/activate
		if [ ! -f \"${PROJECT}/requirements.txt\" ]; then
			echo \"[INFO] No requirements.txt file found at: ${PROJECT}/requirements.txt\"
		else
			echo \"[INFO] Installing pip requirements from: ${PROJECT}/requirements.txt\"
			pip install -r \"${PROJECT}/requirements.txt\"
		fi

		set -x
		${*}" devilbox
else
	exec su -c "
		set -e
		set -u

		cd \"${PROJECT}\"

		. venv/bin/activate
		if [ ! -f \"${PROJECT}/requirements.txt\" ]; then
			echo \"[INFO] No requirements.txt file found at: ${PROJECT}/requirements.txt\"
		else
			echo \"[INFO] Installing pip requirements from: ${PROJECT}/requirements.txt\"
			pip install -r \"${PROJECT}/requirements.txt\"
		fi

		set -x
		sphinx-autobuild -a -E -n -j auto -q --host 0.0.0.0 --port ${DEFAULT_SPHINX_PORT} . ${DEFAULT_SPHINX_BUILD_DIR}" devilbox
fi

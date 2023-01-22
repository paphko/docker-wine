#!/usr/bin/env bash

is_enabled () {
    echo "$1" | grep -q -i -E "^(yes|on|true|1)$"
}

is_disabled () {
    echo "$1" | grep -q -i -E "^(no|off|false|0)$"
}


# Set user account and run values
USER_NAME=${USER_NAME:-wineuser}
USER_UID=${USER_UID:-1010}
USER_GID=${USER_GID:-"${USER_UID}"}
USER_HOME=${USER_HOME:-/home/"${USER_NAME}"}
USER_PASSWD=${USER_PASSWD:-"$(openssl passwd -1 -salt "$(openssl rand -base64 6)" "${USER_NAME}")"}
USER_SUDO=${USER_SUDO:-yes}
RUN_AS_ROOT=${RUN_AS_ROOT:-no}
FORCED_OWNERSHIP=${FORCED_OWNERSHIP:-no}
TZ=${TZ:-UTC}
USE_XVFB=${USE_XVFB:-no}

# Catch attempts to set user as root
if [ "${USER_NAME}" = 'root' ] || [ "${USER_UID}" -eq 0 ] || [ "${USER_GID}" -eq 0 ]; then
    echo "ERROR: To run as root, either set env RUN_AS_ROOT=yes --as-root"
    exit 1
fi

# Create the user account
grep -q ":${USER_GID}:$" /etc/group || groupadd --gid "${USER_GID}" "${USER_NAME}"
grep -q "^${USER_NAME}:" /etc/passwd || useradd --shell /bin/bash --uid "${USER_UID}" --gid "${USER_GID}" --password "${USER_PASSWD}" --no-create-home --home-dir "${USER_HOME}" "${USER_NAME}"

# Create the user's home if it doesn't exist
[ -d "${USER_HOME}" ] || mkdir -p "${USER_HOME}"

# Add or remove user from sudo group
if is_enabled "${USER_SUDO}"; then
    groups "${USER_NAME}" | tr " " "\n" | grep -q "^sudo$" || usermod -aG sudo "${USER_NAME}"
elif is_disabled "${USER_SUDO}"; then
    ! groups "${USER_NAME}" | tr " " "\n" | grep -q "^sudo$" || gpasswd -d "${USER_NAME}" sudo
else
    echo "ERROR: '${USER_SUDO}' is not a valid value for USER_SUDO"
    exit 1
fi

# Take ownership of user's home directory if owned by root or if FORCED_OWNERSHIP is enabled
OWNER_IDS="$(stat -c "%u:%g" "${USER_HOME}")"
if [ "${OWNER_IDS}" != "${USER_UID}:${USER_GID}" ]; then
    if [ "${OWNER_IDS}" == "0:0" ] || is_enabled "${FORCED_OWNERSHIP}"; then
        chown -R "${USER_UID}":"${USER_GID}" "${USER_HOME}"
    else
        echo "ERROR: User's home '${USER_HOME}' is currently owned by $(stat -c "%U:%G" "${USER_HOME}")"
        echo "Use option --force-owner to enable user ${USER_NAME} to take ownership"
        exit 1
    fi
fi

# Run xvfb
if is_enabled "${USE_XVFB}"; then
	nohup /usr/bin/Xvfb "${XVFB_SERVER}" -screen "${XVFB_SCREEN}" "${XVFB_RESOLUTION}" >/dev/null 2>&1 &
fi

# Generate .Xauthority using xauth with .Xkey sourced from host
if [ -f /root/.Xkey ]; then
	[ -f /root/.Xauthority ] || touch /root/.Xauthority
	xauth add "$DISPLAY" . "$(cat /root/.Xkey)"
fi

# Run in X11 redirection mode as $USER_NAME (default)
if is_disabled "${RUN_AS_ROOT}"; then

	# Copy and take ownership of .Xauthority for X11 redirection
	if [ -f /root/.Xauthority ] && is_disabled "${USE_XVFB}"; then
		cp /root/.Xauthority "${USER_HOME}"
		chown "${USER_UID}":"${USER_GID}" "${USER_HOME}/.Xauthority"
	fi

	# Run in X11 redirection mode as user
	exec gosu "${USER_NAME}" "$@"

# Run in X11 redirection mode as root
elif is_enabled "${RUN_AS_ROOT}"; then
	exec "$@"
else
	echo "ERROR: '${RUN_AS_ROOT}' is not a valid value for RUN_AS_ROOT"
	exit 1
fi


#!/usr/bin/env bash

set -e
set -u
set -o pipefail

TEST_PATH="$( cd "$(dirname "$0")" && pwd -P )"
ROOT_PATH="$( cd "${TEST_PATH}/.." && pwd -P )"

retry() {
	for ((n=0; n<40; n++)); do
		echo "[${n}] ${*}"
		if eval "${*}"; then
			return 0
		fi
		sleep 1
	done
	return 1
}

IMAGE="${1}"
PYTHON="${2}"
NAME="devilbox-python-sphinx-${PYTHON}"


# -------------------------------------------------------------------------------------------------
# Clean environment
# -------------------------------------------------------------------------------------------------
rm -rf "${ROOT_PATH}/test-project/venv"
docker stop "${NAME}" >/dev/null 2>&1 || true
docker rm -f "${NAME}" >/dev/null 2>&1  || true


echo
echo "# -------------------------------------------------------------------------------------------------"
echo "# Test Container"
echo "# -------------------------------------------------------------------------------------------------"
echo

docker run --rm -d \
	--name "${NAME}" \
	-v "${ROOT_PATH}/test-project:/shared/httpd/test-project" \
	-p "8000:8000" \
	-e NEW_UID="$(id -u)" \
	-e NEW_GID="$(id -g)" \
	-e SPHINX_PROJECT="test-project" \
	"${IMAGE}:${PYTHON}-dev"

if ! retry curl -sS 'http://localhost:8000' | grep 'Test Documentation'; then
	docker ps -a --no-trunc || true
	docker logs "${NAME}" || true
	docker stop "${NAME}" >/dev/null 2>&1 || true
	docker rm -f "${NAME}" >/dev/null 2>&1  || true

	# Start in with log output to see what happens
	docker run --rm \
		--name "${NAME}" \
		-v "${ROOT_PATH}/test-project:/shared/httpd/test-project" \
		-p "3000:8000" \
		-e SPHINX_PROJECT="test-project" \
		-e NEW_UID="$(id -u)" \
		-e NEW_GID="$(id -g)" \
		"${IMAGE}:${PYTHON}-dev" &
	sleep 20
	docker stop "${NAME}" >/dev/null 2>&1 || true
	docker rm -f "${NAME}" >/dev/null 2>&1  || true
	exit 1
fi

docker logs "${NAME}"
docker stop "${NAME}" || true
docker rm -f "${NAME}" >/dev/null 2>&1  || true


echo
echo "# -------------------------------------------------------------------------------------------------"
echo "# Test Docker Compose"
echo "# -------------------------------------------------------------------------------------------------"
echo
cp -f "${ROOT_PATH}/.env.example" "${ROOT_PATH}/.env"
sed -i'' "s/^PYTHON_VERSION=.*/PYTHON_VERSION=${PYTHON}/g" "${ROOT_PATH}/.env"
sed -i'' "s/^NEW_UID=.*/NEW_UID=$(id -u)/g" "${ROOT_PATH}/.env"
sed -i'' "s/^NEW_GID=.*/NEW_GID=$(id -g)/g" "${ROOT_PATH}/.env"

cd "${ROOT_PATH}"
docker-compose up -d


if ! retry curl -sS 'http://localhost:8000' | grep 'Test Documentation'; then
	docker ps -a --no-trunc || true
	docker-compose logs || true
	docker-compose stop >/dev/null 2>&1 || true
	docker-compose rm -f >/dev/null 2>&1  || true

	# Start in with log output to see what happens
	docker-compose up &
	sleep 20
	docker-compose stop >/dev/null 2>&1 || true
	docker-compose rm -f >/dev/null 2>&1  || true
	exit 1
fi

docker-compose logs
docker-compose stop || true
docker-compose rm -f >/dev/null 2>&1  || true

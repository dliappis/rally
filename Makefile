# We assume an active virtualenv for development
include requirements.txt
VENV_NAME ?= .venv
VENV_ACTIVATE_FILE = $(VENV_NAME)/bin/activate
VENV_ACTIVATE = . $(VENV_ACTIVATE_FILE)
prereq: requirements.txt
	pyenv install $(PY34)
	pyenv install $(PY35)
	pyenv install $(PY36)
	pyenv install $(PY37)
	pyenv global system $(PY34) $(PY35) $(PY36) $(PY37)
	-@printf "\033[0;31mIMPORTANT\033[0m: please add \033[0;31meval \"\$$"
	-@printf "(pyenv init -)\"\033[0m to your bash profile and restart your terminal before proceeding any further.\n"

venv-create:
	-@if [ ! -f $(VENV_ACTIVATE_FILE) ]; then python3 -mvenv ${VENV_NAME}; fi;	
venv:
	-@$(VENV_ACTIVATE)

install: venv-create venv
	-@python3 setup.py -q develop --upgrade
	# also install development dependencies
	# workaround for https://github.com/elastic/rally/issues/439
	-@pip3 install -q sphinx sphinx_rtd_theme

clean: nondocs-clean docs-clean

nondocs-clean:
	rm -rf .benchmarks .eggs .tox .rally_it .cache build dist esrally.egg-info logs junit-py*.xml

docs-clean:
	cd docs && $(MAKE) clean

# Avoid conflicts between .pyc/pycache related files created by local Python interpreters and other interpreters in Docker
python-caches-clean:
	-@find . -name "__pycache__" -exec rm -rf -- \{\} \;
	-@find . -name ".pyc" -exec rm -rf -- \{\} \;

docs: venv
	cd docs && $(MAKE) html

test: venv
	python3 setup.py test

it: venv python-caches-clean
	tox

it34: venv python-caches-clean
	tox -e py34

it35: venv python-caches-clean
	tox -e py35

it36: venv python-caches-clean
	tox -e py36

it37: venv python-caches-clean
	tox -e py37

benchmark: venv
	python3 setup.py pytest --addopts="-s benchmarks"

coverage: venv
	coverage run setup.py test
	coverage html

release-checks: venv
	./release-checks.sh $(release_version) $(next_version)

# usage: e.g. make release release_version=0.9.2 next_version=0.9.3
release: venv release-checks clean docs it
	./release.sh $(release_version) $(next_version)

docker-it: nondocs-clean python-caches-clean
	@if ! export | grep UID; then export UID=$(shell id -u) >/dev/null 2>&1 || export UID; fi ; \
	if ! export | grep USER; then export USER=$(shell echo $$USER); fi ; \
	if ! export | grep PWD; then export PWD=$(shell pwd); fi ; \
	docker-compose build --pull; `# add --pull here to rebuild a fresh image` \
	docker-compose run --rm rally-tests /bin/bash -c "make docs-clean && make it"

.PHONY: install clean nondocs-clean docs-clean python-caches-clean docs test docker-it it it34 it35 it36 benchmark coverage release release-checks

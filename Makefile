SHELL = /bin/bash
# We assume an active virtualenv for development
include requirements.txt
VENV_NAME ?= .venv
VENV_ACTIVATE_FILE = $(VENV_NAME)/bin/activate
VENV_ACTIVATE = . $(VENV_ACTIVATE_FILE)
VEPYTHON = $(VENV_NAME)/bin/python3
PYENV_PREREQ_HELP = "\033[0;31mIMPORTANT\033[0m: please add \033[0;31meval \"\$$(pyenv init -)\"\033[0m to your bash profile and restart your terminal before proceeding any further.\n"
VE_MISSING_HELP = "\033[0;31mIMPORTANT\033[0m: Couldn't find $(PWD)/$(VENV_NAME); have you executed make venv-create?\033[0m\n"

prereq: requirements.txt
	pyenv install $(PY34)
	pyenv install $(PY35)
	pyenv install $(PY36)
	pyenv install $(PY37)
	pyenv global system $(PY34) $(PY35) $(PY36) $(PY37)
	-@ printf $(PYENV_PREREQ_HELP)

venv-create:
	@if [[ ! -f $(VENV_ACTIVATE_FILE) ]]; then \
	    eval "$$(pyenv init -)" && python3 -mvenv $(VENV_NAME); \
	    printf "Created python3 venv under $(PWD)/$(VENV_NAME).\n"; \
	fi;

check-venv:
	@if [[ ! -f $(VENV_ACTIVATE_FILE) ]]; then \
          printf $(VE_MISSING_HELP); \
	fi

install: venv-create
	. $(VENV_ACTIVATE_FILE); pip3 install -e .
	# install tox for it tests
	. $(VENV_ACTIVATE_FILE); pip3 install tox
	# also install development dependencies
	# workaround for https://github.com/elastic/rally/issues/439
	. $(VENV_ACTIVATE_FILE); pip3 install -q sphinx sphinx_rtd_theme

clean: nondocs-clean docs-clean

nondocs-clean:
	rm -rf .benchmarks .eggs .tox .rally_it .cache build dist esrally.egg-info logs junit-py*.xml

docs-clean:
	cd docs && $(MAKE) clean

# Avoid conflicts between .pyc/pycache related files created by local Python interpreters and other interpreters in Docker
python-caches-clean:
	-@find . -name "__pycache__" -exec rm -rf -- \{\} \;
	-@find . -name ".pyc" -exec rm -rf -- \{\} \;

docs: check-venv
	cd docs && $(MAKE) html

test: check-venv
	$(VEPYTHON) setup.py test

it: check-venv python-caches-clean
	. $(VENV_ACTIVATE_FILE); tox

it34: check-venv python-caches-clean
	tox -e py34

it35: check-venv python-caches-clean
	tox -e py35

it36: check-venv python-caches-clean
	tox -e py36

it37: check-venv python-caches-clean
	tox -e py37

benchmark: check-venv
	python3 setup.py pytest --addopts="-s benchmarks"

coverage: check-venv
	coverage run setup.py test
	coverage html

release-checks: check-venv
	./release-checks.sh $(release_version) $(next_version)

# usage: e.g. make release release_version=0.9.2 next_version=0.9.3
release: check-venv release-checks clean docs it
	./release.sh $(release_version) $(next_version)

docker-it: nondocs-clean python-caches-clean
	@if ! export | grep UID; then export UID=$(shell id -u) >/dev/null 2>&1 || export UID; fi ; \
	if ! export | grep USER; then export USER=$(shell echo $$USER); fi ; \
	if ! export | grep PWD; then export PWD=$(shell pwd); fi ; \
	docker-compose build --pull; `# add --pull here to rebuild a fresh image` \
	docker-compose run --rm rally-tests /bin/bash -c "make docs-clean && make it"

.PHONY: install clean nondocs-clean docs-clean python-caches-clean docs test docker-it it it34 it35 it36 benchmark coverage release release-checks prereq venv-create check-env

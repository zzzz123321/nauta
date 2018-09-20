# Copyright (c) 2018, Intel Corporation

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

build-conditional-deep-clean:
ifeq (Darwin,$(OS))
	@echo Removes all virtualenv on MacOS
	@rm -rf $(VIRTUALENV_DIR)
	@rm -rf vendor
endif

build: $(ACTIVATE) set-version metrics-lib
	@. $(ACTIVATE); pip install pyinstaller;

ifeq (Windows,$(OS))
	@. $(ACTIVATE); pyinstaller --paths "C:\Program Files (x86)\Windows Kits\10\Redist\ucrt\DLLs\x64" main.py --add-data "util/nbformat.v4.schema.json:.\nbformat\v4" -F --exclude-module readline -n dlsctl;
	@curl http://repository.toolbox.nervana.sclab.intel.com/files/draft-bundles/windows/draft-v0.13.0-dls-windows-amd64.7z -o draft.7z
	@mkdir dist/dls_ctl_config/
	@7z x draft.7z -odist/dls_ctl_config/
	@rm -f draft.7z
	@curl http://repository.toolbox.nervana.sclab.intel.com/files/socat-container-image.tar.gz -o dist/dls_ctl_config/socat-container-image.tar.gz
endif
ifeq (Linux,$(OS))
	@. $(ACTIVATE); pyinstaller main.py --add-data util/nbformat.v4.schema.json:./nbformat/v4 --exclude-module readline -F -n dlsctl;
	@curl http://repository.toolbox.nervana.sclab.intel.com/files/draft-bundles/linux/draft-v0.13.0-dls-linux-amd64.tar.gz -o draft.tar.gz
	@cp set-autocomplete.sh dist/
	@chmod +x dist/set-autocomplete.sh
	@mkdir dist/dls_ctl_config/
	@tar -zxf draft.tar.gz -C dist/dls_ctl_config/
	@rm -f draft.tar.gz
endif
ifeq (Darwin,$(OS))
	@. $(ACTIVATE); pyinstaller main.py --add-data util/nbformat.v4.schema.json:./nbformat/v4 --exclude-module readline -F -n dlsctl;
	@curl http://repository.toolbox.nervana.sclab.intel.com/files/draft-bundles/mac/draft-v0.13.0-dls-darwin-amd64.tar.gz -o draft.tar.gz
	@mkdir dist/dls_ctl_config/
	@tar -zxf draft.tar.gz -C dist/dls_ctl_config/
	@rm -f draft.tar.gz
	@curl http://repository.toolbox.nervana.sclab.intel.com/files/socat-container-image.tar.gz -o dist/dls_ctl_config/socat-container-image.tar.gz
endif


	@cp -Rf draft/packs/* dist/dls_ctl_config/.draft/packs/
	@cp -Rf ../dls4e-user dist/dls_ctl_config/
	@mkdir -p dist/lib/
	@mv experiment_metrics/dist/experiment_metrics-0.0.1.tar.gz dist/lib/
	@cp -f license.txt dist/
	@mkdir -p dist/docs/
	@cp -f ../applications/dls-gui/src/assets/*.pdf dist/docs/

metrics-lib:
	@. $(ACTIVATE); cd experiment_metrics && python setup.py sdist

style: $(DEV_VIRTUALENV_MARK)
	@. $(ACTIVATE); flake8 draft/ util/ commands/ main.py

test: $(DEV_VIRTUALENV_MARK)
	@. $(ACTIVATE); LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 py.test

cli-check: venv-dev test style

test-with-code-cov: $(DEV_VIRTUALENV_MARK)
	@. $(ACTIVATE); LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 py.test
	#@. $(ACTIVATE); LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 py.test --cov=. --cov-config tox.ini --cov-report term-missing



export CLI_ARTIFACT_DIRECTORY:=$(CURDIR)
export CLI_ARTIFACT_VERSION_STRING:=$(VERSION_CLIENT_MAJOR).$(VERSION_CLIENT_MINOR).$(VERSION_CLIENT_NO)-$(BUILD_ID)

ifeq (Windows,$(OS))
export CLI_ARTIFACT_NAME:=dlsctl-$(CLI_ARTIFACT_VERSION_STRING)-windows.zip
export CLI_ARTIFACT_PLATFORM:=windows
endif
ifeq (Linux,$(OS))
export CLI_ARTIFACT_NAME:=dlsctl-$(CLI_ARTIFACT_VERSION_STRING)-linux.tar.gz
export CLI_ARTIFACT_PLATFORM:=linux
endif
ifeq (Darwin,$(OS))
export CLI_ARTIFACT_NAME:=dlsctl-$(CLI_ARTIFACT_VERSION_STRING)-darwin.tar.gz
export CLI_ARTIFACT_PLATFORM:=darwin
endif

pack-ipplan:
ifeq (Windows,$(OS))
	@cd $(CURDIR)/.. && 7z a -tzip ipplan-$(CLI_ARTIFACT_NAME) ./cli/*
endif
ifeq (Linux,$(OS))
	@cd $(CURDIR)/.. && tar -zcf ipplan-$(CLI_ARTIFACT_NAME) -C cli .
endif
ifeq (Darwin,$(OS))
	@cd $(CURDIR)/.. && tar -zcf ipplan-$(CLI_ARTIFACT_NAME) -C cli .
endif

pack: build
ifeq (Windows,$(OS))
	@7z a -tzip $(CLI_ARTIFACT_NAME) ./dist/*
endif
ifeq (Linux,$(OS))
	@tar -zcf $(CLI_ARTIFACT_NAME) -C dist .
endif
ifeq (Darwin,$(OS))
	@tar -zcf $(CLI_ARTIFACT_NAME) -C dist .
endif

push: pack
ifeq (True,$(ENV_IPPLAN))
	@make pack-ipplan
endif
	@echo Upload artifacts to the releases directory
ifneq (Windows,$(OS))
	@cd $(CURDIR)/.. && make tools-push ENV_SRC=$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME) ENV_DEST=releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME)
else
	@echo aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME)" "s3://repository/releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME)"
	@aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME)" "s3://repository/releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME)"
endif

ifeq (True,$(ENV_IPPLAN))
	@echo Upload artifacts to the ipplan directory
ifneq (Windows,$(OS))
	@cd $(CURDIR)/.. && make tools-push ENV_SRC=$(CURDIR)/../ipplan-$(CLI_ARTIFACT_NAME) ENV_DEST=releases/ipplan/$(CLI_ARTIFACT_PLATFORM)/ipplan-$(CLI_ARTIFACT_NAME)
else
	@echo aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CURDIR)/../ipplan-$(CLI_ARTIFACT_NAME)" "s3://repository/releases/ipplan/$(CLI_ARTIFACT_PLATFORM)/ipplan-$(CLI_ARTIFACT_NAME)"
	@aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CURDIR)/../ipplan-$(CLI_ARTIFACT_NAME)" "s3://repository/releases/ipplan/$(CLI_ARTIFACT_PLATFORM)/ipplan-$(CLI_ARTIFACT_NAME)"
endif
endif

ifeq (True,$(ENV_CALCULATESUM))
	@echo Calculate file control sum and upload to the releases directory
ifeq (Linux,$(OS))
	sha256sum "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME)" > "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum"
	@cd $(CURDIR)/.. && make tools-push ENV_SRC=$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum ENV_DEST=releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME).sha256sum
endif
ifeq (Darwin,$(OS))
	shasum -a 256 "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME)" > "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum"
	@cd $(CURDIR)/.. && make tools-push ENV_SRC=$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum ENV_DEST=releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME).sha256sum
endif
ifeq (Windows,$(OS))
	powershell -Command "& { Get-FileHash -Algorithm SHA256 -Path $(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME) > $(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum }"
	@echo aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum" "s3://repository/releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME).sha256sum"
	@aws --endpoint-url $(ENV_S3_URL) s3 cp "$(CLI_ARTIFACT_DIRECTORY)/$(CLI_ARTIFACT_NAME).sha256sum" "s3://repository/releases/dlsctl/$(CLI_ARTIFACT_PLATFORM)/$(CLI_ARTIFACT_NAME).sha256sum"
endif
endif


VERSION_CLIENT_MAJOR ?= 1
VERSION_CLIENT_MINOR ?= 0
VERSION_CLIENT_NO ?= 0
BUILD_ID ?= dev
VERSION_CLIENT_BUMP_PART ?= patch

set-version:
	./set-version.sh "$(VERSION_CLIENT_MAJOR).$(VERSION_CLIENT_MINOR).$(VERSION_CLIENT_NO)-$(BUILD_ID)"

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Shortcut for mochitest* and xpcshell-tests targets,
# replaces 'EXTRA_TEST_ARGS=--test-path=...'.
ifdef TEST_PATH
TEST_PATH_ARG := --test-path=$(TEST_PATH)
PEPTEST_PATH_ARG := --test-path=$(TEST_PATH)
else
TEST_PATH_ARG :=
PEPTEST_PATH_ARG := --test-path=_tests/peptest/tests/firefox/firefox_all.ini
endif

# include automation-build.mk to get the path to the binary
TARGET_DEPTH = $(DEPTH)
include $(topsrcdir)/build/binary-location.mk

SYMBOLS_PATH := --symbols-path=$(DIST)/crashreporter-symbols

# Usage: |make [TEST_PATH=...] [EXTRA_TEST_ARGS=...] mochitest*|.
MOCHITESTS := mochitest-plain mochitest-chrome mochitest-a11y mochitest-ipcplugins
mochitest:: $(MOCHITESTS)

ifndef TEST_PACKAGE_NAME
TEST_PACKAGE_NAME := $(ANDROID_PACKAGE_NAME)
endif

RUN_MOCHITEST = \
  rm -f ./$@.log && \
  $(PYTHON) _tests/testing/mochitest/runtests.py --autorun --close-when-done \
    --console-level=INFO --log-file=./$@.log --file-level=INFO \
    --failure-file=$(call core_abspath,_tests/testing/mochitest/makefailures.json) \
    --testing-modules-dir=$(call core_abspath,_tests/modules) \
    $(SYMBOLS_PATH) $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

RERUN_MOCHITEST = \
  rm -f ./$@.log && \
  $(PYTHON) _tests/testing/mochitest/runtests.py --autorun --close-when-done \
    --console-level=INFO --log-file=./$@.log --file-level=INFO \
    --run-only-tests=makefailures.json \
    --testing-modules-dir=$(call core_abspath,_tests/modules) \
    $(SYMBOLS_PATH) $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

RUN_MOCHITEST_REMOTE = \
  rm -f ./$@.log && \
  $(PYTHON) _tests/testing/mochitest/runtestsremote.py --autorun --close-when-done \
    --console-level=INFO --log-file=./$@.log --file-level=INFO $(DM_FLAGS) --dm_trans=$(DM_TRANS) \
    --app=$(TEST_PACKAGE_NAME) --deviceIP=${TEST_DEVICE} --xre-path=${MOZ_HOST_BIN} \
    $(SYMBOLS_PATH) $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

RUN_MOCHITEST_ROBOTIUM = \
  rm -f ./$@.log && \
  $(PYTHON) _tests/testing/mochitest/runtestsremote.py --robocop-path=$(DEPTH)/dist \
    --robocop-ids=$(DEPTH)/build/mobile/robocop/fennec_ids.txt \
    --console-level=INFO --log-file=./$@.log --file-level=INFO $(DM_FLAGS) --dm_trans=$(DM_TRANS) \
    --app=$(TEST_PACKAGE_NAME) --deviceIP=${TEST_DEVICE} --xre-path=${MOZ_HOST_BIN} \
    --robocop=$(DEPTH)/build/mobile/robocop/robocop.ini $(SYMBOLS_PATH) $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

ifndef NO_FAIL_ON_TEST_ERRORS
define check_test_error_internal
  @errors=`grep "TEST-UNEXPECTED-" $@.log` ;\
  if test "$$errors" ; then \
	  echo "$@ failed:"; \
	  echo "$$errors"; \
          $(if $(1),echo $(1)) \
	  exit 1; \
  fi
endef
CHECK_TEST_ERROR = $(call check_test_error_internal)
CHECK_TEST_ERROR_RERUN = $(call check_test_error_internal,"To rerun your failures please run 'make $@-rerun-failures'")
endif

mochitest-remote: DM_TRANS?=adb
mochitest-remote:
	@if [ ! -f ${MOZ_HOST_BIN}/xpcshell ]; then \
        echo "please prepare your host with the environment variable MOZ_HOST_BIN"; \
    elif [ "${TEST_DEVICE}" = "" -a "$(DM_TRANS)" != "adb" ]; then \
        echo "please prepare your host with the environment variable TEST_DEVICE"; \
    else \
        $(RUN_MOCHITEST_REMOTE); \
    fi

mochitest-robotium: robotium-id-map
mochitest-robotium: DM_TRANS?=adb
mochitest-robotium:
	@if [ ! -f ${MOZ_HOST_BIN}/xpcshell ]; then \
        echo "please prepare your host with the environment variable MOZ_HOST_BIN"; \
    elif [ "${TEST_DEVICE}" = "" -a "$(DM_TRANS)" != "adb" ]; then \
        echo "please prepare your host with the environment variable TEST_DEVICE"; \
    else \
        $(RUN_MOCHITEST_ROBOTIUM); \
    fi

mochitest-plain:
	$(RUN_MOCHITEST)
	$(CHECK_TEST_ERROR_RERUN)

mochitest-plain-rerun-failures:
	$(RERUN_MOCHITEST)
	$(CHECK_TEST_ERROR_RERUN)

# Allow mochitest-1 ... mochitest-5 for developer ease
mochitest-1 mochitest-2 mochitest-3 mochitest-4 mochitest-5: mochitest-%:
	echo "mochitest: $* / 5"
	$(RUN_MOCHITEST) --chunk-by-dir=4 --total-chunks=5 --this-chunk=$*
	$(CHECK_TEST_ERROR)

mochitest-chrome:
	$(RUN_MOCHITEST) --chrome
	$(CHECK_TEST_ERROR)

mochitest-a11y:
	$(RUN_MOCHITEST) --a11y
	$(CHECK_TEST_ERROR)

mochitest-ipcplugins:
ifeq (Darwin,$(OS_ARCH))
ifeq (i386,$(TARGET_CPU))
	$(RUN_MOCHITEST) --setpref=dom.ipc.plugins.enabled.i386.test.plugin=false --test-path=dom/plugins/test
endif
ifeq (x86_64,$(TARGET_CPU))
	$(RUN_MOCHITEST) --setpref=dom.ipc.plugins.enabled.x86_64.test.plugin=false --test-path=dom/plugins/test
endif
ifeq (powerpc,$(TARGET_CPU))
	$(RUN_MOCHITEST) --setpref=dom.ipc.plugins.enabled.ppc.test.plugin=false --test-path=dom/plugins/test
endif
else
	$(RUN_MOCHITEST) --setpref=dom.ipc.plugins.enabled=false --test-path=dom/plugins/test
endif
	$(CHECK_TEST_ERROR)

ifeq ($(OS_ARCH),Darwin)
webapprt_stub_path = $(TARGET_DIST)/$(MOZ_MACBUNDLE_NAME)/Contents/MacOS/webapprt-stub$(BIN_SUFFIX)
endif
ifeq ($(OS_ARCH),WINNT)
webapprt_stub_path = $(TARGET_DIST)/bin/webapprt-stub$(BIN_SUFFIX)
endif
ifeq ($(MOZ_WIDGET_TOOLKIT),gtk2)
webapprt_stub_path = $(TARGET_DIST)/bin/webapprt-stub$(BIN_SUFFIX)
endif

ifdef webapprt_stub_path
webapprt-test-content:
	$(RUN_MOCHITEST) --webapprt-content --appname $(webapprt_stub_path)
	$(CHECK_TEST_ERROR)
webapprt-test-chrome:
	$(RUN_MOCHITEST) --webapprt-chrome --appname $(webapprt_stub_path) --browser-arg -test-mode
	$(CHECK_TEST_ERROR)
endif

# Usage: |make [EXTRA_TEST_ARGS=...] *test|.
RUN_REFTEST = rm -f ./$@.log && $(PYTHON) _tests/reftest/runreftest.py \
  $(SYMBOLS_PATH) $(EXTRA_TEST_ARGS) $(1) | tee ./$@.log

REMOTE_REFTEST = rm -f ./$@.log && $(PYTHON) _tests/reftest/remotereftest.py \
  --dm_trans=$(DM_TRANS) --ignore-window-size \
  --app=$(TEST_PACKAGE_NAME) --deviceIP=${TEST_DEVICE} --xre-path=${MOZ_HOST_BIN} \
  $(SYMBOLS_PATH) $(EXTRA_TEST_ARGS) $(1) | tee ./$@.log

RUN_REFTEST_B2G = rm -f ./$@.log && $(PYTHON) _tests/reftest/runreftestb2g.py \
  --remote-webserver=10.0.2.2 --b2gpath=${B2G_PATH} --adbpath=${ADB_PATH} \
  --xre-path=${MOZ_HOST_BIN} $(SYMBOLS_PATH) --ignore-window-size \
  $(EXTRA_TEST_ARGS) $(1) | tee ./$@.log

ifeq ($(OS_ARCH),WINNT) #{
# GPU-rendered shadow layers are unsupported here
OOP_CONTENT = --setpref=browser.tabs.remote=true --setpref=layers.acceleration.disabled=true
GPU_RENDERING =
else
OOP_CONTENT = --setpref=browser.tabs.remote=true
GPU_RENDERING = --setpref=layers.acceleration.force-enabled=true
endif #}

reftest: TEST_PATH?=layout/reftests/reftest.list
reftest:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH))
	$(CHECK_TEST_ERROR)

reftest-remote: TEST_PATH?=layout/reftests/reftest.list
reftest-remote: DM_TRANS?=adb
reftest-remote:
	@if [ ! -f ${MOZ_HOST_BIN}/xpcshell ]; then \
        echo "please prepare your host with the environment variable MOZ_HOST_BIN"; \
    elif [ "${TEST_DEVICE}" = "" -a "$(DM_TRANS)" != "adb" ]; then \
        echo "please prepare your host with the environment variable TEST_DEVICE"; \
    else \
        ln -s $(abspath $(topsrcdir)) _tests/reftest/tests; \
        $(call REMOTE_REFTEST,tests/$(TEST_PATH)); \
        $(CHECK_TEST_ERROR); \
    fi

reftest-b2g: TEST_PATH?=layout/reftests/reftest.list
reftest-b2g:
	@if [ ! -f ${MOZ_HOST_BIN}/xpcshell ]; then \
        echo "please set the MOZ_HOST_BIN environment variable"; \
	elif [ "${B2G_PATH}" = "" -o "${ADB_PATH}" = "" ]; then \
		echo "please set the B2G_PATH and ADB_PATH environment variables"; \
	else \
        ln -s $(abspath $(topsrcdir)) _tests/reftest/tests; \
		if [ "${REFTEST_PATH}" != "" ]; then \
			$(call RUN_REFTEST_B2G,tests/${REFTEST_PATH}); \
		else \
			$(call RUN_REFTEST_B2G,tests/$(TEST_PATH)); \
		fi; \
        $(CHECK_TEST_ERROR); \
	fi

reftest-ipc: TEST_PATH?=layout/reftests/reftest.list
reftest-ipc:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH) $(OOP_CONTENT))
	$(CHECK_TEST_ERROR)

reftest-ipc-gpu: TEST_PATH?=layout/reftests/reftest.list
reftest-ipc-gpu:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH) $(OOP_CONTENT) $(GPU_RENDERING))
	$(CHECK_TEST_ERROR)

crashtest: TEST_PATH?=testing/crashtest/crashtests.list
crashtest:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH))
	$(CHECK_TEST_ERROR)

crashtest-ipc: TEST_PATH?=testing/crashtest/crashtests.list
crashtest-ipc:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH) $(OOP_CONTENT))
	$(CHECK_TEST_ERROR)

crashtest-ipc-gpu: TEST_PATH?=testing/crashtest/crashtests.list
crashtest-ipc-gpu:
	$(call RUN_REFTEST,$(topsrcdir)/$(TEST_PATH) $(OOP_CONTENT) $(GPU_RENDERING))
	$(CHECK_TEST_ERROR)

jstestbrowser: TESTS_PATH?=test-package-stage/jsreftest/tests/
jstestbrowser:
	$(MAKE) -C $(DEPTH)/config
	$(MAKE) -C $(DEPTH)/js/src/config
	$(MAKE) stage-jstests
	$(call RUN_REFTEST,$(DIST)/$(TESTS_PATH)/jstests.list --extra-profile-file=$(DIST)/$(TESTS_PATH)/user.js)
	$(CHECK_TEST_ERROR)

GARBAGE += $(addsuffix .log,$(MOCHITESTS) reftest crashtest jstestbrowser)

# Execute all xpcshell tests in the directories listed in the manifest.
# See also config/rules.mk 'xpcshell-tests' target for local execution.
# Usage: |make [TEST_PATH=...] [EXTRA_TEST_ARGS=...] xpcshell-tests|.
xpcshell-tests:
	$(PYTHON) -u $(topsrcdir)/config/pythonpath.py \
	  -I$(topsrcdir)/build -I$(DEPTH)/_tests/mozbase/mozinfo \
	  $(topsrcdir)/testing/xpcshell/runxpcshelltests.py \
	  --manifest=$(DEPTH)/_tests/xpcshell/xpcshell.ini \
	  --build-info-json=$(DEPTH)/mozinfo.json \
	  --no-logfiles \
	  --tests-root-dir=$(call core_abspath,_tests/xpcshell) \
	  --testing-modules-dir=$(call core_abspath,_tests/modules) \
	  --xunit-file=$(call core_abspath,_tests/xpcshell/results.xml) \
	  --xunit-suite-name=xpcshell \
          $(SYMBOLS_PATH) \
	  $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS) \
	  $(LIBXUL_DIST)/bin/xpcshell

REMOTE_XPCSHELL = \
	rm -f ./$@.log && \
	$(PYTHON) -u $(topsrcdir)/config/pythonpath.py \
	  -I$(topsrcdir)/build \
	  $(topsrcdir)/testing/xpcshell/remotexpcshelltests.py \
	  --manifest=$(DEPTH)/_tests/xpcshell/xpcshell.ini \
	  --build-info-json=$(DEPTH)/mozinfo.json \
	  --no-logfiles \
	  --dm_trans=$(DM_TRANS) \
	  --deviceIP=${TEST_DEVICE} \
	  --objdir=$(DEPTH) \
	  $(SYMBOLS_PATH) \
	  $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

B2G_XPCSHELL = \
	rm -f ./@.log && \
	$(PYTHON) -u $(topsrcdir)/config/pythonpath.py \
	  -I$(topsrcdir)/build \
	  $(topsrcdir)/testing/xpcshell/runtestsb2g.py \
	  --manifest=$(DEPTH)/_tests/xpcshell/xpcshell.ini \
	  --build-info-json=$(DEPTH)/mozinfo.json \
	  --no-logfiles \
	  --use-device-libs \
	  --no-clean \
	  --objdir=$(DEPTH) \
	  $$EXTRA_XPCSHELL_ARGS \
	  --b2gpath=${B2G_HOME} \
	  $(TEST_PATH_ARG) $(EXTRA_TEST_ARGS)

xpcshell-tests-b2g: ADB_PATH?=$(shell which adb)
xpcshell-tests-b2g:
	@if [ "${B2G_HOME}" = "" ]; then \
		echo "Please set the B2G_HOME variable"; exit 1; \
	elif [ ! -f "${ADB_PATH}" ]; then \
		echo "Please set the ADB_PATH variable"; exit 1; \
	elif [ "${EMULATOR}" != "" ]; then \
		EXTRA_XPCSHELL_ARGS=--emulator=${EMULATOR}; \
		$(call B2G_XPCSHELL); \
		exit 0; \
	else \
		EXTRA_XPCSHELL_ARGS=--address=localhost:2828; \
		$(call B2G_XPCSHELL); \
		exit 0; \
	fi

xpcshell-tests-remote: DM_TRANS?=adb
xpcshell-tests-remote:
	@if [ "${TEST_DEVICE}" != "" -o "$(DM_TRANS)" = "adb" ]; \
          then $(call REMOTE_XPCSHELL); $(CHECK_TEST_ERROR); \
        else \
          echo "please prepare your host with environment variables for TEST_DEVICE"; \
        fi

# Runs peptest, for usage see: https://developer.mozilla.org/en/Peptest#Running_Tests
RUN_PEPTEST = \
	rm -f ./$@.log && \
	$(PYTHON) _tests/peptest/runtests.py --binary=$(browser_path) \
          $(PEPTEST_PATH_ARG) \
	  --proxy=_tests/peptest/tests/firefox/server-locations.txt \
          --proxy-host-dirs \
          --server-path=_tests/peptest/tests/firefox/server \
          --log-file=./$@.log $(SYMBOLS_PATH) $(EXTRA_TEST_ARGS)

peptest:
	$(RUN_PEPTEST)
	$(CHECK_TEST_ERROR)

# Package up the tests and test harnesses
include $(topsrcdir)/toolkit/mozapps/installer/package-name.mk

ifndef UNIVERSAL_BINARY
PKG_STAGE = $(DIST)/test-package-stage
package-tests: \
  stage-config \
  stage-mochitest \
  stage-reftest \
  stage-xpcshell \
  stage-jstests \
  stage-jetpack \
  stage-peptest \
  stage-mozbase \
  stage-tps \
  stage-modules \
  stage-marionette \
  $(NULL)
else
# This staging area has been built for us by universal/flight.mk
PKG_STAGE = $(DIST)/universal/test-package-stage
endif

package-tests:
	@rm -f "$(DIST)/$(PKG_PATH)$(TEST_PACKAGE)"
ifndef UNIVERSAL_BINARY
	$(NSINSTALL) -D $(DIST)/$(PKG_PATH)
else
	#building tests.jar (bug 543800) fails on unify, so we build tests.jar after unify is run
	$(MAKE) -C $(DEPTH)/testing/mochitest stage-chromejar PKG_STAGE=$(DIST)/universal
endif
	find $(PKG_STAGE) -name "*.pyc" -exec rm {} \;
	cd $(PKG_STAGE) && \
	  zip -rq9D "$(call core_abspath,$(DIST)/$(PKG_PATH)$(TEST_PACKAGE))" \
	  * -x \*/.mkdir.done

ifeq ($(MOZ_WIDGET_TOOLKIT),android)
package-tests: stage-android
endif

ifeq ($(MOZ_WIDGET_TOOLKIT),gonk)
package-tests: stage-b2g
endif

make-stage-dir:
	rm -rf $(PKG_STAGE)
	$(NSINSTALL) -D $(PKG_STAGE)
	$(NSINSTALL) -D $(PKG_STAGE)/bin
	$(NSINSTALL) -D $(PKG_STAGE)/bin/components
	$(NSINSTALL) -D $(PKG_STAGE)/certs
	$(NSINSTALL) -D $(PKG_STAGE)/config
	$(NSINSTALL) -D $(PKG_STAGE)/jetpack
	$(NSINSTALL) -D $(PKG_STAGE)/peptest
	$(NSINSTALL) -D $(PKG_STAGE)/mozbase
	$(NSINSTALL) -D $(PKG_STAGE)/modules

stage-b2g: make-stage-dir
	$(NSINSTALL) $(topsrcdir)/b2g/test/b2g-unittest-requirements.txt $(PKG_STAGE)/b2g

stage-config: make-stage-dir
	$(MAKE) -C $(DEPTH)/testing/config stage-package

robotium-id-map:
ifeq ($(MOZ_BUILD_APP),mobile/android)
	$(PYTHON) $(DEPTH)/build/mobile/robocop/parse_ids.py -i $(DEPTH)/mobile/android/base/R.java -o $(DEPTH)/build/mobile/robocop/fennec_ids.txt
endif

stage-mochitest: robotium-id-map
stage-mochitest: make-stage-dir
	$(MAKE) -C $(DEPTH)/testing/mochitest stage-package
ifeq ($(MOZ_BUILD_APP),mobile/android)
	$(NSINSTALL) $(DEPTH)/build/mobile/robocop/fennec_ids.txt $(PKG_STAGE)/mochitest
endif

stage-reftest: make-stage-dir
	$(MAKE) -C $(DEPTH)/layout/tools/reftest stage-package

stage-xpcshell: make-stage-dir
	$(MAKE) -C $(DEPTH)/testing/xpcshell stage-package

stage-jstests: make-stage-dir
	$(MAKE) -C $(DEPTH)/js/src/tests stage-package

stage-android: make-stage-dir
	$(NSINSTALL) $(DEPTH)/build/mobile/sutagent/android/sutAgentAndroid.apk $(PKG_STAGE)/bin
	$(NSINSTALL) $(DEPTH)/build/mobile/sutagent/android/watcher/Watcher.apk $(PKG_STAGE)/bin
	$(NSINSTALL) $(DEPTH)/build/mobile/sutagent/android/fencp/FenCP.apk $(PKG_STAGE)/bin
	$(NSINSTALL) $(DEPTH)/build/mobile/sutagent/android/ffxcp/FfxCP.apk $(PKG_STAGE)/bin

stage-jetpack: make-stage-dir
	$(NSINSTALL) $(topsrcdir)/testing/jetpack/jetpack-location.txt $(PKG_STAGE)/jetpack

stage-peptest: make-stage-dir
	$(MAKE) -C $(DEPTH)/testing/peptest stage-package

stage-tps: make-stage-dir
	$(NSINSTALL) -D $(PKG_STAGE)/tps/tests
	@(cd $(topsrcdir)/testing/tps && tar $(TAR_CREATE_FLAGS) - *) | (cd $(PKG_STAGE)/tps && tar -xf -)
	@(cd $(topsrcdir)/services/sync/tps && tar $(TAR_CREATE_FLAGS) - *) | (cd $(PKG_STAGE)/tps && tar -xf -)
	(cd $(topsrcdir)/services/sync/tests/tps && tar $(TAR_CREATE_FLAGS_QUIET) - *) | (cd $(PKG_STAGE)/tps/tests && tar -xf -)

stage-modules: make-stage-dir
	$(NSINSTALL) -D $(PKG_STAGE)/modules
	cp -RL $(DEPTH)/_tests/modules $(PKG_STAGE)

MARIONETTE_DIR=$(PKG_STAGE)/marionette
stage-marionette: make-stage-dir
	$(NSINSTALL) -D $(MARIONETTE_DIR)/tests
	@(cd $(topsrcdir)/testing/marionette/client && tar --exclude marionette/tests $(TAR_CREATE_FLAGS) - *) | (cd $(MARIONETTE_DIR) && tar -xf -)
	$(PYTHON) $(topsrcdir)/testing/marionette/client/marionette/tests/print-manifest-dirs.py \
          $(topsrcdir) \
          $(topsrcdir)/testing/marionette/client/marionette/tests/unit-tests.ini \
          | (cd $(topsrcdir) && xargs tar $(TAR_CREATE_FLAGS_QUIET) -) \
          | (cd $(MARIONETTE_DIR)/tests && tar -xf -)

stage-mozbase: make-stage-dir
	$(MAKE) -C $(DEPTH)/testing/mozbase stage-package
.PHONY: \
  mochitest \
  mochitest-plain \
  mochitest-chrome \
  mochitest-a11y \
  mochitest-ipcplugins \
  reftest \
  crashtest \
  xpcshell-tests \
  jstestbrowser \
  peptest \
  package-tests \
  make-stage-dir \
  stage-b2g \
  stage-config \
  stage-mochitest \
  stage-reftest \
  stage-xpcshell \
  stage-jstests \
  stage-android \
  stage-jetpack \
  stage-peptest \
  stage-mozbase \
  stage-tps \
  stage-modules \
  stage-marionette \
  $(NULL)

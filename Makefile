mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
curr_dir := $(patsubst %/,%,$(dir $(mkfile_path)))
sde := /home/ubuntu/mysde/bf-sde-9.7.0

include util/docker/Makefile.vars

onos_url := http://localhost:8181/onos
onos_curl := curl --fail -sSL --user onos:rocks --noproxy localhost
app_name := org.onosproject.ngsdn-tutorial

NGSDN_TUTORIAL_SUDO ?=

default:
	$(error Please specify a make target (see README.md))

_docker_pull_all:
	docker pull ${ONOS_IMG}@${ONOS_SHA}
	docker tag ${ONOS_IMG}@${ONOS_SHA} ${ONOS_IMG}
	docker pull ${P4RT_SH_IMG}@${P4RT_SH_SHA}
	docker tag ${P4RT_SH_IMG}@${P4RT_SH_SHA} ${P4RT_SH_IMG}
	docker pull ${P4C_IMG}@${P4C_SHA}
	docker tag ${P4C_IMG}@${P4C_SHA} ${P4C_IMG}
	docker pull ${STRATUM_BMV2_IMG}@${STRATUM_BMV2_SHA}
	docker tag ${STRATUM_BMV2_IMG}@${STRATUM_BMV2_SHA} ${STRATUM_BMV2_IMG}
	docker pull ${MVN_IMG}@${MVN_SHA}
	docker tag ${MVN_IMG}@${MVN_SHA} ${MVN_IMG}
	docker pull ${GNMI_CLI_IMG}@${GNMI_CLI_SHA}
	docker tag ${GNMI_CLI_IMG}@${GNMI_CLI_SHA} ${GNMI_CLI_IMG}
	docker pull ${YANG_IMG}@${YANG_SHA}
	docker tag ${YANG_IMG}@${YANG_SHA} ${YANG_IMG}
	docker pull ${SSHPASS_IMG}@${SSHPASS_SHA}
	docker tag ${SSHPASS_IMG}@${SSHPASS_SHA} ${SSHPASS_IMG}
	docker pull ${TOFINO_IMG}
	docker tag ${TOFINO_IMG} ${TOFINO_IMG}

deps: _docker_pull_all

_start:
	$(info *** Starting ONOS and Mininet (${NGSDN_TOPO_PY})... )
	@mkdir -p tmp/onos
	@NGSDN_TOPO_PY=${NGSDN_TOPO_PY} sde=${sde} docker-compose up -d

start: NGSDN_TOPO_PY := topo-v6.py
start: _start
start: _run-tofino

stop:
	$(info *** Stopping ONOS and Mininet...)
	docker exec -it mininet mn -c
	docker exec -it tofino ${sde}/install/bin/veth_teardown.sh
	@NGSDN_TOPO_PY=foo sde=${sde} docker-compose down -t0 --remove-orphans

restart: reset start

onos-cli:
	$(info *** Connecting to the ONOS CLI... password: rocks)
	$(info *** Top exit press Ctrl-D)
	@ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o LogLevel=ERROR -p 8101 onos@localhost

onos-log:
	docker-compose logs -f onos

onos-ui:
	open ${onos_url}/ui

mn-cli:
	$(info *** Attaching to Mininet CLI...)
	$(info *** To detach press Ctrl-D (Mininet will keep running))
	-@docker attach --detach-keys "ctrl-d" $(shell docker-compose ps -q mininet) || echo "*** Detached from Mininet CLI"

mn-log:
	docker logs -f mininet

tofino-log:
	$(info *** Attaching to Tofino Log...)
	$(info *** Press Ctrl-C to exit (Tofino will keep running))
	#-@docker attach --detach-keys "ctrl-d" $(shell docker-compose ps -q tofino) || echo "*** Detached from Tofino Bash"
	docker-compose logs -f tofino

tofino-cli:
	$(info *** Running Tofino Shell...)
	$(info *** Type exit to exit)
	@docker exec -it tofino ${sde}/run_bfshell.sh

tofino-bash:
	$(info *** Running Tofino Bash...)
	$(info *** Type exit to exit)
	@docker exec -it tofino /bin/bash

_run-tofino:
	$(info *** Running tofino switch...)
	@docker exec -d tofino ${sde}/run_switchd.sh -p switch

_netcfg:
	$(info *** Pushing ${NGSDN_NETCFG_JSON} to ONOS...)
	${onos_curl} -X POST -H 'Content-Type:application/json' \
		${onos_url}/v1/network/configuration -d@./mininet/${NGSDN_NETCFG_JSON}
	@echo

netcfg: NGSDN_NETCFG_JSON := netcfg-tofino.json
netcfg: _netcfg

brcfg:
	$(info *** Configuring bridge interfaces...)
	@sh ./util/brcfg.sh

flowrule-clean:
	$(info *** Removing all flows installed via REST APIs...)
	${onos_curl} -X DELETE -H 'Content-Type:application/json' \
		${onos_url}/v1/flows/application/rest-api
	@echo

reset: stop
	-$(NGSDN_TUTORIAL_SUDO) rm -rf ./tmp

clean:
	-$(NGSDN_TUTORIAL_SUDO) rm -rf p4src/build
	-$(NGSDN_TUTORIAL_SUDO) rm -rf app/target
	-$(NGSDN_TUTORIAL_SUDO) rm -rf app/src/main/resources/bmv2.json
	-$(NGSDN_TUTORIAL_SUDO) rm -rf app/src/main/resources/p4info.txt

p4-build: p4src/main.p4
	$(info *** Building P4 program...)
	@mkdir -p p4src/build
	docker run --rm -v ${curr_dir}:/workdir -w /workdir ${P4C_IMG} \
		p4c-bm2-ss --arch v1model -o p4src/build/bmv2.json \
		--p4runtime-files p4src/build/p4info.txt --Wdisable=unsupported \
		p4src/main.p4
	@echo "*** P4 program compiled successfully! Output files are in p4src/build"

p4-tofino-build: # not necessary
	$(info *** Building Tofino P4 program...)
	docker run --rm -v ${curr_dir}/tofino:/tofino -w /home/ubuntu/mysde ${TOFINO_IMG} \
		/bin/bash -c "cmake ${sde}/p4studio -DCMAKE_INSTALL_PREFIX=${sde}/install -DCMAKE_MODULE_PATH=${sde}/cmake -DP4_NAME=switch -DP4_PATH=/tofino/switch.p4; \
		make switch && make install; cp -r switch /tofino"

p4-test:
	@cd ptf && PTF_DOCKER_IMG=$(STRATUM_BMV2_IMG) ./run_tests $(TEST)

_copy_p4c_out:
	$(info *** Copying p4c outputs to app resources...)
	@mkdir -p app/src/main/resources
	cp -f p4src/build/p4info.txt app/src/main/resources/
	cp -f p4src/build/bmv2.json app/src/main/resources/

_mvn_package:
	$(info *** Building ONOS app...)
	@mkdir -p app/target
	@docker run --rm -v ${curr_dir}/app:/mvn-src -w /mvn-src ${MVN_IMG} mvn -o clean package

app-build: p4-build _copy_p4c_out _mvn_package
	$(info *** ONOS app .oar package created succesfully)
	@ls -1 app/target/*.oar

app-install:
	$(info *** Installing and activating app in ONOS...)
	${onos_curl} -X POST -HContent-Type:application/octet-stream \
		'${onos_url}/v1/applications?activate=true' \
		--data-binary @app/target/ngsdn-tutorial-1.0-SNAPSHOT.oar
	@echo

app-uninstall:
	$(info *** Uninstalling app from ONOS (if present)...)
	-${onos_curl} -X DELETE ${onos_url}/v1/applications/${app_name}
	@echo

app-reload: app-uninstall app-install

solution-apply:
	mkdir working_copy
	cp -r app working_copy/app
	cp -r p4src working_copy/p4src
	cp -r ptf working_copy/ptf
	cp -r mininet working_copy/mininet
	rsync -r solution/ ./

solution-revert:
	test -d working_copy
	$(NGSDN_TUTORIAL_SUDO) rm -rf ./app/*
	$(NGSDN_TUTORIAL_SUDO) rm -rf ./p4src/*
	$(NGSDN_TUTORIAL_SUDO) rm -rf ./ptf/*
	$(NGSDN_TUTORIAL_SUDO) rm -rf ./mininet/*
	cp -r working_copy/* ./
	$(NGSDN_TUTORIAL_SUDO) rm -rf working_copy/

check:
	make reset
	# P4 starter code and app should compile
	make app-build
	# Run containers
	make start
	sleep 40
	make app-reload
	sleep 5
	make netcfg
	sleep 5
	# The first ping(s) might fail because of a known race condition in Ipv6SimpleRoutingComponent
	-util/mn-cmd h1 ping -c 1 2001:1:1::2
	-util/mn-cmd h2 ping -c 1 2001:1:1::1
	# Reload app
	make app-reload
	-util/mn-cmd h1 ip -6 neigh replace 2001:1:1::2 lladdr 00:00:00:00:00:20 dev h1-eth0
	-util/mn-cmd h2 ip -6 neigh replace 2001:1:1::1 lladdr 00:00:00:00:00:10 dev h2-eth0
	-util/mn-cmd h1 ping -c 1 2001:1:1::2
	-util/mn-cmd h2 ping -c 1 2001:1:1::1
	# P4Simtool is ready
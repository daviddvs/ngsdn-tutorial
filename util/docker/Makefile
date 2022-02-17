include Makefile.vars

build: build-stratum_bmv2 build-mvn build-tofino
push: push-stratum_bmv2 push-mvn

build-stratum_bmv2:
	cd stratum_bmv2 && docker build -t ${STRATUM_BMV2_IMG} .

build-mvn:
	cd ../../app && docker build --squash -f ../util/docker/mvn/Dockerfile \
		-t ${MVN_IMG} .

build-tofino:
	#cd tofino && wget -nc ${UBUNTU_IMG_URL} && docker build -f ./Dockerfile -t ${TOFINO_IMG} .
	cd tofino && docker build -f ./Dockerfile -t ${TOFINO_IMG} .

push-stratum_bmv2:
	# Remember to update Makefile.vars with the new image sha
	docker push ${STRATUM_BMV2_IMG}

push-mvn:
	# Remember to update Makefile.vars with the new image sha
	docker push ${MVN_IMG}

push-tofino:
	# Remember to update Makefile.vars with the new image sha
	docker push daviddvs/p4simtool:tofino
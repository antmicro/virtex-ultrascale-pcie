IP_ADDR ?= 10.0.0.2
LOGIN ?= antmicro
HOST := $(LOGIN)@$(IP_ADDR)
VIRTUALENV_DIR ?= venv
BOARD ?= profpga_xcvu19p

LITEX_MODULES = migen litex litedram litex-boards litepcie

default: all

### GENERAL TARGETS ###
all: build host/reload

build: gateware/build software/build host/reload

load: host/reload

clean: gateware/clean software/clean

### VIRTUALENV ###
venv/create:
	python3 -m venv $(VIRTUALENV_DIR)

venv/install:
	for module in $(LITEX_MODULES); do \
		pushd $$module; \
		python setup.py develop; \
		popd; \
	done

venv/clean:
	rm -rf $(VIRTUALENV_DIR)


### GATEWARE ###
build/profpga_xcvu19p/gateware/profpga_xcvu19p.bit:
	./litepcie/examples/profpga_xcvu19p.py --build --driver --speed gen3 --nlanes 8

build/xcu1525/gateware/xcu1525.bit:
	./litepcie/examples/xcu1525.py --build --driver --speed gen3 --nlanes 16

gateware/build: build/$(BOARD)/gateware/$(BOARD).bit

gateware/clean:
	rm -rf build

### KERNEL MODULE ###
software.tar.gz: build/$(BOARD)/driver
	tar czf $@ software

software/copy: software.tar.gz
	scp $< $(HOST):/home/$(LOGIN)

software/extract: software/copy
	ssh $(HOST) "tar --overwrite -xzf software.tar.gz"

software/build: software/extract
	ssh $(HOST) -t "cd build/$(BOARD)/driver/kernel; make; sudo cp litepcie.ko /lib/modules/\`uname -r\`"
	ssh $(HOST) -t "cd build/$(BOARD)/driver/user; make"

software/clean:
	rm -f software.tar.gz
	ssh $(HOST) "sudo rm /lib/modules/\`uname -r\`/litepcie.ko"
	ssh $(HOST) "rm -rf software software.tar.gz"


### HOST COMMANDS ###
host/reload:
	ssh $(HOST) "sudo modprobe -r litepcie"
	ssh $(HOST) "echo 1 | sudo tee /sys/bus/pci/devices/0000\:02\:00.0/remove"
	ssh $(HOST) "echo 1 | sudo tee /sys/bus/pci/rescan"

host/rmmod:
	ssh $(HOST) "sudo rmmod -f litepcie"

host/test:
	ssh $(HOST) "cd build/$(BOARD)/driver/user; sudo ./litepcie_util dma_test"

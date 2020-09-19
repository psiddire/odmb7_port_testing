# ODMB7 Development

This repository can be used for porting parts of the ODMB7 firmware from the ODMB and for testing it in simulation and on the KCU105 evaluation board. 

## Structure

### ODMB firmware
The top module of ODMB firmware is contained in the interface [odmb7_ucsb_dev.vhd](/source/odmb7_ucsb_dev.vhd), which then manages signals and sends them to
appropriate submodules as they are ported. 


#### Constraints

#### IP cores

Hold the IP core configs `*.xci` files used in the ODMB7 config. The one used for KCU test will be under the `testbench` folder.

#### Generator scripts
The Tcl scripts are holded in the `scripts` folder, make sure to `cd` into the `scripts` folder before sourcing them.
- `project_generator.tcl`: sourced to generate the project in the `project` folder. 
   Sourcing of the `ip_generator.tcl` is optional (default off) depending on if the IP configs existed or not.
- `ip_generator.tcl`: generate the IP cores and their configs used in the ODMB7 firmware.


#### Porting guidelines
- The naming of the signals in the top module should follow the signal names connected to the FPGA in the schematic as much as possible, except when they shall be
  improved to give more clarity  (e.g. `C_TDO` --> `DCFEB_TDO`, `DONE` --> `DCFEB_DONE`), in such case, the real signal name shall be attached as comment.

- The position of the pin (which Bank it is connected to) shall be attached as comment in the entity declaration.

- Try to assign every connected signal a corresponding signal in the entity declaration, even if they are unused for now (just to keep the record).

### Testbench
The top-level testbench file is [Firmware_tb.vhd](testbench/source/Firmware_tb.vhd). This will contain the ODMB firmware, the simulated VME, DCFEBs, and possibly
other devices in the future. LUTs are used to provide VME commands to the ODMB, and its eventual response is given to an ILA. 

Currently it is optimized for KCU tests.


## Progress

- [ ] Port ODMB_VME 
  - [X] COMMAND_MODULE
  - [ ] Device 0: TESTCTRL
  - [X] Device 1: CFEBJTAG
    - [X] Import VME simulation
    - [X] Import DCFEB simulation (only user code reading)
  - [ ] Device 2: ODMBJTAG
  - [ ] Device 3: VMEMON
  - [ ] Device 4: VMECONFREGS
  - [ ] Device 5: TESTFIFOS
  - [ ] Device 6: BPI_PORT
  - [ ] Device 7: SYSTEM_MON
  - [ ] Device 8: LVDBMON
  - [ ] Device 9: SYSTEM_TEST

- [ ] Constraints
  - [X] Pinouts for the VME and DCFEB


- [ ] Preproduction test specific
  - [ ] Adding IBERT Test


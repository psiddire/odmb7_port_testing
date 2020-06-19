# ODMB7 Development

This repository can be used for porting parts of the ODMB7 firmware from the ODMB and for testing it on the KCU105 evaluation board. 

## Structure

The top-level testbench file is [TestBench_odmb7/source/Firmware_tb.vhd](Firmware_tb.vhd). This will contain the ODMB firmware, the simulated VME, DCFEBs, and possibly other devices in the future. LUTs are used to provide VME commands to the ODMB, and its eventual response is given to an ILA.

The ODMB firmware is contained in the interface [TestBench_odmb7/source/odmb/odmb7_ucsb_dev.vhd](odmb7_ucsb_dev.vhd), which then manages signals and sends them to appropriate submodules as they are ported.


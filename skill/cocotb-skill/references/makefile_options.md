# Makefile Options Reference

## Core Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SIM` | Simulator to use | `icarus`, `verilator`, `questa`, `vcs` |
| `TOPLEVEL_LANG` | HDL language | `verilog`, `vhdl` |
| `TOPLEVEL` | Top-level module name | `my_module` |
| `MODULE` | Python test module | `TB`, `test_module` |

## Source Files

```makefile
# Verilog sources
VERILOG_SOURCES += $(PWD)/../path/to/module.v
VERILOG_SOURCES += $(PWD)/../path/to/submodule.v

# VHDL sources
VHDL_SOURCES += $(PWD)/../path/to/entity.vhd
```

## Build Options

```makefile
# Waveform generation
WAVES = 1

# Additional simulator arguments
EXTRA_ARGS = -Wall

# Custom include paths
VHDL_ARGS = -i/path/to/includes
```

## Simulator-Specific Notes

### Icarus Verilog (icarus)
```makefile
SIM ?= icarus
# No extra setup needed
```

### Verilator
```makefile
SIM ?= verilator
# Generates C++ models, faster simulation
# Requires CXX compiler
```

### Questa/ModelSim
```makefile
SIM ?= questa
# Commercial simulator
# Requires license
```

## Running Tests

```bash
# Default simulator
make

# Specific simulator
make SIM=verilator

# Run specific test
make TESTCASE=test_name

# Clean build
make clean
```
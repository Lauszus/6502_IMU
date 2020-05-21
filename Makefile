# We only got one source file.
SOURCE = src/main.s

# Build directory.
BUILD_DIR ?= build

# The object that will be built.
OBJ = $(addprefix $(BUILD_DIR)/,$(SOURCE:.s=.o))

# Explicitly tell Make about the targets.
.PHONY: all clean flash

# Rebuild all objects when the Makefile changes.
$(OBJ): Makefile

# The default rule, which causes the project to be built.
all: $(OBJ)

# The rule to clean out all the build products.
clean:
	@rm -rf $(BUILD_DIR)

# The rule for flashing the application to the EEPROM.
flash: all
	@minipro -p AT28C256 -w $(OBJ)

# The rule for building the object files from each source file.
$(OBJ): $(BUILD_DIR)/%.o : %.s
	@mkdir -p $(@D)
	@vasm6502_oldstyle -Fbin -dotdir -wdc02 $(<) -o $(@)

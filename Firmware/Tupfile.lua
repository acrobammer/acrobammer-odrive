
tup.include('build.lua')

-- Switch between board versions
boardversion = tup.getconfig("BOARD_VERSION")
if boardversion == "" then boardversion = "v3.4" end
if boardversion == "v3.1" then
    boarddir = 'Board/v3.3' -- currently all platform code is in the same v3.3 directory
    FLAGS += "-DHW_VERSION_MAJOR=3 -DHW_VERSION_MINOR=1"
elseif boardversion == "v3.2" then
    boarddir = 'Board/v3.3'
    FLAGS += "-DHW_VERSION_MAJOR=3 -DHW_VERSION_MINOR=2"
elseif boardversion == "v3.3" then
    boarddir = 'Board/v3.3'
    FLAGS += "-DHW_VERSION_MAJOR=3 -DHW_VERSION_MINOR=3"
elseif boardversion == "v3.4" then
    boarddir = 'Board/v3.3'
    FLAGS += "-DHW_VERSION_MAJOR=3 -DHW_VERSION_MINOR=4"
else
    error("unknown board version "..boardversion)
end
buildsuffix = boardversion

-- 48V voltage version
if tup.getconfig("48V") == "y" then
    FLAGS += "-DHW_VERSION_HIGH_VOLTAGE=true"
else
    FLAGS += "-DHW_VERSION_HIGH_VOLTAGE=false"
end

-- USB I/O settings
if tup.getconfig("USB_PROTOCOL") == "native" or tup.getconfig("USB_PROTOCOL") == "" then
    FLAGS += "-DUSB_PROTOCOL_NATIVE"
elseif tup.getconfig("USB_PROTOCOL") == "native-stream" then
    FLAGS += "-DUSB_PROTOCOL_NATIVE_STREAM_BASED"
elseif tup.getconfig("USB_PROTOCOL") == "ascii" then
    FLAGS += "-DUSB_PROTOCOL_LEGACY"
elseif tup.getconfig("USB_PROTOCOL") == "none" then
    FLAGS += "-DUSB_PROTOCOL_NONE"
else
    error("unknown USB protocol")
end

-- UART I/O settings
if tup.getconfig("UART_PROTOCOL") == "native" then
    FLAGS += "-DUART_PROTOCOL_NATIVE"
elseif tup.getconfig("UART_PROTOCOL") == "ascii" or tup.getconfig("UART_PROTOCOL") == "" then
    FLAGS += "-DUART_PROTOCOL_LEGACY"
elseif tup.getconfig("UART_PROTOCOL") == "none" then
    FLAGS += "-DUART_PROTOCOL_NONE"
else
    error("unknown UART protocol "..tup.getconfig("UART_PROTOCOL"))
end

-- GPIO settings
if tup.getconfig("STEP_DIR") == "y" then
    if tup.getconfig("UART_PROTOCOL") != "none" then
        FLAGS += "-DUSE_GPIO_MODE_STEP_DIR"
    else
        error("Step/dir mode conflicts with UART. Set CONFIG_UART_PROTOCOL to none.")
    end
end


-- C-specific flags
FLAGS += '-D__weak="__attribute__((weak))"'
FLAGS += '-D__packed="__attribute__((__packed__))"'
FLAGS += '-DUSE_HAL_DRIVER'
FLAGS += '-DSTM32F405xx'

FLAGS += '-mthumb'
FLAGS += '-mcpu=cortex-m4'
FLAGS += '-mfpu=fpv4-sp-d16'
FLAGS += '-mfloat-abi=hard'
FLAGS += { '-Wall', '-fdata-sections', '-ffunction-sections'}

FLAGS += '-g -gdwarf-2'


-- linker flags
LDFLAGS += '-T'..boarddir..'/STM32F405RGTx_FLASH.ld'
LDFLAGS += '-L'..boarddir..'/Drivers/CMSIS/Lib' -- lib dir
LDFLAGS += '-lc -lm -lnosys -larm_cortexM4lf_math' -- libs
LDFLAGS += '-mthumb -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard -specs=nosys.specs -specs=nano.specs -u _printf_float -u _scanf_float -Wl,--cref -Wl,--gc-sections'


-- common flags for ASM, C and C++
OPT += '-Og'
OPT += '-ffast-math'
tup.append_table(FLAGS, OPT)
tup.append_table(LDFLAGS, OPT)

toolchain = GCCToolchain('arm-none-eabi-', 'build', FLAGS, LDFLAGS)


-- Load list of source files Makefile that was autogenerated by CubeMX
vars = parse_makefile_vars(boarddir..'/Makefile')
all_stm_sources = (vars['C_SOURCES'] or '')..' '..(vars['CPP_SOURCES'] or '')..' '..(vars['ASM_SOURCES'] or '')
for src in string.gmatch(all_stm_sources, "%S+") do
    stm_sources += boarddir..'/'..src
end
for src in string.gmatch(vars['C_INCLUDES'] or '', "%S+") do
    stm_includes += boarddir..'/'..string.sub(src, 3, -1) -- remove "-I" from each include path
end

-- TODO: cleaner separation of the platform code and the rest
stm_includes += 'MotorControl'
stm_includes += 'Drivers/DRV8301'
build{
    name='stm_platform',
    type='objects',
    toolchains={toolchain},
    packages={},
    sources=stm_sources,
    includes=stm_includes
}

build{
    name='ODriveFirmware',
    toolchains={toolchain},
    --toolchains={LLVMToolchain('x86_64', {'-Ofast'}, {'-flto'})},
    packages={'stm_platform'},
    sources={
        'Drivers/DRV8301/drv8301.c',
        'MotorControl/utils.c',
        'MotorControl/legacy_commands.c',
        'MotorControl/low_level.c',
        'MotorControl/nvm.c',
        'MotorControl/axis.cpp',
        'MotorControl/commands.cpp',
        'MotorControl/protocol.cpp',
        'MotorControl/config.cpp'
    },
    includes={
        'Drivers/DRV8301',
        'MotorControl'
    }
}

#
# Copyright (C) 2024 Xiaomi Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# reset environment
deactivate() {
    # reset path
    if [ -n "${VELA_ORIGINAL_PATH:-}" ]; then
        PATH="${VELA_ORIGINAL_PATH:-}"
        export PATH
        unset VELA_ORIGINAL_PATH
    fi
    # rset prompt
    if [ -n "${VELA_ORIGINAL_PS1:-}" ]; then
        PS1="${VELA_ORIGINAL_PS1:-}"
        export PS1
        unset VELA_ORIGINAL_PS1
    fi
    # reset build variables
    unset VELA_BUILD_TARGET_VENDOR
    unset VELA_BUILD_TARGET_BOARD
    unset VELA_BUILD_TARGET_CONFIG
    if [ ! "${1:-}" = "nondestructive" ]; then
        # reset nuttx custom name null
        if [[ "${NUTTX_DIR_NAME}" == "nuttx" ]]; then
            unset NUTTX_DIR_NAME
        fi
        # Self destruct!
        unset -f deactivate
    fi
}

# Help prompt
function hmm() {
    cat <<EOF

Invoke "source build/envsetup.sh" from your shell to add the following functions to your environment:
- lunch:      lunch [vendor]-[board]-[config]
              and stores those selections in the environment to be read by subsequent
              invocations of 'm' etc.
- croot:      Changes directory to the top of the tree, or a subdirectory thereof.
- m:          Makes from the top of the tree.
- mm:         Builds and installs all library targets.
- mmm:        Builds current directory's library targets.
- make:       Alias for 'm' if there is no Makefile.
- cgrep:      Greps on all local C/C++ files.
- kgrep:      Greps on all local Kconfig files.
- mgrep:      Greps on all local Makefiles and CMake files.
- godir:      Go to the directory containing a file.

Environment options:
- VELA_CMAKE_GENERATOR: Default is -GNinja
- VELA_EXTRA_FLAGS: Default is -Wno-cpp

EOF
}

# check environment override nuttx name
if [ -z "${NUTTX_DIR_NAME}" ]; then
    export NUTTX_DIR_NAME="nuttx"
fi

function gettop {
    local TOPFILE=$NUTTX_DIR_NAME/tools/Unix.mk
    # The ${TOP-} expansion allows this to work even with set -u
    if [ -n "${TOP:-}" -a -f "${TOP:-}/$TOPFILE" ]; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (
            cd "$TOP"
            PWD= /bin/pwd
        )
    else
        if [ -f $TOPFILE ]; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            local T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( "$PWD" != "/" \) ]; do
                \cd ..
                T=$(PWD= /bin/pwd -P)
            done
            \cd "$HERE"
            if [ -f "$T/$TOPFILE" ]; then
                echo "$T"
            fi
        fi
    fi
}

# Get the top of the build tree
T=$(gettop)

# check that the top of the build tree is set
if [ ! "$T" ]; then
    echo "Couldn't locate the top of the tree. Always source build/envsetup.sh from the root of the tree." >&2
    return 1
fi

# ssortcuts go back to the top of the tree
function croot() {
    local T=$(gettop)
    if [ "$T" ]; then
        if [ "$1" ]; then
            \cd $(gettop)/$1
        else
            \cd $(gettop)
        fi
    else
        echo "Couldn't locate the top of the tree.  Try setting TOP."
    fi
}

function godir() {
    if [[ -z "$1" ]]; then
        echo "Usage: godir <regex>"
        return
    fi
    local T=$(gettop)
    local FILELIST
    if [ ! "$OUT_DIR" = "" ]; then
        mkdir -p $OUT_DIR
        FILELIST=$OUT_DIR/filelist
    else
        FILELIST=$T/filelist
    fi
    if [[ ! -f $FILELIST ]]; then
        echo -n "Creating index..."
        (
            \cd $T
            find ./$NUTTX_DIR_NAME ./apps ./external ./frameworks ./vendor -type f >$FILELIST
        )
        echo " Done"
        echo ""
    fi
    local lines
    lines=($(\grep "$1" $FILELIST | sed -e 's/\/[^/]*$//' | sort | uniq))
    if [[ ${#lines[@]} = 0 ]]; then
        echo "Not found"
        return
    fi
    local pathname
    local choice
    if [[ ${#lines[@]} > 1 ]]; then
        while [[ -z "$pathname" ]]; do
            local index=1
            local line
            for line in ${lines[@]}; do
                printf "%6s %s\n" "[$index]" $line
                index=$(($index + 1))
            done
            echo
            echo -n "Select one: "
            unset choice
            read choice
            if [[ $choice -gt ${#lines[@]} || $choice -lt 1 ]]; then
                echo "Invalid choice"
                continue
            fi
            pathname=${lines[@]:$(($choice - 1)):1}
        done
    else
        pathname=${lines[@]:0:1}
    fi
    \cd $T/$pathname
}

GREP_EXCLUDE=" -name .repo -prune -o -name .git -prune -o -name out -prune -o -name out -prune -o -name prebuilts -prune -o -name cm-tools -prune -o "

function cgrep() {
    find . $GREP_EXCLUDE -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) \
        -exec grep --color -n "$@" {} +
}

function mgrep() {
    find . $GREP_EXCLUDE -type f \( -name 'Makefile' -o -name 'Make.defs' -o -name 'CMakeLists.txt' -o -name '*.mk' -o -name '*.cmake' \) \
        -exec grep --color -n "$@" {} +
}

function kgrep() {
    find . $GREP_EXCLUDE -type f \( -name 'Kconfig' \) \
        -exec grep --color -n "$@" {} +
}

function clean_select_configs() {
    export VELA_BUILD_TARGET_VENDOR=
    export VELA_BUILD_TARGET_BOARD=
    export VELA_BUILD_TARGET_CONFIG=
}

function clunch() {
    local vendor=$VELA_BUILD_TARGET_VENDOR
    local board=$VELA_BUILD_TARGET_BOARD
    local config=$VELA_BUILD_TARGET_CONFIG
    echo -e "The current build configuration lunched with: \033[32m[$vendor]-[$board]-[$config]!"
}

# Function: dump_build_choices
# Description:
#   This function searches for build choices within a vendor directory structure.
#   It identifies directories that contain a 'boards' subdirectory and further
#   filters those boards directories to find subdirectories with a 'configs'
#   subdirectory and a 'CMakeLists.txt' file. The function then constructs a
#   formatted string for each matching configuration and prints the results.
#
# Usage:
#   dump_build_choices
#
# Output:
#   Prints a list of formatted strings, each representing a build choice in the
#   format '[vendor_dir]-[board_dir]-[config_dir]', where:
#     - vendor_dir is the name of the directory containing 'boards'.
#     - board_dir is the name of the 'boards' subdirectory.
#     - config_dir is the name of the 'configs' subdirectory.
#
# Example:
#   If the structure is as follows:
#   vendor/bouffalolab/boards/bl616evb/configs/nsh
#   The output might be:
#   [bouffalolab]-[bl616evb]-[nsh]
#
# Note:
#   This function assumes that the 'gettop' function is defined and returns the
#   root directory of the project. It also assumes that the 'boards' and 'configs'
#   directories, as well as the 'CMakeLists.txt' file, are present in the expected
#   locations.
#
function dump_build_choices() {
    # Define the starting directory as the 'vendor' directory within the project root.
    start_dir=$(gettop)/vendor

    # Initialize an array to hold directories containing 'boards'.
    list_of_dirs=()

    # Search for directories at the first level under 'start_dir' that contain 'boards'.
    find "$start_dir" -maxdepth 1 -type d | while read -r dir; do
        if [[ -d "${dir}/boards" ]]; then
            # If a 'boards' directory is found, add the parent directory to the list.
            list_of_dirs+=("$dir")
        fi
    done

    # Initialize an array to hold the final formatted results.
    final_results=()

    # Iterate over each directory in the list that contains 'boards'.
    for parent_dir in "${list_of_dirs[@]}"; do
        # Search for subdirectories within the 'boards' directory.
        find "$parent_dir/boards" -maxdepth 1 -type d ! -path "$parent_dir/boards" | while read -r subdir; do
            # Check if the subdirectory contains 'configs' and a 'CMakeLists.txt' file.
            if [[ -d "${subdir}/configs" && -f "${subdir}/CMakeLists.txt" ]]; then
                # Get all subdirectories within 'configs'.
                configs_subdirs=("$subdir"/configs/*)
                for config_subdir in "${configs_subdirs[@]}"; do
                    if [[ -d "$config_subdir" ]]; then
                        # Format the result string and add it to the final results array.
                        final_results+=("[$(basename $parent_dir)]-[$(basename $subdir)]-[$(basename $config_subdir)]")
                    fi
                done
            fi
            # boards chip level config such as bes
            find $subdir -maxdepth 1 -type d ! -path $subdir | while read -r chipdir; do
                if [[ -d "${chipdir}/configs" && -f "${chipdir}/CMakeLists.txt" ]]; then
                    # Get all subdirectories within 'configs'.
                    configs_subdirs=("$chipdir"/configs/*)
                    for config_subdir in "${configs_subdirs[@]}"; do
                        if [[ -d "$config_subdir" ]]; then
                            # Format the result string and add it to the final results array.
                            final_results+=("[$(basename $parent_dir)]-[$(basename $chipdir)]-[$(basename $config_subdir)]")
                        fi
                    done
                fi
            done
        done
    done
    # Print the final results.
    printf '%s\n' "${final_results[@]}"
}

function print_lunch_menu() {
    local choices
    choices=$(dump_build_choices 2>/dev/null)
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "Warning: Cannot display lunch menu."
        echo
        echo "Note: You can invoke lunch with an explicit target:"
        echo
        echo "  usage: lunch vendor/sim/boards/miwear/configs/vela" >&2
        echo
        return
    fi

    echo "Lunch menu .. Here are the support combinations:"

    local i=1
    local choice
    for choice in $(echo $choices); do
        echo "     $i. $choice"
        i=$(($i + 1))
    done

    echo
}

function lunch() {
    local answer

    if [[ $# -gt 1 ]]; then
        echo "usage: lunch [target]" >&2
        return 1
    fi

    local used_lunch_menu=0

    if [ "$1" ]; then
        answer=$1
    else
        print_lunch_menu
        echo "Which would you like?"
        echo -n "Pick from common choices above or specify your own: "
        read answer
        used_lunch_menu=1
    fi

    local selection=
    if [ -z "$answer" ]; then
        selection="[sim]-[vela]-[vela]"
    elif (echo -n $answer | grep -q -e "^[0-9][0-9]*$"); then
        local -a choices=()
        while IFS= read -r line; do
            choices+=("$line")
        done < <(dump_build_choices)
        if [ $answer -le ${#choices[@]} ]; then
            # array in zsh starts from 1 instead of 0.
            if [ -n "$ZSH_VERSION" ]; then
                selection=${choices[$(($answer))]}
            else
                selection=${choices[$(($answer - 1))]}
            fi
        fi
    else
        selection=$answer
    fi

    export TARGET_BUILD_APPS=

    # This must be [vendor]-[board]-[config]
    local vendor board config
    # Split string on the '-' character.
    selection=$(echo "$selection" | sed 's/[][]//g')

    IFS="-" read -r vendor board config <<<"$selection"

    if [[ -z "$vendor" ]] || [[ -z "$board" ]] || [[ -z "$config" ]]; then
        echo
        echo "Invalid lunch combo: $selection"
        echo "Valid combos must be of the form [vendor]-[board]-[config]"
        return 1
    fi

    # clean first
    clean_select_configs
    export VELA_BUILD_TARGET_VENDOR=$vendor
    export VELA_BUILD_TARGET_BOARD=$board
    export VELA_BUILD_TARGET_CONFIG=$config

    echo -e "The current build configuration lunched with: \033[32m[$vendor]-[$board]-[$config]!"
    echo
}

function _wrap_build() {
    TOP_DIR=$(gettop)
    OUT_DIR=$TOP_DIR/out
    NUTTXDIR=$TOP_DIR/$NUTTX_DIR_NAME
    CMAKE_BINARY_DIR=${OUT_DIR}/${VELA_BUILD_TARGET_VENDOR}_${VELA_BUILD_TARGET_BOARD}_${VELA_BUILD_TARGET_CONFIG}

    if [ -d "$TOP_DIR/vendor/${VELA_BUILD_TARGET_VENDOR}/boards/${VELA_BUILD_TARGET_BOARD}/configs/${VELA_BUILD_TARGET_CONFIG}" ]; then
        BOARD_CONFIG="vendor/${VELA_BUILD_TARGET_VENDOR}/boards/${VELA_BUILD_TARGET_BOARD}/configs/${VELA_BUILD_TARGET_CONFIG}"
    else
        BOARD_CONFIG="$(dirname vendor/${VELA_BUILD_TARGET_VENDOR}/boards/*/${VELA_BUILD_TARGET_BOARD}/configs/${VELA_BUILD_TARGET_CONFIG})/${VELA_BUILD_TARGET_CONFIG}"
    fi

    if [[ "${VELA_QUIET_BUILD:-}" == true ]]; then
        "$@"
        return $?
    fi
    local start_time=$(date +"%s")
    "$@"
    local ret=$?
    local end_time=$(date +"%s")
    local tdiff=$(($end_time - $start_time))
    local hours=$(($tdiff / 3600))
    local mins=$((($tdiff % 3600) / 60))
    local secs=$(($tdiff % 60))
    local ncolors=$(tput colors 2>/dev/null)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        color_failed=$'\E'"[0;31m"
        color_success=$'\E'"[0;32m"
        color_warning=$'\E'"[0;33m"
        color_reset=$'\E'"[00m"
    else
        color_failed=""
        color_success=""
        color_reset=""
    fi

    echo
    if [ $ret -eq 0 ]; then
        echo -n "${color_success}#### build completed successfully "
    else
        echo -n "${color_failed}#### failed to build some targets "
    fi
    if [ $hours -gt 0 ]; then
        printf "(%02g:%02g:%02g (hh:mm:ss))" $hours $mins $secs
    elif [ $mins -gt 0 ]; then
        printf "(%02g:%02g (mm:ss))" $mins $secs
    elif [ $secs -gt 0 ]; then
        printf "(%s seconds)" $secs
    fi
    echo " ####${color_reset}"
    echo
    return $ret
}

function _trigger_build() (
    local -r bc="$1"
    shift
    local T=$(gettop)
    if [ -n "$T" ]; then
        _wrap_build ${bc} "$@"
    else
        echo >&2 "Couldn't locate the top of the tree. Try setting TOP."
        return 1
    fi
    local ret=$?
    return $ret
)

function m() {
    _trigger_build "build_board" "$@"
}

function mm() {
    _trigger_build "build_and_install_board" "$@"
}

function mmm() {
    _trigger_build "build_current_target" "$@"
}

function get_make_command() {
    # If we're in the Makefile directory, use the real make
    if [ -f Makefile ]; then
        echo command make
        return
    fi
    # Always use the real make if -C is passed in
    for arg in "$@"; do
        if [[ $arg == -C* ]]; then
            echo command make
            return
        fi
    done
    echo m
}

function make() {
    $(get_make_command $@) $@
}

function do_cmake_generator() {
    if [ ! -d "${CMAKE_BINARY_DIR}" ]; then
        echo -e "Build CMake configuration:"
        echo -e "  cmake -B ${CMAKE_BINARY_DIR} -S ${NUTTXDIR} -DBOARD_CONFIG=../${BOARD_CONFIG} -DEXTRA_FLAGS=\"${VELA_EXTRA_FLAGS}\" ${VELA_CMAKE_GENERATOR}"
        if ! cmake -B ${CMAKE_BINARY_DIR} -S ${NUTTXDIR} -DBOARD_CONFIG=../${BOARD_CONFIG} -DEXTRA_FLAGS="${VELA_EXTRA_FLAGS}" ${VELA_CMAKE_GENERATOR}; then
            echo "Error: ############# config ${1} fail ##############"
            exit 1
        fi
    fi
}

function build_board() {

    # first check if the command target is `distclean`
    # cmake is built for out-of-tree, so delete the CMAKE_BINARY_DIR directory directly
    if echo "${@:1}" | grep -q "clean"; then
        echo -e "Build target distclean:"
        echo -e "  there is no need to distclean in cmake, delete '${CMAKE_BINARY_DIR}' directly"
        if [ -d "${CMAKE_BINARY_DIR}" ]; then
            rm -rf $CMAKE_BINARY_DIR
        fi
        return 0
    fi
    # check parallelism
    j_arg=$(echo ${@:1} | grep -oP '\-j[0-9]+')
    if [ -z "$j_arg" ]; then
        j_arg="-j$(nproc)"
    fi
    # cmake verbose
    v_arg=""
    # check if cmake configuration is required
    do_cmake_generator
    # check if the command target is `Xconfig`
    for arg in "${@:1}"; do
        if [[ $arg == *config ]]; then
            echo -e "  cmake --build ${CMAKE_BINARY_DIR} -t $arg"
            if ! cmake --build ${CMAKE_BINARY_DIR} -t $arg; then
                echo "Error: ############# CMake -t $arg fail ##############"
                exit 2
            else
                return 0
            fi
        fi
        if [[ "$arg" =~ ^V=1$ ]]; then
            v_arg+="-v"
        fi
    done
    # do cmake build
    echo -e "  cmake --build ${CMAKE_BINARY_DIR} $j_arg $v_arg"
    if ! cmake --build ${CMAKE_BINARY_DIR} $j_arg $v_arg; then
        echo "Error: ############# build ${1} fail ##############"
        exit 2
    fi
    # do cmake install
    if [[ ! -z $CMAKE_WITH_INSTALL ]]; then
        echo -e "  cmake --install ${CMAKE_BINARY_DIR}"
        if ! cmake --install ${CMAKE_BINARY_DIR}; then
            echo "Error: ############# CMake install fail ##############"
            exit 2
        else
            return 0
        fi
    fi

}

function build_and_install_board() {

    build_board "$@"

    echo -e "  cmake --install ${CMAKE_BINARY_DIR}"
    if ! cmake --install ${CMAKE_BINARY_DIR}; then
        echo "Error: ############# CMake install fail ##############"
        exit 2
    else
        return 0
    fi

}

function build_current_target() {
    local T=$(gettop)
    # first check whether CMake generator is done
    do_cmake_generator
    # where we should find in CMake BINAR dir?
    if [[ "$PWD" == "$T/$NUTTX_DIR_NAME"* ]]; then
        relative_path=$(realpath -s --relative-to="$T/$NUTTX_DIR_NAME" "$PWD")
    else
        relative_path=$(realpath -s --relative-to="$T" "$PWD")
    fi
    target_path=${CMAKE_BINARY_DIR}/${relative_path}
    # build specific target
    if [ -e "${target_path}/targets" ]; then
        targets=($(sort -u ${target_path}/targets))
        echo targets=${targets[@]}
        for target in ${targets[@]}; do
            if ! cmake --build ${CMAKE_BINARY_DIR} -t $target; then
                echo "Error: ############# build ${target} fail ##############"
                exit 2
            fi
            echo -e " $target archive in ${target_path}"
        done
    fi
}

# Zsh needs bashcompinit called to support bash-style completion.
function enable_zsh_completion() {
    # Don't override user's options if bash-style completion is already enabled.
    if ! declare -f complete >/dev/null; then
        autoload -U compinit && compinit
        autoload -U bashcompinit && bashcompinit
    fi
}

function validate_current_shell() {
    local current_sh="$(ps -o command -p $$)"
    case "$current_sh" in
    *bash*)
        function check_type() { type -t "$1"; }
        ;;
    *zsh*)
        function check_type() { type "$1"; }
        enable_zsh_completion
        ;;
    *)
        echo -e "WARNING: Only bash and zsh are supported.\nUse of other shell would lead to erroneous results."
        ;;
    esac
}

# Add directories to PATH that are NOT dependent on the lunch target.
# For directories that are lunch-specific, add them in set_lunch_paths
function setup_global_paths() {
    export VELA_ORIGINAL_PS1="$PS1"
    export VELA_ORIGINAL_PATH="$PATH"

    # wrap bash prompt, mark the current state of vela envs
    env_name="vela-env"
    PS1="($env_name) $VELA_ORIGINAL_PS1"
    export PS1

    local T=$(gettop)
    if [ ! "$T" ]; then
        echo "Couldn't locate the top of the tree.  Try setting TOP."
        return
    fi

    ##################################################################
    #                                                                #
    #              Read me before you modify this code               #
    #                                                                #
    #   This function sets VELA_GLOBAL_BUILD_PATHS to what it is  #
    #   adding to PATH, and the next time it is run, it removes that #
    #   from PATH.  This is required so envsetup.sh can be sourced   #
    #   more than once and still have working paths.                 #
    #                                                                #
    ##################################################################

    # Out with the old...
    if [ -n "$VELA_GLOBAL_BUILD_PATHS" ]; then
        export PATH=${PATH/$VELA_GLOBAL_BUILD_PATHS/}
    fi

    if [ -n "$VELA_GLOBAL_PYPATHS" ]; then
        export PYTHONPATH=${PYTHONPATH/$VELA_GLOBAL_PYPATHS/}
    fi

    if [ -n "$WASI_SDK_PATH" ]; then
        export WASI_SDK_PATH=
    fi

    if [ -z "$VELA_EXTRA_FLAGS" ]; then
        export VELA_EXTRA_FLAGS="-Wno-cpp"
    fi

    if [ -z "$VELA_CMAKE_GENERATOR" ]; then
        export VELA_CMAKE_GENERATOR="-GNinja"
    fi

    SYSTEM=$(uname | tr '[:upper:]' '[:lower:]')
    SYS_ARCH=$(uname -m | sed 's/arm64/aarch64/')

    ARCH=(
        "xtensa"
        "arm"
        "arm64"
        "risc-v"
        "x86_64"
        "tc32")

    TOOLCHAIN=(
        "gcc"
        "clang")

    if [[ "$XTENSAD_LICENSE_FILE" == "" ]]; then
        export XTENSAD_LICENSE_FILE=28000@10.38.168.2
    fi
    export WASI_SDK_PATH=$T/prebuilts/clang/${SYSTEM}/wasm
    # And in with the new...
    VELA_GLOBAL_BUILD_PATHS=${WASI_SDK_PATH}
    VELA_GLOBAL_PYPATHS=$T/prebuilts/tools/python/dist-packages/pyelftools
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/cxxfilt
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/Mako
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/ply
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/jsonpath
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/kconfiglib
    VELA_GLOBAL_PYPATHS+=:$T/prebuilts/tools/python/dist-packages/construct

    # Recommended to use kconfiglib instead of kconfig-frontends
    VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/tools/python/bin

    for ((i = 0; i < ${#ARCH[*]}; i++)); do
        for ((j = 0; j < ${#TOOLCHAIN[*]}; j++)); do
            if [ -d $T/prebuilts/${TOOLCHAIN[$j]}/${SYSTEM}-${SYS_ARCH}/${ARCH[$i]}/bin ]; then
                VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/${TOOLCHAIN[$j]}/${SYSTEM}-${SYS_ARCH}/${ARCH[$i]}/bin
            elif [ -d $T/prebuilts/${TOOLCHAIN[$j]}/${SYSTEM}/${ARCH[$i]}/bin ]; then
                VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/${TOOLCHAIN[$j]}/${SYSTEM}/${ARCH[$i]}/bin
            fi
        done
    done
    lsb_release_version=$(lsb_release -rs | cut -d '.' -f1)
    # Gdb-multiarch Path
    if [ "$lsb_release_version" -ge 22 ] && [ -d $T/prebuilts/gcc/linux/gdb-multiarch/bin ]; then
        VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/gcc/linux/gdb-multiarch/bin
    fi
    # Arm Compiler
    VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/clang/${SYSTEM}/armclang/bin

    if [ ! -n "${ARM_PRODUCT_DEF}" ]; then
        export ARM_PRODUCT_DEF=${ROOTDIR}/prebuilts/clang/${SYSTEM}/armclang/mappings/eval.elmap
    fi
    if [ ! -n "${LM_LICENSE_FILE}" ]; then
        export LM_LICENSE_FILE=${HOME}/.arm/ds/licenses/DS000-EV-31030.lic
    fi
    if [ ! -n "${ARMLMD_LICENSE_FILE}" ]; then
        export ARMLMD_LICENSE_FILE=${HOME}/.arm/ds/licenses/DS000-EV-31030.lic
    fi

    # Generate compile database file compile_commands.json
    if type bear >/dev/null 2>&1; then
        # get version of bear
        BEAR_VERSION=$(bear --version | awk '{print $2}' | awk -F. '{printf("%d%03d%03d ", $1,$2,$3)}')

        # judge version of bear
        if [ $BEAR_VERSION -ge 3000000 ]; then
            # BEAR="bear --append --output compile_commands.json -- "
            echo -e "Note: currently not support bear 3.0.0+ for some prebuilt toolchain limited."
        else
            echo -e "Note: bear 2.4.3 in Ubuntu 20.04 works out of box."
            COMPILE_COMMANDS_DB_PATH="$T/compile_commands"
            if [ ! -d "$COMPILE_COMMANDS_DB_PATH" ]; then
                mkdir -p $COMPILE_COMMANDS_DB_PATH
            fi

            COMPILE_COMMANDS=$T/compile_commands.json
            COMPILE_COMMANDS_BACKUP=${COMPILE_COMMANDS_DB_PATH}/compile_commands_${1//\//_}_$(date "+%Y-%m-%d-%H-%M-%S").json
            export BEAR="bear -a -o ${COMPILE_COMMANDS} "
        fi
    fi

    # Add prebuilt tool
    VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/tools/${SYSTEM}/${SYS_ARCH}

    # Additional prebuilt GNU tools
    if [[ ${SYSTEM} == "darwin" ]]; then
        VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/tools/gnu/${SYSTEM}/${SYS_ARCH}
        VELA_GLOBAL_BUILD_PATHS+=:$T/prebuilts/tools/gnu/${SYSTEM}/universal
    fi

    # Finally, set PATH
    export PATH=$VELA_GLOBAL_BUILD_PATHS:$PATH
    export PYTHONPATH=$VELA_GLOBAL_PYPATHS:$PYTHONPATH
}

function setup_environment() {
    PACKAGES=(
        "autoconf"
        "automake"
        "bison"
        "build-essential"
        "dfu-util"
        "genromfs"
        "flex"
        "git"
        "gperf"
        "libncurses5"
        "lib32ncurses5-dev"
        "libc6-dev-i386"
        "libx11-dev"
        "libx11-dev:i386"
        "libxext-dev"
        "libxext-dev:i386"
        "net-tools"
        "pkgconf"
        "unionfs-fuse"
        "zlib1g-dev"
        "kconfig-frontends"
        "g++-11"
        "g++-11-multilib"
        "libpulse-dev:i386"
        "libasound2-dev:i386"
        "libasound2-plugins:i386"
        "libusb-1.0-0-dev"
        "libusb-1.0-0-dev:i386"
        "libv4l-dev"
        "libv4l-dev:i386"
        "libuv1-dev"
        "libmp3lame-dev:i386"
        "libmad0-dev:i386"
        "libv4l-dev:i386"
        "npm"
        "nodejs"
        "xxd"
        "qemu-system-arm"
        "qemu-efi-aarch64"
        "qemu-utils"
        "nasm"
        "yasm"
        "libdivsufsort-dev"
        "libc++-dev"
        "libc++abi-dev"
        "libprotobuf-dev"
        "protobuf-compiler"
        "protobuf-c-compiler"
        "gcc-multilib"
        "g++-multilib"
        "gettext"
        "mtools"
    )
    declare -A INSTALLS
    for ((i = 0; i < ${#PACKAGES[*]}; i++)); do
        dpkg -l ${PACKAGES[$i]} >/dev/null 2>&1
        if [ $? -eq 1 ]; then
            echo "WARNING: no packages found matching ${PACKAGES[$i]}"
            INSTALLS[${#INSTALLS[@]}]=${PACKAGES[$i]}
        fi
    done

    if [ ${#INSTALLS[*]} -eq 0 ]; then
        return
    fi

    if [ ${#INSTALLS[*]} -eq 1 ] && [ "${INSTALLS[0]}" = "kconfig-frontends" ]; then
        return
    fi

    echo "*************************************************************************************"
    echo "The environment of Vela depends on above tools, Run the following command to install:"
    echo ""
    echo " sudo dpkg --add-architecture i386"

    for ((i = 0; i < ${#INSTALLS[*]}; i++)); do
        result=$(apt-cache search ${INSTALLS[$i]})
        if [ "$result" = "" ]; then
            if [ "${INSTALLS[$i]}" = "kconfig-frontends" ]; then
                unset INSTALLS[$i]
            fi
        fi
    done

    echo " sudo apt-get install -y software-properties-common"
    echo " sudo add-apt-repository ppa:ubuntu-toolchain-r/test"
    echo " sudo apt-get update"
    echo " sudo apt-get install -y ${INSTALLS[@]}"
    echo ""
    echo "*************************************************************************************"
}

deactivate nondestructive
validate_current_shell
setup_environment
setup_global_paths

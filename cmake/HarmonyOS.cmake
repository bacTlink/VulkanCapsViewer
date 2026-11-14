# HarmonyOS: locate the SDK and the Qt for HarmonyOS kit, and wrap hvigorw.
# vkcaps_harmonyos_toolchain() runs before project(), which loads the toolchain.

# <dir> moved <levels> directories up
function(_vkcaps_parent out_var dir levels)
    set(_dir "${dir}")
    foreach(_level RANGE 1 ${levels})
        get_filename_component(_dir "${_dir}" DIRECTORY)
    endforeach()
    set(${out_var} "${_dir}" PARENT_SCOPE)
endfunction()

function(_vkcaps_harmonyos_sdk)
    if(NOT OHOS_SDK_ROOT)
        # The toolchain also reads $ENV{OHOS_SDK_ROOT}, so it has to win here.
        if(DEFINED ENV{OHOS_SDK_ROOT})
            set(OHOS_SDK_ROOT "$ENV{OHOS_SDK_ROOT}")
        elseif(DEFINED ENV{DEVECO_SDK_HOME})
            # What the Command Line Tools documentation has the user export.
            set(OHOS_SDK_ROOT
                "$ENV{DEVECO_SDK_HOME}/default/openharmony")
        elseif(WIN32 AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.24)
            # The DevEco Studio installer records its own location.
            set(_uninstall
                "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall")
            cmake_host_system_information(RESULT _subkeys
                QUERY WINDOWS_REGISTRY "${_uninstall}" SUBKEYS)
            foreach(_subkey IN LISTS _subkeys)
                if(_subkey MATCHES "DevEco")
                    cmake_host_system_information(RESULT _install_location
                        QUERY WINDOWS_REGISTRY "${_uninstall}/${_subkey}"
                        VALUE "InstallLocation")
                    if(_install_location
                       AND EXISTS "${_install_location}/sdk/default/openharmony")
                        set(OHOS_SDK_ROOT
                            "${_install_location}/sdk/default/openharmony")
                        break()
                    endif()
                endif()
            endforeach()
        endif()
        if(OHOS_SDK_ROOT)
            set(OHOS_SDK_ROOT "${OHOS_SDK_ROOT}" CACHE PATH
                "HarmonyOS SDK root" FORCE)
            message(STATUS "Using OHOS_SDK_ROOT '${OHOS_SDK_ROOT}'")
        endif()
    endif()

    # The SDK carries the ninja that builds the HAP.
    if(OHOS_SDK_ROOT AND NOT CMAKE_PROGRAM_PATH
       AND EXISTS "${OHOS_SDK_ROOT}/native/build-tools/cmake/bin")
        set(CMAKE_PROGRAM_PATH
            "${OHOS_SDK_ROOT}/native/build-tools/cmake/bin" CACHE PATH
            "Directory holding ninja" FORCE)
    endif()
endfunction()

# qmake names its own kit's prefix, and the newest version with a
# harmonyos_arm64_v8a kit wins; the HarmonyOS wrappers carry build-machine
# paths, so only qmake is asked.
function(_vkcaps_harmonyos_qt_kit)
    find_program(_qmake NAMES qmake6 qmake NO_CACHE)
    if(_qmake)
        execute_process(COMMAND "${_qmake}" -query QT_INSTALL_PREFIX
            OUTPUT_VARIABLE _kit_prefix
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            RESULT_VARIABLE _qmake_result)
        if(_qmake_result EQUAL 0 AND _kit_prefix)
            _vkcaps_parent(_qt_root "${_kit_prefix}" 2)
            message(STATUS
                "Looking for Qt under '${_qt_root}', implied by ${_qmake}")
        endif()
    endif()

    file(GLOB _qt_roots LIST_DIRECTORIES true "${_qt_root}/*")
    set(_qt_versions "")
    foreach(_qt_root IN LISTS _qt_roots)
        get_filename_component(_qt_version "${_qt_root}" NAME)
        if(EXISTS "${_qt_root}/harmonyos_arm64_v8a/lib/cmake/Qt6/qt.toolchain.cmake")
            list(APPEND _qt_versions "${_qt_version}")
        endif()
    endforeach()
    list(SORT _qt_versions COMPARE NATURAL ORDER DESCENDING)

    foreach(_qt_version IN LISTS _qt_versions)
        if(_qt_version VERSION_GREATER_EQUAL 6.12.1)
            set(CMAKE_TOOLCHAIN_FILE
                "${_qt_root}/${_qt_version}/harmonyos_arm64_v8a/lib/cmake/Qt6/qt.toolchain.cmake"
                CACHE FILEPATH "Qt for HarmonyOS target kit toolchain" FORCE)
            break()
        endif()
    endforeach()

    if(NOT CMAKE_TOOLCHAIN_FILE)
        message(FATAL_ERROR
            "No Qt for HarmonyOS 6.12.1 or newer found under '${_qt_root}'. "
            "Versions seen: '${_qt_versions}'. Put a Qt kit's bin directory "
            "on PATH so the location can be derived with qmake.")
    endif()
endfunction()

# The host kit sits beside the target kit and is the one holding harmonydeployqt.
function(_vkcaps_harmonyos_qt_host)
    # <prefix>/<version>/harmonyos_arm64_v8a/lib/cmake/Qt6/qt.toolchain.cmake,
    # which qt-cmake passes through a bin/.. detour.
    get_filename_component(_toolchain "${CMAKE_TOOLCHAIN_FILE}" REALPATH)
    _vkcaps_parent(_qt_version_dir "${_toolchain}" 5)
    file(GLOB _kits LIST_DIRECTORIES true "${_qt_version_dir}/*")
    foreach(_kit IN LISTS _kits)
        if(EXISTS "${_kit}/bin/harmonydeployqt"
           OR EXISTS "${_kit}/bin/harmonydeployqt.exe")
            set(QT_HOST_PATH "${_kit}" CACHE PATH
                "Host kit providing moc, rcc and harmonydeployqt" FORCE)
            break()
        endif()
    endforeach()
    if(NOT QT_HOST_PATH)
        message(FATAL_ERROR
            "No Qt kit providing harmonydeployqt found next to "
            "'${_qt_version_dir}'. QT_HOST_PATH must point at the host Qt "
            "installation, the one built for this machine.")
    endif()
endfunction()

# Runs when the preset asked for the HarmonyOS build, or when the caller supplied
# a HarmonyOS toolchain file and only wants the rest filled in.
function(vkcaps_harmonyos_toolchain)
    if(NOT VKCAPS_HARMONYOS AND NOT CMAKE_TOOLCHAIN_FILE MATCHES "harmonyos")
        return()
    endif()

    if(NOT CMAKE_TOOLCHAIN_FILE)
        # Multi-config generates with the host compiler before reading the toolchain.
        if(CMAKE_GENERATOR MATCHES "Visual Studio|Xcode|Multi-Config")
            message(FATAL_ERROR
                "The HarmonyOS build needs a single-configuration generator. "
                "Re-run cmake with -G Ninja.")
        endif()

        # Ninja builds unoptimised without one, and a HAP only runs on a device.
        if(NOT CMAKE_BUILD_TYPE)
            set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
        endif()
    endif()

    _vkcaps_harmonyos_sdk()
    if(NOT CMAKE_TOOLCHAIN_FILE)
        _vkcaps_harmonyos_qt_kit()
    endif()
    if(NOT QT_HOST_PATH)
        _vkcaps_harmonyos_qt_host()
    endif()
endfunction()

# harmonydeployqt drives hvigorw, which needs DEVECO_SDK_HOME, a JDK and Node.
function(vkcaps_harmonyos_hvigor)
    if(NOT OHOS_SDK_ROOT)
        return()
    endif()
    _vkcaps_parent(_deveco "${OHOS_SDK_ROOT}" 3)
    _vkcaps_parent(_sdk_dir "${OHOS_SDK_ROOT}" 2)

    if(NOT HARMONYOS_HVIGOR)
        # DevEco Studio keeps it in tools/hvigor, the Command Line Tools in bin.
        foreach(_hvigor_dir
                "${_deveco}/tools/hvigor" "${_deveco}" "${_deveco}/hvigor")
            foreach(_wrapper hvigorw.bat hvigorw)
                if(EXISTS "${_hvigor_dir}/bin/${_wrapper}")
                    set(HARMONYOS_HVIGOR "${_hvigor_dir}/bin/${_wrapper}")
                    break()
                endif()
            endforeach()
            if(HARMONYOS_HVIGOR)
                break()
            endif()
        endforeach()
    endif()
    if(NOT HARMONYOS_HVIGOR OR NOT EXISTS "${_sdk_dir}")
        set(HARMONYOS_HVIGOR "${HARMONYOS_HVIGOR}" PARENT_SCOPE)
        return()
    endif()

    set(_path "")
    foreach(_bundled
            "${_deveco}/jbr/bin"
            "${_deveco}/tools/node"
            "${_deveco}/node"
            "${_deveco}/node/bin"
            "${_deveco}/tool/node"
            "${_deveco}/tool/node/bin"
            # hvigor runs ohpm itself, but only if it is on PATH.
            "${_deveco}/tools/ohpm/bin"
            "${_deveco}/ohpm/bin")
        if(EXISTS "${_bundled}")
            if(_path)
                set(_path "${_path};${_bundled}")
            else()
                set(_path "${_bundled}")
            endif()
        endif()
    endforeach()

    # WIN32 describes the target, which is OHOS, so ask about the host.
    if(CMAKE_HOST_WIN32)
        set(_hvigorw "${CMAKE_BINARY_DIR}/vkcaps-hvigorw.bat")
        set(_body "@echo off\r\n")
        string(APPEND _body "set \"DEVECO_SDK_HOME=${_sdk_dir}\"\r\n")
        if(_path)
            string(REPLACE "/" "\\" _path_win "${_path}")
            string(APPEND _body "set \"PATH=${_path_win};%PATH%\"\r\n")
        endif()
        string(APPEND _body
            "call \"${HARMONYOS_HVIGOR}\" %* -p enforce-ohpm=true\r\n")
    else()
        set(_hvigorw "${CMAKE_BINARY_DIR}/vkcaps-hvigorw")
        set(_body "#!/bin/sh\n")
        string(APPEND _body
            "DEVECO_SDK_HOME=\"${_sdk_dir}\"\n"
            "export DEVECO_SDK_HOME\n")
        if(_path)
            string(REPLACE ";" ":" _path_sh "${_path}")
            string(APPEND _body "PATH=\"${_path_sh}:$PATH\"\n"
                "export PATH\n")
        endif()
        string(APPEND _body
            "exec \"${HARMONYOS_HVIGOR}\" \"$@\" -p enforce-ohpm=true\n")
    endif()
    file(WRITE "${_hvigorw}" "${_body}")
    set(HARMONYOS_HVIGOR "${_hvigorw}" PARENT_SCOPE)
    if(_path)
        message(STATUS "Wrapping hvigorw to put '${_path}' on PATH")
    endif()
endfunction()

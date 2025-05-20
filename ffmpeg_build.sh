#!/bin/bash
#
# from https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
#
# Compile FFmpeg for Ubuntu, Debian, or Mint
#
# Contents
#
#    Get the Dependencies
#    Compilation & Installation
#    Updating FFmpeg
#    Reverting Changes made by this Guide
#    FAQ
#    If You Need Help
#    Also See
#
# This guide for standard current releases of Ubuntu and Debian. It will provide a local, non-system installation of FFmpeg with several external libraries.
#
# You may also refer to the Generic Compilation Guide for additional information about compiling software.
#
# Recent static builds are also available for lazy people or those who are unable to compile. The static builds do not support non-free libraries.
#
# Note: FFmpeg is part of the Ubuntu packages and can be installed via apt-get install ffmpeg. You may still wish to compile if you want the latest version, experience a bug, or want to customize your build, and it will not interfere with the ffmpeg package in the repository.
#
#    Tags
#    configuration
#
# This guide is designed to be non-intrusive and will create several directories in your home directory:
#
#    ffmpeg_sources – Where the source files will be downloaded. This can be deleted if desired when finished with the guide.
#    ffmpeg_build – Where the files will be built and libraries installed. This can be deleted if desired when finished with the guide.
#    bin – Where the resulting binaries (ffmpeg, ffplay, ffprobe, x264, x265) will be installed.
# --------------------------------------------------------------------------------------------------

# Where the source files will be downloaded. This can be deleted if desired when finished with the guide.
# ffmpeg_sources=~/ffmpeg_sources # default
ffmpeg_sources=~/ffmpeg/sources # Personal. For me this location is a symlink to a fas dev drive

# Where the resulting binaries (ffmpeg, ffplay, ffprobe, x264, x265) will be installed.
# ffmpeg_bin=~/bin   # default
ffmpeg_bin=~/bin  # Personal. For me this location is a symlink to a fast dev drive
# Where the files will be built and libraries installed. This can be deleted if desired when finished with the guide.
ffmpeg_build=~/ffmpeg/build

# The number of processors/cores to compile on - this example leaves 1 free for other stuff
# Change it to whatever your want - there are arguments to increase this beyond your proc count
# see https://unix.stackexchange.com/questions/519092/what-is-the-logic-of-using-nproc-1-in-make-command
# the net argument in favour is:
# The real limit on build time however isn’t CPU capacity, it’s I/O capacity,
# but there’s no handy metric to determine that.
# So nproc is a proxy: it tells you how many jobs you can run in parallel without
# exhausting your CPU resources at least.
# Adding one is a common technique to use a bit more CPU...
JM="-j $(($(nproc) - 1))" # Note: The default for make: Allow N jobs at once; infinite jobs with no arg
                          #       The default for ninja: run N jobs in parallel (0 means infinity) [default=6 on this system]
                          # So: Effectively the same
unset JM                  # set this back to default - Comment this line out if you want to reduce cpu usage



enable_args=""
# ffmpeg/sources
# ffmpeg/build
# ffmpeg/bin

# I had a promblem with PYTHONUSERBASE
# python couldnt import cmake bacause PYTHONUSERBASE was pointing to a
# non-existant folder.
# The physical disk it was on had died years ago and I forgot the variable was set
[ -d ${PYTHONUSERBASE} ] || unset PYTHONUSERBASE

bailout(){
  #error handler
  echo -e "\n${1}\nSo quitting..."
  exit
}

cleanup(){
  rm -rf ${ffmpeg_build} ${ffmpeg_sources} ${ffmpeg_bin}/{ffmpeg,ffprobe,ffplay,x264,x265,nasm}
  }

# These are packages required for compiling, but you can
# remove them when you are done if you prefer:
deps(){
  echo -e "\nInstalling Dependancies"
  echo -e "\nA quiet screen probably means we already did this"
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get -y install build-essential \
    yasm \
    cmake \
    libtool \
    libc6 \
    libc6-dev \
    unzip \
    wget \
    libnuma1 \
    libnuma-dev

  sudo apt-get -y install \
    autoconf \
    automake \
    build-essential \
    cmake \
    git-core \
    libass-dev \
    libfreetype6-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libsdl2-dev \
    libtool \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    meson \
    ninja-build \
    pkg-config \
    texinfo \
    wget \
    yasm \
    zlib1g-dev



    sudo apt-get -y install libunistring-dev libaom-dev libdav1d-dev libffmpeg-nvenc-dev

    # just to make sure
    # pip install cmake
    pip install cmake --user $(whoami)

    mkdir -p ${ffmpeg_sources} ${ffmpeg_bin} ${ffmpeg_build}
    ls



    ffmpeg_sources=$(cd ${ffmpeg_sources}; pwd) # Personal. For me this location is a symlink to a fas dev drive
    ffmpeg_bin=$(cd ${ffmpeg_bin} ; pwd)  # Personal. For me this location is a symlink to a fas dev drive
    ffmpeg_build=$(cd ${ffmpeg_build} ; pwd)
    # Some of the build process require the bin directory to be a subdirectory
    # of the sources directory.
    # see libvmaf below
    # [ -L "${ffmpeg_sources}/bin" ] || ln -s ${ffmpeg_bin} ${ffmpeg_sources}/bin
    # The above seemed to create
    echo -e "\nDone\n"
}




assembler(){
# An assembler used by some libraries.
#
# If your repository provides nasm version ≥ 2.14 then you can install that instead of compiling:
# nasm
  cd ${ffmpeg_sources} && \
  # I had problems with a corrupt download that wget would not clobber
  # so I force a fresh download by deleting the archive
  [ -f nasm-2.16.03.tar.bz2 ] && rm xjvf nasm-2.16.03.tar.bz2
  wget https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.bz2
  tar xjvf nasm-2.16.03.tar.bz2
  cd nasm-2.16.03 && \
  ./autogen.sh && \
  PATH="${ffmpeg_bin}:$PATH" ./configure --prefix="${ffmpeg_build}" --bindir="${ffmpeg_bin}" && \
  make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "nasm compile failed"
}

# NVENC
#
# NVENC can be used for H.264 and HEVC encoding. FFmpeg supports NVENC through the h264_nvenc and hevc_nvenc encoders. In order to enable it in FFmpeg you need:
#
#     A ​supported GPU
#     Supported drivers for your operating system
#     ​The NVIDIA Codec SDK or compiling FFmpeg with --enable-cuda-llvm
#     ffmpeg configured with --enable-ffnvcodec (default if the nv-codec-headers are detected while configuring)
#
# Note: FFmpeg uses its own slightly modified runtime-loader for NVIDIA's CUDA/NVENC/NVDEC-related libraries. If you get an error from configure complaining about missing ffnvcodec, ​this project is what you need. It has a working Makefile with an install target: make install PREFIX=/usr. FFmpeg will look for its pkg-config file, called ffnvcodec.pc. Make sure it is in your PKG_CONFIG_PATH.
#
# This means that running the following before compiling ffmpeg should suffice:

use_ffnvcodec(){
      enable_args="${enable_args} --enable-ffnvcodec"
      # --enable-cuda-llvm is enable_args by default
      cd ${ffmpeg_sources}
      if [[ -d nv-codec-headers ]]
      then
        cd nv-codec-headers
        git fetch --tags
      else
        git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
        cd nv-codec-headers
      fi
      make ${JM} && \
      sudo make install && echo -e "\nDone\n" || bailout "libx264 compile failed"
# After compilation, you can use NVENC.
#
# Usage example:
#
# ffmpeg -i input -c:v h264_nvenc -profile high444p -pixel_format yuv444p -preset default output.mp4
#
# You can see available presets (including lossless for both hevc and h264), other options,
# and encoder info with ffmpeg -h encoder=h264_nvenc or ffmpeg -h encoder=hevc_nvenc.
#
# Note: If you get the No NVENC capable devices found error make sure you're encoding to a supported pixel format. See encoder info as shown above.
#
# NVENC can accept d3d11 frames context directly.
#
# ffmpeg -y -hwaccel_output_format d3d11 -hwaccel d3d11va -i input.mp4 -c:v
# hevc_nvenc out.mp4

}


use_libx264(){
# libx264
#
# H.264 video encoder. See the H.264 Encoding Guide for more information and usage examples.
#
# Requires ffmpeg to be configured with --enable-gpl --enable-libx264.
  [[ ${enable_args} == *"--enable-gpl"* ]] || enable_args="${enable_args} --enable-gpl"
  enable_args="${enable_args} --enable-libx264"
  cd ${ffmpeg_sources} && \
  git -C x264 pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
  cd x264 && \
  PATH="${ffmpeg_bin}:$PATH" PKG_CONFIG_PATH="${ffmpeg_sources}/lib/pkgconfig" ./configure --prefix="${ffmpeg_build}" --bindir="${ffmpeg_bin}" --enable-static --enable-pic && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libx264 compile failed"
}

use_libx265(){

  # libx265
  #
  # H.265/HEVC video encoder. See the H.265 Encoding Guide for more information and usage examples.
  #
  # Requires ffmpeg to be configured with --enable-gpl --enable-libx265.
  [[ ${enable_args} == *"--enable-gpl"* ]] || enable_args="${enable_args} --enable-gpl"
  enable_args="${enable_args} --enable-libx264"

  sudo apt-get -y install libnuma-dev cmake && \
  cd ${ffmpeg_sources} && \
  wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/master.tar.bz2 && \
  tar xjvf x265.tar.bz2 && \
  cd multicoreware*/build/linux && \
  PATH="${ffmpeg_bin}:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${ffmpeg_sources}" -DENABLE_SHARED=off ../../source && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libx265 compile failed"
}


use_libvpx(){
# libvpx
#
# VP8/VP9 video encoder/decoder. See the VP9 Video Encoding Guide for more information and usage examples.
#
# Requires ffmpeg to be configured with --enable-libvpx.
  enable_args="${enable_args} --enable-libvpx"

  cd ${ffmpeg_sources} && \
  git -C libvpx pull 2> /dev/null || git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
  cd libvpx && \
  PATH="${ffmpeg_bin}:$PATH" ./configure --prefix="${ffmpeg_build}" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libvpx compile failed"
}

use_libfdk_aac(){
# libfdk-aac
#
# AAC audio encoder. See the AAC Audio Encoding Guide for more information and usage examples.
#
# Requires ffmpeg to be configured with --enable-libfdk-aac (and --enable-nonfree if you also included --enable-gpl).
# ----------------------------------------------------------------------
# You may see the following flash up in your terminal
# I've pasted it here so you can do whever is required
#
# Libraries have been installed in:
#    'Your ${ffmpeg_build}'/lib
#
# If you ever happen to want to link against installed libraries
# in a given directory, LIBDIR, you must either use libtool, and
# specify the full pathname of the library, or use the '-LLIBDIR'
# flag during linking and do at least one of the following:
#    - add LIBDIR to the 'LD_LIBRARY_PATH' environment variable
#      during execution
#    - add LIBDIR to the 'LD_RUN_PATH' environment variable
#      during linking
#    - use the '-Wl,-rpath -Wl,LIBDIR' linker flag
#    - have your system administrator add LIBDIR to '/etc/ld.so.conf'
#
# See any operating system documentation about shared libraries for
# more information, such as the ld(1) and ld.so(8) manual pages.
# ----------------------------------------------------------------------



  [[ ${enable_args} == *"--enable-gpl"* ]] && enable_args="${enable_args} --enable-nonfree"
  enable_args="${enable_args} --enable-libfdk-aac"

  cd ${ffmpeg_sources} && \
  git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
  cd fdk-aac && \
  autoreconf -fiv && \
  ./configure --prefix="${ffmpeg_build}" --disable-shared && \
  make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libfdk-aac compile failed"
}

use_libopus(){
  # libopus
  #
  # Opus audio decoder and encoder.
  #
  # Requires ffmpeg to be configured with --enable-libopus.
  #
  enable_args="${enable_args} --enable-libopus"
  cd ${ffmpeg_sources} && \
  git -C opus pull 2> /dev/null || git clone --depth 1 https://github.com/xiph/opus.git && \
  cd opus && \
  ./autogen.sh && \
  ./configure --prefix="${ffmpeg_build}" --disable-shared && \
  make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libopus compile failed"
}

use_libaom(){
  # libaom
  #
  # AV1 video encoder/decoder:
  cd ${ffmpeg_sources} && \
  git -C aom pull 2> /dev/null || git clone --depth 1 https://aomedia.googlesource.com/aom && \
  mkdir -p aom_build && \
  cd aom_build && \
  PATH="${ffmpeg_bin}:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${ffmpeg_sources}" -DENABLE_TESTS=OFF -DENABLE_NASM=on ../aom && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libaom compile failed"
}



use_libsvtav1(){
  # libsvtav1
  #
  # AV1 video encoder/decoder. Only the encoder is supported by FFmpeg, so building of the decoder is disabled.
  #
  # Requires ffmpeg to be configured with --enable-libsvtav1.

  # Deal With This error
  # collect2: error: ld returned 1 exit status
  # make[2]: *** [Source/App/CMakeFiles/SvtAv1EncApp.dir/build.make:204: /home/martin/ffmpeg/sources/SVT-AV1/Bin/Release/SvtAv1EncApp] Error 1
  # make[1]: *** [CMakeFiles/Makefile2:575: Source/App/CMakeFiles/SvtAv1EncApp.dir/all] Error 2
  # make: *** [Makefile:136: all] Error 2
  #
  # libsvtav1 compile failed
  # So quitting...


  # for now - untill I figure out why this wont compile I'm skipping this
  # personally I dont use it anyway
  echo -e "\n-------------------------------------------------------"
  echo -e "\nSkipping libsvtav1 untill compile error can be resolved"
  echo -e "\n-------------------------------------------------------"
  return


  enable_args="${enable_args} --enable-libsvtav1"

  cd ${ffmpeg_sources} && \
  git -C SVT-AV1 pull 2> /dev/null || git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
  mkdir -p SVT-AV1/build && \
  cd SVT-AV1/build && \
  PATH="${ffmpeg_bin}:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${ffmpeg_sources}" -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF .. && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && echo -e "\nDone\n" || bailout "libsvtav1 compile failed"
}



use_libdav1d(){
  # libdav1d
  #
  # AV1 decoder, much faster than the one provided by libaom.
  #
  # Requires ffmpeg to be configured with --enable-libdav1d.
  enable_args="${enable_args} --enable-libdav1d"

  sudo apt-get -y install python3-pip && \
  pip3 install --user meson
  cd ${ffmpeg_sources} && \
  git -C dav1d pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/dav1d.git && \
  mkdir -p dav1d/build && \
  cd dav1d/build && \
  meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "${ffmpeg_sources}" --libdir="${ffmpeg_sources}/lib" && \
  ninja ${JM} && \
  ninja install && echo -e "\nDone\n" || bailout "libdav1d compile failed"
}


use_libvmaf(){
  # libvmaf
  # Library for calculating the ​VMAF video quality metric.
  # Requires ffmpeg to be configured with --enable-libvmaf.
  # Currently ​an issue in libvmaf also requires FFmpeg to be built with --ld="g++" for a static build to succeed.
  #


  enable_args="${enable_args} --enable-libvmaf"

  cd ${ffmpeg_sources} && \
  wget https://github.com/Netflix/vmaf/archive/v3.0.0.tar.gz && \
  tar xvf v3.0.0.tar.gz && \
  mkdir -p vmaf-3.0.0/libvmaf/build &&\
  cd vmaf-3.0.0/libvmaf/build && \
  meson setup -Denable_tests=false -Denable_docs=false --buildtype=release --default-library=static .. \
  --prefix "${ffmpeg_sources}" --bindir="${ffmpeg_sources}/bin" --libdir="${ffmpeg_sources}/lib" && \
  ninja ${JM} && \
  ninja install && echo -e "\nDone\n" || bailout "libvmaf compile failed"
  # --prefix "${ffmpeg_sources}" --bindir="${ffmpeg_bin}" --libdir="${ffmpeg_sources}/lib" && \

}


BuildFFmpeg(){
  cd ${ffmpeg_sources} && \
  wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
  tar xjvf ffmpeg-snapshot.tar.bz2 && \
  cd ffmpeg && \
  PATH="${ffmpeg_bin}:$PATH" PKG_CONFIG_PATH="${ffmpeg_sources}/lib/pkgconfig" ./configure \
    --prefix="${ffmpeg_build}" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I${ffmpeg_build}/include" \
    --extra-ldflags="-L${ffmpeg_build}/lib" \
    --extra-libs="-lpthread -lm" \
    --ld="g++" \
    --bindir="${ffmpeg_bin}" \
    --enable-cuda-llvm \
    --enable-gnutls \
    --enable-libaom \
    --enable-libass \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libvorbis \
    ${enable_args} && \
  PATH="${ffmpeg_bin}:$PATH" make ${JM} && \
  make install && \
  hash -r
  echo -e "\nDone\n"
}


select_action()
# No error checking here - assumed to ALLWAYS have two arguments
# argument one is the prompt,
# argument two is the action
# argument 3 - if provided should be "batch"
{

if [ $# -lt 2 ]
then
    echo -e "usage :\n\tselect_action \"prompt\"  action [\"batch\" <optional>]"
    echo -e "\tbatch can be anything but wil cause the function to bahave as if the user selected [Y]es"
fi

ync=" [Y]es [N]no [C]ancel "
if [ $# -eq 3 ] && [ "${3}" == "batch" ]
then
    choice="y"
    ync="${ync}\n"
else
    choice="n"
fi


_prompt="${1}"
# eval _action=${2}
# debugging
_action=$(echo ${2})

done=1
while [ ${done} -eq 1 ]
do
      echo -e "\nDo you wish to $_prompt?"
      [ "${choice}" == "y" ] && echo -e ${ync} || read -p "${ync}" choice
      choice=${choice,,}
      echo -e " ${choice} \n"
      if [ "$choice" = "y" ]; then
        $_action
        done=0
      elif [ "$choice" = "n" ];then
        echo "No Action"
        done=0
      elif [ "$choice" = "c" ];then
        echo "Latest FFmpeg Private Installation cancelled"
        done=0
        exit
      else
        echo "Invalid response!"
      fi
done
}


main(){
  # any argument passed in here will be assumed to mean run as a batch without prompting
  [ $# -gt 0 ] && batch='batch' || unset batch
  select_action "Install Dependencies for FFmpeg" deps ${batch}
  select_action "Build latest version of nasm (private build)" assembler ${batch}
  select_action "compile ffmpeg with ffnvcodec" use_ffnvcodec ${batch}
  select_action "compile ffmpeg with libx264" use_libx264 ${batch}
  select_action "compile ffmpeg with libx265" use_libx265 ${batch}
  select_action "compile ffmpeg with libvpx" use_libvpx ${batch}
  select_action "compile ffmpeg with libfdk_aac" use_libfdk_aac ${batch}
  select_action "compile ffmpeg with libopus" use_libopus ${batch}
  select_action "compile ffmpeg with libaom" use_libaom ${batch}
  select_action "compile ffmpeg with libsvtav1" use_libsvtav1 ${batch}
  select_action "compile ffmpeg with libdav1d" use_libdav1d ${batch}
  select_action "compile ffmpeg with libvmaf" use_libvmaf ${batch}
  select_action "Build FFmpeg" BuildFFmpeg ${batch}


}

pre_main(){
  if [[ -d ${ffmpeg_sources} ]] || [[ -d ${ffmpeg_build} ]] || [[ -f ${ffmpeg_bin}/nasm ]]
  then
    select_action "Shall I clean up the source build area?" cleanup
  fi
  ync=" [Y]es [N]no [C]ancel "
  choice=""
  done=1
  while [ ${done} -eq 1 ]
  do
        echo -e "\nShall I prompt for each section? (exept cleanup)"
        echo -e "\nIf you choose [N]o all sections will run without further prompting"
        read -p "${ync}" choice
        choice=${choice,,}
        echo -e " ${choice} \n"
        if [ "$choice" = "y" ]; then
          main
          done=0
        elif [ "$choice" = "n" ];then
          echo -e "\nAll actions continuing without further user input"
          echo -e "\nBatch will end on the first unsuccesful compilation\n"
          echo -e "\n_____________________________________________________\n"
          main "batch"
          done=0
        elif [ "$choice" = "c" ];then
          echo "Latest FFmpeg Private Installation cancelled"
          done=0
          return
        else
          echo "Invalid response!"
        fi
  done
}


clear
echo -e "--------------------------------------------------"
echo -e "Private version of FFmpeg"
echo -e "This process will prepare and compile sources in:\n\t${ffmpeg_sources}\n"
echo -e "Binary executables will be placed in:\n\t${ffmpeg_bin}\n\n"
select_action "Make a private build of FFmpeg" pre_main

# FFmpeg
# cd ${ffmpeg_sources} && \
# wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
# tar xjvf ffmpeg-snapshot.tar.bz2 && \
# cd ffmpeg && \
# PATH="${ffmpeg_bin}:$PATH" PKG_CONFIG_PATH="${ffmpeg_sources}/lib/pkgconfig" ./configure \
#   --prefix="${ffmpeg_build}" \
#   --pkg-config-flags="--static" \
#   --extra-cflags="-I${ffmpeg_sources}/include" \
#   --extra-ldflags="-L${ffmpeg_sources}/lib" \
#   --extra-libs="-lpthread -lm" \
#   --ld="g++" \
#   --bindir="${ffmpeg_bin}" \
#   --enable-gpl \
#   --enable-gnutls \
#   --enable-libaom \
#   --enable-libass \
#   --enable-libfdk-aac \
#   --enable-libfreetype \
#   --enable-libmp3lame \
#   --enable-libopus \
#   --enable-libsvtav1 \
#   --enable-libdav1d \
#   --enable-libvorbis \
#   --enable-libvpx \
#   --enable-libx264 \
#   --enable-libx265 \
#   --enable-nonfree && \
# PATH="${ffmpeg_bin}:$PATH" make && \
# make install && \
# hash -r

# Tip: The configure error message XYZ not found using pkg-config is often misleading,
# namely when the library was found but,for instance, test compilation went wrong.
# In case of trouble with configure, it may be helpful have a look at the log file it
# produces: ffbuild/config.log which contains a lot of detail.
#
#    Tags
#    configuration
#
# Due to an unresolved x265 bug/feature with threads library
# (see ​https://bitbucket.org/multicoreware/x265_git/issues/371/x265-not-found-using-pkg-config)
# sometimes it's needed to add the
#     --extra-libs="-lpthread"
# switch to the configure script, as suggested above.
# Otherwise ERROR: x265 not found using pkg-config might pop out.
# Now re-login or run the following command for your current shell
# session to recognize the new ffmpeg location:
#
# source ~/.profile
#
# Compilation and installation are now complete and ffmpeg
# (also ffplay, ffprobe, lame, x264, & x265) should now be ready to use.
# The rest of this guide shows how to update or remove FFmpeg.
#
# ------------------------------------------------------
# Usage
#
# You can now open a terminal, enter the ffmpeg command, and it should execute your new ffmpeg.
#
# If you need multiple users on the same system to have access to your new ffmpeg, and not just
# the user that compiled it, then move or copy the ffmpeg binary from ~/bin to /usr/local/bin.
#
# ------------------------------------------------------
# Documentation
#
# If you want to run man ffmpeg to have local access to the documentation:
# echo "MANPATH_MAP ${ffmpeg_bin} ${ffmpeg_sources}/share/man" >> ~/.manpath
#
# You may have to log out and then log in for man ffmpeg to work.
# HTML formatted documentation is available in ~/ffmpeg_build/share/doc/ffmpeg.
#
# You can also refer to the online FFmpeg documentation, but remember that it is
# regenerated daily and is meant to be used with the most current ffmpeg
# (meaning an old build may not be compatible with the online docs).
# Updating FFmpeg
#
# Development of FFmpeg is active and an occasional update can give you new features and bug fixes.
# First you need to delete (or move) the old files:
#
# rm -rf ~/ffmpeg_build ~/bin/{ffmpeg,ffprobe,ffplay,x264,x265}
#
# Now can just follow the guide from the beginning.
#
# Reverting Changes made by this Guide
# Remove the build and source files as well as the binaries:
#
# rm -rf ~/ffmpeg_build ${ffmpeg_sources} ~/bin/{ffmpeg,ffprobe,ffplay,x264,x265,nasm}
# sed -i '/ffmpeg_build/d' ~/.manpath
# hash -r
#
# You may also remove packages that have been installed from this guide:
#
# sudo apt-get autoremove autoconf automake build-essential cmake git-core libass-dev \
# libfreetype6-dev libgnutls28-dev libmp3lame-dev libnuma-dev libopus-dev libsdl2-dev \
# libtool libva-dev libvdpau-dev libvorbis-dev libvpx-dev libx264-dev libx265-dev libxcb1-dev \
# libxcb-shm0-dev libxcb-xfixes0-dev texinfo wget yasm zlib1g-dev
#
# If you didnt already have libunistring-dev libaom-dev libdav1d-dev
# you can also
# sudo apt-get autoremove  libunistring-dev libaom-dev libdav1d-dev
#
# ------------------------------------------------------
# FAQ
# Why install to ~/bin?
#
#     Avoids installing files into any system directories.
#     Avoids interfering with the package management system.
#     Avoids conflicts with the ffmpeg package from the repository.
#     Super simple to uninstall.
#     Does not necessarily require sudo or root: useful for shared server users as long as they have the required dependencies available.
#     ~/bin is already in the vanilla Ubuntu PATH (see ~/.profile).
#     User is free to move ffmpeg to any other desired location (such as /usr/local/bin).
#
# ------------------------------------------------------
# Why are the commands in this guide so complicated?
#
# It is to make compiling easy and convenient for the user. This guide:
#
#     Confines everything to the user's home directory (see the previous FAQ question above).
#     Is intended to be usable on all currently supported versions of Debian and Ubuntu.
#     Allows the user to choose if they want to compile certain libraries (latest and greatest) or to simply install the version from their repository (fast and easy but older).
#
# This results in some various additional commands and configurations instead of the typical and simple ./configure, make, make install.
#
# ------------------------------------------------------
# make[1]: Nothing to be done for 'all'/'install'
#
# This is message from libvpx that occasionally makes users think something went wrong.
# You can ignore this message. It just means make is finished doing its work.
#
# ------------------------------------------------------
# How do I compile to a 32-bit Ubuntu target on an Ubuntu 64-bit host?
#
# sudo apt install gcc-multilib
# ./configure --extra-cflags="-m32"  --extra-ldflags="-m32" ...
# make clean
# make
#
# ------------------------------------------------------
# If You Need Help
#
# Feel free to ask your questions at the #ffmpeg IRC channel or the ffmpeg-user mailing list.
# Also See
#
#     Generic FFmpeg Compilation Guide
#     H.264 Video Encoding Guide
#     AAC Audio Encoding Guide
# ------------------------------------------------------

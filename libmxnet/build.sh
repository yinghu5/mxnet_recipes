#!/usr/bin/env bash

set -ex

#export https_proxy=http://child-prc.intel.com:913
export https_proxy=http://proxy01.iind.intel.com:911/
# Enabled mkl-dnn

MKLDNN_SRC=${SRC_DIR}/3rdparty/mkldnn
MKLDNNROOT=${MKLDNN_SRC}
OMP_LIBFILE=${MKLDNNROOT}/lib/libiomp5.so
MKLML_LIBFILE=${MKLDNNROOT}/lib/libmklml_intel.so
MKLDNN_LIBFILE=${MKLDNNROOT}/lib/libmkldnn.so.0
MKLDNN_LIB64FILE=${MKLDNNROOT}/lib64/libmkldnn.so.0
#MKLDNN_COMMIT=`cat ./mkldnn.commit`
MKLDNN_SUBMODDIR=${SRC_DIR}/3rdparty/mkldnn
MKLDNN_BUILDDIR=${MKLDNN_SUBMODDIR}/build
MXNET_LIBDIR=${SRC_DIR}/lib
MXNET_INCLDIR=${SRC_DIR}/include

mkdir -p ${MKLDNN_BUILDDIR}
cd ${MKLDNN_SUBMODDIR} && cd scripts && ./prepare_mkl.sh && cd .. && cp -a external/*/* ${MKLDNNROOT}/.
#	cd $(MKLDNN_SUBMODDIR)  && cd scripts && cd .. && cp -a external/*/* $(MKLDNNROOT)/.
cmake ${MKLDNN_SUBMODDIR} -DCMAKE_INSTALL_PREFIX=${MKLDNNROOT} -B${MKLDNN_BUILDDIR} -DARCH_OPT_FLAGS="-mtune=generic" -DWITH_TEST=OFF -DWITH_EXAMPLE=OFF
make -C ${MKLDNN_BUILDDIR} -j VERBOSE=1 

make -C ${MKLDNN_BUILDDIR} install
if [ -f "${MKLDNN_LIB64FILE}" ]; then \
	mv ${MKLDNNROOT}/lib64/libmkldnn* ${MKLDNNROOT}/lib/; \
fi
mkdir -p ${MXNET_LIBDIR}
cp ${OMP_LIBFILE} ${MXNET_LIBDIR}
cp ${MKLML_LIBFILE} ${MXNET_LIBDIR}
cp ${MKLDNN_LIBFILE} ${MXNET_LIBDIR}
cp ${MKLDNN_BUILDDIR}/include/mkldnn_version.h ${MXNET_INCLDIR}/mkldnn/.

cd ${SRC_DIR}
cp make/config.mk config.mk

export OPENMP_OPT=1
#export JEMALLOC_OPT=1

if [[ ${HOST} =~ .*darwin.* ]]; then
  cp make/osx.mk config.mk
  export OPENMP_OPT=0
  # On macOS, jemalloc defaults to JEMALLOC_PREFIX: 'je_'
  # for which mxnet source code isn't ready yet.
#  export JEMALLOC_OPT=0
fi

#export BLAS_OPTS="USE_BLAS=$mxnet_blas_impl"
#if [[ "${mxnet_blas_impl}" == "mkl" ]]; then
#  BLAS_OPTS="${BLAS_OPTS} USE_MKLDNN=1 USE_INTEL_PATH=NONE USE_STATIC_MKL=NONE MKLDNN_ROOT=${PREFIX}"
#  export MKLDNNROOT="$PREFIX"
#fi

declare -a _gpu_opts
if [[ ${mxnet_variant_str} =~ .*gpu.* ]]; then
  _gpu_opts+=(USE_CUDA=1)
  _gpu_opts+=(USE_CUDNN=1)
  _gpu_opts+=(USE_CUDA_PATH=/usr/local/cuda-${cudatoolkit_version})
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64/stubs
else
  _gpu_opts+=(USE_CUDA=0)
  _gpu_opts+=(USE_CUDNN=0)
fi

make -j${CPU_COUNT} \
  AR="$AR" \
  CC="$CC" \
  CXX="$CXX" \
  USE_F16C=0 \
  USE_OPENCV=1 \
  USE_BLAS=mkl \
  USE_PROFILER=1 \
#  "${_gpu_opts[@]}" \

  USE_CPP_PACKAGE=1 \
  USE_SIGNAL_HANDLER=1 \
  ADD_CFLAGS="$CFLAGS" \
  ADD_LDFLAGS="$LDFLAGS" \
  USE_OPENMP="$OPENMP_OPT" \
  USE_JEMALLOC="$JEMALLOC_OPT" \
  VERBOSE=${VERBOSE_AT}

mkdir -p $PREFIX/bin
cp bin/* $PREFIX/bin/

mkdir -p $PREFIX/include
cp -rv include/* $PREFIX/include/
rm $PREFIX/include/dmlc
cp -rv 3rdparty/dmlc-core/include/* $PREFIX/include/
cp -rv 3rdparty/tvm/include/* $PREFIX/include/
rm $PREFIX/include/dlpack
cp -rv 3rdparty/dlpack/include/* $PREFIX/include/
rm $PREFIX/include/mkldnn/*
cp -rv 3rdparty/mkldnn/include/* $PREFIX/include/mkldnn/

rm $PREFIX/include/mshadow
mkdir -p $PREFIX/include/mshadow
cp -rv 3rdparty/mshadow/mshadow/* $PREFIX/include/mshadow/

rm $PREFIX/include/nnvm
mkdir -p $PREFIX/include/nnvm
cp -rv 3rdparty/tvm/nnvm/include/nnvm/* $PREFIX/include/nnvm/
# https://github.com/apache/incubator-mxnet/tree/1.0.0/cpp-package
cp -rv cpp-package/include/mxnet-cpp $PREFIX/include/mxnet-cpp

cp -rv lib/* $PREFIX/lib/

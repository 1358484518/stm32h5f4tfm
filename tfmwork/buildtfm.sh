set -e
cd ~/test/tfmwork/trusted-firmware-m
source .venv/bin/activate 2>/dev/null || {
  python3 -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip setuptools wheel
  pip install -e .
}

#rm -rf build_s build_ns  # if restart

cmake -S ../tf-m-tests/tests_reg/spe -B build_s -GNinja \
  -DTFM_PLATFORM=stm/stm32h573i_dk \
  -DTFM_TOOLCHAIN_FILE=$PWD/toolchain_GNUARM.cmake \
  -DCONFIG_TFM_SOURCE_PATH=$PWD \
  -DTFM_PSA_API=ON -DTFM_ISOLATION_LEVEL=1 \
  -DTEST_S=ON -DTEST_NS=ON \
  -DTFM_BL2_LOG_LEVEL=LOG_LEVEL_INFO \
  -DTFM_SPM_LOG_LEVEL=LOG_LEVEL_INFO \
  -DTFM_PARTITION_LOG_LEVEL=LOG_LEVEL_INFO

ninja -C build_s install -j$(nproc)

cmake -S ../tf-m-tests/tests_reg -B build_ns -GNinja \
  -DCONFIG_SPE_PATH=$PWD/build_s/api_ns \
  -DTFM_TOOLCHAIN_FILE=$PWD/build_s/api_ns/cmake/toolchain_ns_GNUARM.cmake

ninja -C build_ns -j$(nproc)

cd build_s/api_ns
chmod +x postbuild.sh regression.sh TFM_UPDATE.sh preprocess.sh
./postbuild.sh $(which arm-none-eabi-gcc)
grep -E '^boot=|^slot0=|^slot1=' TFM_UPDATE.sh

echo "=== 编译完成，接下来手动： ==="
echo "  cd build_s/api_ns && ./regression.sh && ./TFM_UPDATE.sh"

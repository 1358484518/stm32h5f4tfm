#!/usr/bin/env bash
# 推送离线可编译工程到 Gitee
# 用法: ./push_to_gitee.sh [提交说明]

set -euo pipefail

GITEE_URL="https://gitee.com/already_use/trusted-firmware-m.git"
GITEE_REMOTE="gitee"
COMMIT_MSG="${1:-Update workspace}"

WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${WORK_ROOT}"

TFM_ROOT="${WORK_ROOT}/trusted-firmware-m"
LIB_EXT="${TFM_ROOT}/build_s/build-spe/lib/ext"

echo "工作区: ${WORK_ROOT}"

spe_deps_complete() {
  local ext="${1}"
  local lib f
  for lib in qcbor mcuboot cmsis t_cose tf-psa-crypto tf-m-extras; do
    [[ -d "${ext}/${lib}-src" ]] || return 1
  done
  for f in \
    "${ext}/qcbor-src/src/qcbor_encode.c" \
    "${ext}/mcuboot-src/boot/bootutil/src/bootutil_misc.c" \
    "${ext}/tf-psa-crypto-src/CMakeLists.txt"; do
    [[ -f "${f}" ]] || return 1
  done
  return 0
}

if ! spe_deps_complete "${LIB_EXT}"; then
  echo "错误: 离线依赖不完整，请先 ./buildtfm.sh 再推送"
  for lib in qcbor mcuboot cmsis t_cose tf-psa-crypto tf-m-extras; do
    [[ -d "${LIB_EXT}/${lib}-src" ]] && echo "  [OK] ${lib}-src" || echo "  [缺失] ${lib}-src"
  done
  exit 1
fi

echo ">>> 离线依赖检查通过"
du -sh "${LIB_EXT}"/*-src 2>/dev/null | sort -hr || true

if [[ ! -d .git ]]; then
  git init
  git branch -M main
fi

BRANCH="$(git branch --show-current)"
[[ -z "${BRANCH}" ]] && git branch -M main && BRANCH="main"
echo "当前分支: ${BRANCH}"

BACKUP_DIR="${WORK_ROOT}/.git-backup"
mkdir -p "${BACKUP_DIR}"

backup_nested_git() {
  local rel="${1#./}"
  [[ -d "${rel}/.git" ]] || return 0
  local safe_name
  safe_name="$(echo "${rel}" | tr '/' '_')"
  rm -rf "${BACKUP_DIR}/${safe_name}"
  mv "${rel}/.git" "${BACKUP_DIR}/${safe_name}"
  echo "  已备份 ${rel}/.git"
}

echo "处理嵌套 .git ..."
backup_nested_git "trusted-firmware-m"
backup_nested_git "tf-m-tests"
while IFS= read -r -d '' gitdir; do
  parent="$(dirname "${gitdir}")"
  rel="${parent#${WORK_ROOT}/}"
  backup_nested_git "${rel}"
done < <(find trusted-firmware-m/build_s trusted-firmware-m/build_ns \
         -name .git -type d -print0 2>/dev/null || true)

echo ">>> 强制纳入 lib/ext"
git add -f trusted-firmware-m/build_s/build-spe/lib/ext/*-src

if git remote get-url "${GITEE_REMOTE}" >/dev/null 2>&1; then
  git remote set-url "${GITEE_REMOTE}" "${GITEE_URL}"
else
  git remote add "${GITEE_REMOTE}" "${GITEE_URL}"
fi

git add -A

if git diff --cached --quiet; then
  echo "没有需要提交的变更"
else
  echo "即将提交 $(git diff --cached --name-only | wc -l) 个文件"
  git commit -m "${COMMIT_MSG}"
fi

echo "推送到 Gitee ..."
git push -u "${GITEE_REMOTE}" "${BRANCH}"

echo "完成: ${GITEE_URL}"


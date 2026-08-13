#!/usr/bin/env bash
# 提交整个工作区到 Gitee（使用现有 .gitignore，不修改忽略规则）
#
# 用法: ./push_to_gitee.sh [提交说明]

set -euo pipefail

GITEE_URL="https://gitee.com/already_use/trusted-firmware-m.git"
GITEE_REMOTE="gitee"
BRANCH="master"
COMMIT_MSG="${1:-Update workspace}"

WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${WORK_ROOT}"

echo "工作区: ${WORK_ROOT}"

if [[ ! -d .git ]]; then
  git init
  git branch -M "${BRANCH}"
  echo "已初始化 git"
fi

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

if git remote get-url "${GITEE_REMOTE}" >/dev/null 2>&1; then
  git remote set-url "${GITEE_REMOTE}" "${GITEE_URL}"
else
  git remote add "${GITEE_REMOTE}" "${GITEE_URL}"
fi
echo "remote ${GITEE_REMOTE} -> ${GITEE_URL}"

git add -A

if git diff --cached --quiet; then
  echo "没有需要提交的变更"
else
  count="$(git diff --cached --name-only | wc -l)"
  echo "即将提交 ${count} 个文件"
  git commit -m "${COMMIT_MSG}"
fi

echo "推送到 Gitee ..."
git push -u "${GITEE_REMOTE}" "${BRANCH}"

echo ""
echo "完成: ${GITEE_URL}"
echo "嵌套 .git 备份在: ${BACKUP_DIR}/"

#!/usr/bin/env bash
# Stop hook: nhắc (không chặn) khi có thay đổi cấu trúc mà
# docs/repo-structure.md chưa được cập nhật cùng lúc. Xem quy tắc ở CLAUDE.md.
#
# "Thay đổi cấu trúc" = sửa init.rb / config/routes.rb / db/migrate/**, hoặc
# thêm/xoá/đổi tên file trong app/, lib/, test/, config/locales/. Sửa nội dung
# bên trong một file có sẵn thì không tính, nên hook không kêu vặt.
#
# Phạm vi soi đúng nghĩa "cùng commit": còn việc chưa commit thì soi phần chưa
# commit; cây sạch thì soi commit cuối cùng.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

DOC='docs/repo-structure.md'

dirty=$( { git status --porcelain 2>/dev/null; } | grep -v '^$' )

if [ -n "$dirty" ]; then
  # Phần chưa commit: staged + unstaged + chưa track.
  changes=$( { git diff --name-status HEAD 2>/dev/null
               git ls-files --others --exclude-standard 2>/dev/null | sed 's/^/A\t/'
             } )
else
  # Cây sạch → soi commit cuối. Commit gốc (không có parent) thì bỏ qua.
  git rev-parse --verify HEAD~1 >/dev/null 2>&1 || exit 0
  changes=$(git diff --name-status HEAD~1 HEAD 2>/dev/null)
fi

changes=$(printf '%s\n' "$changes" | grep -v '^[[:space:]]*$')
[ -n "$changes" ] || exit 0

# Doc nằm trong cùng phạm vi thay đổi → coi như đã đồng bộ.
printf '%s\n' "$changes" | cut -f2- | tr '\t' '\n' | grep -qxF "$DOC" && exit 0

structural=$(printf '%s\n' "$changes" | awk -F'\t' '
  {
    st = substr($1, 1, 1); path = $2
    if (path ~ /^init\.rb$/ || path ~ /^config\/routes\.rb$/ || path ~ /^db\/migrate\//) { print path; next }
    if ((st == "A" || st == "D" || st == "R") && path ~ /^(app|lib|test|config\/locales)\//) { print path }
  }' | sort -u)
[ -n "$structural" ] || exit 0

count=$(printf '%s\n' "$structural" | wc -l | tr -d ' ')
sample=$(printf '%s\n' "$structural" | head -3 | tr '\n' ' ')

jq -nc --arg msg "⚠ $count file cấu trúc đã đổi ($sample…) nhưng $DOC chưa được cập nhật. Quy tắc trong CLAUDE.md: cập nhật bản đồ repo trong cùng commit." \
  '{systemMessage: $msg}'

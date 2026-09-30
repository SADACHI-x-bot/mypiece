#!/bin/bash
# マイピースの配信を GitHub Pages へ押し上げる。
#
# **このアプリ専用。**X自動投稿ともオフィスとも、1本も繋がっていない（社長のご指示
# 2026-10-01「このアプリは完全に別のものとは独立させて」）。
# 触るのは `~/mypiece-feed` と、GitHub の `mypiece` だけ。
#
# **作るのはこちらではない。**相場は `com.jibunnohoseki.prices`（毎日17:30）、
# 天気は `com.jibunnohoseki.weather`（6/12/18時）が作る。
# **ここは出来た物を運ぶだけ。**作る側が失敗した日は、古い物をそのまま置いておく
# （**中途半端に消さない**。アプリ側は「いつ取り込んだか」を自分で出す）。
#
# **黙って失敗しない。**理由は logs/push.log に残る。

set -uo pipefail          # **-e は付けない。**落ちても最後まで記録したい

FEED=/Users/shoma/mypiece-feed
SRC="/Users/shoma/Desktop/Claude Code/アプリ開発部/app"
LOG="$FEED/logs"
mkdir -p "$LOG"
exec >> "$LOG/push.log" 2>&1

echo "$(date '+%F %T') ---- 配信を押し上げる"

cd "$FEED" || { echo "$(date '+%F %T') **置き場が無い: $FEED**"; exit 1; }

# **二重起動よけ。**相場と天気が同じ分に終わることがある
exec 9>"$FEED/.push.lock"
if ! flock -n 9 2>/dev/null; then
  # macOS の bash には flock が無いことがある。**その時は素通りする**
  # （押すのが2回走っても、2本目は「変わっていない」で何もしない）
  :
fi

changed=0
for f in prices.json weather.json; do
  if [ ! -f "$SRC/$f" ]; then
    echo "$(date '+%F %T') **$f が作られていない。飛ばす**（作る側の launchd を見ること）"
    continue
  fi
  # **中身が同じなら触らない。**毎日 1本ずつ空のコミットを積まないため
  if cmp -s "$SRC/$f" "$FEED/$f"; then
    echo "$(date '+%F %T') $f は変わっていない"
  else
    cp "$SRC/$f" "$FEED/$f" && echo "$(date '+%F %T') $f を差し替えた" && changed=1
  fi
done

if [ "$changed" -eq 0 ]; then
  echo "$(date '+%F %T') 押す物が無い。終わる"
  exit 0
fi

git add prices.json weather.json
git -c user.email=mypiece.support@gmail.com -c user.name="My piece" \
    commit -q -m "配信を更新（$(date '+%F %T')）" || {
  echo "$(date '+%F %T') **commit できなかった**"; exit 2; }

if git push -q origin HEAD; then
  echo "$(date '+%F %T') 押し上げた"
else
  echo "$(date '+%F %T') **push できなかった。**次の回でまとめて上がる（記録は手元に残っている）"
  exit 3
fi

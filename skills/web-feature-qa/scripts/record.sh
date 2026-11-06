#!/usr/bin/env bash
# Quay video bằng chứng cho từng testcase bằng ffmpeg.
#
#   record.sh start <case-id> [x y w h]     quay vùng màn hình (mặc định: cả màn hình)
#   record.sh stop  <case-id> [nhãn]        dừng, hậu kỳ ra <case-id>.mp4, in đường dẫn
#   record.sh discard <case-id>             dừng và xoá (case Pass)
#   record.sh fix <vào> <ra.mp4> [nhãn]     làm mượt video screencast của Chrome DevTools MCP
#   record.sh check                         kiểm tra ffmpeg/DISPLAY, in chế độ sẽ dùng
#
# Thư mục làm việc: $QA_OUT (mặc định ./qa-evidence). Cần ffmpeg; chế độ x11grab cần DISPLAY.
set -euo pipefail

OUT="${QA_OUT:-./qa-evidence}"
FPS="${QA_FPS:-15}"
MAXW="${QA_MAXW:-1280}"
mkdir -p "$OUT"

die() { echo "record.sh: $*" >&2; exit 1; }
command -v ffmpeg >/dev/null || die "chưa cài ffmpeg"

encoder() {
  local list; list="$(ffmpeg -hide_banner -encoders 2>/dev/null)"
  for e in libx264 libopenh264 h264_vaapi mpeg4; do
    grep -q " $e " <<<"$list" && { echo "$e"; return; }
  done
  die "không có encoder H.264/MPEG-4"
}

font() {
  local f
  f="$(fc-match -f '%{file}' 'DejaVu Sans' 2>/dev/null || true)"
  [[ -f "$f" ]] || f="$(fc-match -f '%{file}' sans 2>/dev/null || true)"
  echo "$f"
}

screen_size() { # in "WxH" của DISPLAY
  ffprobe -v error -f x11grab -i "$DISPLAY" -show_entries stream=width,height -of csv=s=x:p=0 2>/dev/null | head -1
}

even() { echo $(( $1 / 2 * 2 )); }

# Hậu kỳ: fps cố định, thu nhỏ, gắn nhãn góc trên, MP4 phát được trên web.
finish() { # <vào> <ra> <nhãn>
  local in="$1" out="$2" label="$3" enc vf f txt
  enc="$(encoder)"; f="$(font)"
  vf="fps=${FPS},scale='min(${MAXW},iw)':-2:flags=lanczos"
  if [[ -n "$label" && -n "$f" ]]; then
    txt="$OUT/.label.$$.txt"; printf '%s' "$label" >"$txt"
    vf+=",drawtext=fontfile='${f}':textfile='${txt}':x=12:y=12:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=8"
    vf+=",drawtext=fontfile='${f}':text='%{pts\\:hms}':x=w-tw-12:y=12:fontsize=16:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=6"
  fi
  local q=(-b:v 2500k); [[ "$enc" == libx264 ]] && q=(-crf 26 -preset veryfast)
  ffmpeg -hide_banner -loglevel error -y -i "$in" -vf "$vf" -an -c:v "$enc" "${q[@]}" \
    -pix_fmt yuv420p -movflags +faststart "$out"
  rm -f "${txt:-}"
  echo "$out"
}

stop_raw() { # dừng tiến trình quay của case, trả về file thô
  local id="$1" pidf="$OUT/.$1.pid" pid
  [[ -f "$pidf" ]] || die "case $id chưa start"
  pid="$(cat "$pidf")"
  kill -INT "$pid" 2>/dev/null || true
  for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
  rm -f "$pidf"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    echo "ffmpeg: $(ffmpeg -hide_banner -version | head -1)"
    echo "encoder: $(encoder)"
    echo "font: $(font)"
    if [[ -n "${DISPLAY:-}" ]] && ffmpeg -hide_banner -devices 2>/dev/null | grep -q x11grab && [[ -n "$(screen_size)" ]]; then
      echo "mode: x11grab (DISPLAY=$DISPLAY, màn hình $(screen_size))"
    else
      echo "mode: fallback (dùng screencast_start/stop của MCP rồi 'record.sh fix')"
    fi ;;
  start)
    id="${1:?thiếu case-id}"; [[ -n "${DISPLAY:-}" ]] || die "không có DISPLAY, dùng chế độ fallback"
    [[ -f "$OUT/.$id.pid" ]] && die "case $id đang quay"
    size="$(screen_size)"; [[ -n "$size" ]] || die "không đọc được màn hình $DISPLAY"
    sw="${size%x*}"; sh="${size#*x}"
    x="${2:-0}"; y="${3:-0}"; w="${4:-$sw}"; h="${5:-$sh}"
    (( x < 0 )) && x=0; (( y < 0 )) && y=0
    (( x + w > sw )) && w=$(( sw - x )); (( y + h > sh )) && h=$(( sh - y ))
    w="$(even "$w")"; h="$(even "$h")"
    # Ghi thô MKV (chịu được ngắt giữa chừng), nén nhanh; hậu kỳ ở bước stop.
    nohup ffmpeg -hide_banner -loglevel error -y -f x11grab -draw_mouse 1 -framerate 24 \
      -video_size "${w}x${h}" -i "${DISPLAY}+${x},${y}" \
      -c:v "$(encoder)" -b:v 6000k -pix_fmt yuv420p "$OUT/.$id.raw.mkv" \
      >"$OUT/.$id.log" 2>&1 </dev/null &
    echo $! >"$OUT/.$id.pid"
    sleep 0.5; kill -0 "$(cat "$OUT/.$id.pid")" 2>/dev/null || { cat "$OUT/.$id.log" >&2; die "ffmpeg không chạy"; }
    echo "recording $id ${w}x${h}+${x},${y}" ;;
  stop)
    id="${1:?thiếu case-id}"; label="${2:-$id}"
    stop_raw "$id"
    finish "$OUT/.$id.raw.mkv" "$OUT/$id.mp4" "$label"
    rm -f "$OUT/.$id.raw.mkv" "$OUT/.$id.log" ;;
  discard)
    id="${1:?thiếu case-id}"
    stop_raw "$id"; rm -f "$OUT/.$id.raw.mkv" "$OUT/.$id.log"; echo "discarded $id" ;;
  fix)
    in="${1:?thiếu file vào}"; out="${2:?thiếu file ra}"; finish "$in" "$out" "${3:-}" ;;
  *) sed -n '2,11p' "$0"; exit 2 ;;
esac

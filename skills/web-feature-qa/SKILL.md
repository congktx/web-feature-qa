---
name: web-feature-qa
description: Use when the user gives a website URL plus a feature description, spec or requirements document and wants test case ideas, written test cases, or the feature tested in a real browser with screenshots or video evidence of failures (QA, kiểm thử, testcase, test tính năng web).
---

# Web Feature QA

## Overview

Từ một URL và tài liệu mô tả tính năng, agent mở website bằng Chrome DevTools MCP, brainstorm ý tưởng testcase, ghi vào **một artifact vừa là nơi duyệt testcase vừa là báo cáo**, rồi chạy test và đính kèm ảnh + video cho mọi case Fail/Blocked.

Có **hai điểm dừng bắt buộc** để người dùng quyết định: sau khi có ý tưởng (bước 5) và trước khi chạy test (bước 6). Không gộp, không tự vượt qua.

## Đầu vào

| | |
|---|---|
| **Bắt buộc** | URL website; tài liệu mô tả tính năng (file, text hoặc link) |
| **Không bắt buộc** | Thông tin đăng nhập. **Không hỏi trước.** Chỉ hỏi khi website thực sự đòi đăng nhập (bước 2) |

Thiếu URL hoặc tài liệu: hỏi đúng thứ còn thiếu, rồi dừng.

## Quy trình

### 1. Chuẩn bị
- `bash <skill-dir>/scripts/record.sh check` để biết chế độ quay: `x11grab` (ffmpeg quay màn hình) hay `fallback` (screencast của MCP).
- Tạo thư mục làm việc trong scratchpad: `qa-<slug>/` (chứa `report.html`, `evidence/`). Đặt `QA_OUT=<thư mục>/evidence` cho mọi lệnh `record.sh`.
- Đọc tài liệu mô tả; ghi ra (trong đầu, không ra file) danh sách yêu cầu kiểm chứng được.

### 2. Mở website
- Load các tool `mcp__chrome-devtools__*` bằng ToolSearch. `new_page` với URL, rồi `take_snapshot`.
- **Gặp màn đăng nhập** (form mật khẩu, redirect tới /login, SSO): dừng lại và báo người dùng, đưa 2 lựa chọn:
  1. Gửi tài khoản test để agent điền (`fill_form`);
  2. Tự đăng nhập trong cửa sổ Chrome đang mở, rồi nhắn "tiếp tục".
  CAPTCHA, OTP, 2FA: luôn để người dùng tự làm.
- **Mật khẩu chỉ dùng để điền form.** Không ghi vào file, artifact, db, ghi chú kết quả hay tóm tắt.
- Đi qua các màn hình liên quan đến tính năng (snapshot, tối đa ~10 màn) để biết tên nút, trường, thông báo thực tế.

### 3. Brainstorm ý tưởng testcase
**REQUIRED SUB-SKILL:** gọi skill brainstorming đang có trong phiên (`brainstorming`, `superpowers:brainstorming` hoặc `tiered-agent-kit:brainstorming`). Dùng nó để khai thác ý tưởng, **không** viết spec file hay chuyển sang implementation plan; đầu ra là danh sách ý tưởng ghi vào artifact ở bước 4.

Phủ các nhóm (bỏ nhóm không áp dụng): luồng chính; validation & dữ liệu biên; trạng thái rỗng/lỗi/mất mạng; phân quyền & phiên đăng nhập; hiển thị & responsive; điều hướng (back, reload, deep link); hiệu năng cảm nhận; bảo mật cơ bản (XSS trong input, truy cập URL không quyền). Mỗi ý tưởng: tên dạng hành vi, `idea` 1 câu, ưu tiên P1–P3, nguồn (mục nào trong tài liệu, hoặc "đề xuất thêm" nếu tài liệu không nói tới).

### 4. Tạo artifact báo cáo
1. Copy `<skill-dir>/template/report.html` vào `qa-<slug>/report.html`, sửa `<title>` thành tên báo cáo (vd. "Kiểm thử Giỏ hàng").
2. Publish: `Artifact` với `file_path` đó, `icon: "checklist"`, `capabilities: {"db": {}, "user": {}, "assets": {}}`, một câu `description`.
3. Ghi `meta/project` (`phase: "ideas"`) và các case (`steps: []`) bằng **một** `ArtifactData` `batch` (≤50 entry/lần). Schema và lệnh mẫu: `references/data-model.md`.
4. `ArtifactData` `list` collection `cases` một lần để xác nhận số case đã ghi.

### 5. ⏸ Chờ người dùng duyệt ý tưởng
Gửi link artifact + số ý tưởng theo nhóm. Nói rõ người dùng có thể sửa, xoá, thêm case ngay trên trang, xong thì nhắn lại. **Dừng.** Không viết bước chi tiết trước khi người dùng trả lời.

### 6. Viết testcase chi tiết
- `ArtifactData` `list` `cases` (và `results`). Bỏ case `deleted: true`. Case có `editedBy`/`origin: "user"`: giữ nguyên `title`, `idea` của người dùng.
- Mỗi case: `update` (kèm `if_version`) các trường `pre`, `steps`, `expected`, `tags`. Bước dùng đúng tên nút/trường đã thấy trên trang; `expected` phải quan sát được (text, URL, trạng thái), không viết "hoạt động bình thường".
- Đặt `meta/project.phase = "cases"`.
- ⏸ Báo số case theo ưu tiên, **hỏi có chạy test không** (tất cả, chỉ P1, hay danh sách mã). **Dừng.**

### 7. Chạy test
Đặt `phase = "running"`. Chạy theo thứ tự P1 → P3. Với mỗi case:

1. **Bắt đầu quay.**
   - x11grab: `evaluate_script` → `() => ({x: screenX, y: screenY, w: outerWidth, h: outerHeight, r: devicePixelRatio})`, nhân cả 4 số với `r`, rồi `record.sh start <ID> <x> <y> <w> <h>`. Chỉ quay đúng cửa sổ Chrome; đưa Chrome lên trước (`select_page` với `bringToFront`) trước khi quay.
   - fallback: `screencast_start` với `filePath: <evidence>/<ID>.raw.mp4`.
2. **Thực hiện từng bước** bằng tool MCP (`click`, `fill`, `fill_form`, `press_key`, `navigate_page`, `wait_for`…), dựa trên `take_snapshot` mới nhất.
3. **So với `expected`.** Kiểm tra thêm `list_console_messages` (lỗi) và `list_network_requests` (status ≥ 400) trong lúc chạy case.
4. **Kết luận:**
   - **Pass**: `record.sh discard <ID>` (fallback: `screencast_stop` rồi xoá file). Ghi `results/<ID>` `{status: "pass", actual: <1 câu>, by: "agent"}`.
   - **Fail** (chạy được nhưng sai mong đợi) hoặc **Blocked** (không thực hiện được bước: thiếu dữ liệu, môi trường lỗi, quyền):
     1. `take_screenshot` `filePath: <evidence>/<ID>.png` ngay tại trạng thái lỗi;
     2. `record.sh stop <ID> "<ID> · <tên case>"` → `<evidence>/<ID>.mp4` (fallback: `screencast_stop`, rồi `record.sh fix <ID>.raw.mp4 <ID>.mp4 "<ID> · <tên case>"`);
     3. Upload cả hai: `Artifact` `url: <artifact>`, `asset: true`, `file_paths: [png, mp4]`. Dùng nguyên `id`, `url` trả về;
     4. Ghi `results/<ID>`: `status`, `actual` (thực tế + lỗi console/network liên quan), `media`, `dev: "new"`, `by: "agent"`, `at`.
5. Ghi kết quả **ngay sau mỗi case**, không dồn đến cuối.

Không sửa `expected` cho khớp với hành vi của website. Hành vi lệch tài liệu = Fail, kể cả khi trông hợp lý; ghi nhận xét vào `actual`.

### 8. Kết thúc
Đặt `phase = "done"`. Trả lời ngắn: số Pass/Fail/Blocked, liệt kê mã + tên case Fail/Blocked, link artifact. Nhắc nút "Tạo bản tóm tắt" trên trang để copy vào ticket.

## Lỗi thường gặp

| Sai | Đúng |
|---|---|
| Hỏi tài khoản ngay từ đầu | Chỉ hỏi khi website đòi đăng nhập |
| Viết testcase chi tiết rồi mới cho người dùng xem | Ý tưởng → người dùng duyệt → mới viết chi tiết |
| Tự chạy test ngay sau khi viết testcase | Hỏi trước, chạy đúng phạm vi người dùng chọn |
| Ghi đè `title`/`idea` người dùng đã sửa | `update` chỉ các trường chi tiết, kèm `if_version` |
| Nhúng dữ liệu case vào HTML | Mọi dữ liệu ở db; template giữ nguyên |
| Giữ video của case Pass | `discard`, chỉ giữ bằng chứng cho Fail/Blocked |
| Quay cả màn hình có cửa sổ khác | Truyền toạ độ cửa sổ Chrome cho `record.sh start` |
| Mật khẩu xuất hiện trong `actual` hay tóm tắt | Không bao giờ ghi thông tin đăng nhập |

## Tệp đi kèm
- `template/report.html`: trang báo cáo (lọc, kết quả, trạng thái dev, ảnh/video, sửa/xoá/khôi phục case, tóm tắt Fail/Blocked để copy).
- `scripts/record.sh`: quay bằng ffmpeg x11grab, hậu kỳ (fps cố định, thu nhỏ ≤1280px, nhãn mã case + đồng hồ), làm mượt video screencast. `record.sh` không tham số để xem cách dùng.
- `references/data-model.md`: schema db và lệnh `ArtifactData` mẫu.

# Dữ liệu của artifact báo cáo

Template `template/report.html` không chứa dữ liệu nào. Mọi thứ nằm trong db của artifact; agent đọc/ghi bằng tool `ArtifactData`, người dùng sửa trực tiếp trên trang.

## `meta/project` (1 document)

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `title` | string | Tên báo cáo, ví dụ "Kiểm thử Giỏ hàng" |
| `site` | string | URL website đang test |
| `feature` | string | Tên tính năng |
| `summary` | string | 1–3 câu tóm tắt tài liệu mô tả và phạm vi test |
| `env` | string | Ví dụ "Chrome 1366×768, tài khoản user thường" |
| `phase` | `ideas` \| `cases` \| `running` \| `done` | Bước hiện tại, hiện ở thanh tiến trình |
| `updatedAt` | ISO string | |

## `cases/<ID>`

`<ID>` = mã nhóm + số 2 chữ số: `A01`, `A02`, `B01`… Case do người dùng thêm thường ở nhóm `U`.

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `id` | string | Trùng doc_id |
| `group`, `groupName` | string | `A` / "Luồng chính" |
| `order` | number | Thứ tự trong nhóm |
| `title` | string | Tên ngắn, dạng hành vi cần kiểm tra |
| `idea` | string | Mục tiêu / lý do của case (giai đoạn ý tưởng) |
| `priority` | 1 \| 2 \| 3 | P1 = chặn luồng chính |
| `pre` | string | Tiền điều kiện |
| `steps` | string[] | **Rỗng = còn là ý tưởng** (trang hiện chip "Ý tưởng") |
| `expected` | string | Kết quả mong đợi, kiểm chứng được |
| `tags` | string[] | Ví dụ `validation`, `bảo mật`, `mobile` |
| `origin` | `agent` \| `user` | |
| `deleted` | bool | Người dùng xoá mềm; agent bỏ qua case này |
| `editedBy` | `viewer` | Có nghĩa là người dùng đã sửa: giữ nguyên `title`/`idea` của họ |

## `results/<ID>`

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `status` | `""` \| `pass` \| `fail` \| `blocked` | |
| `actual` | string | Kết quả thực tế + lỗi console/network liên quan |
| `media` | `{id, url, kind: "image"\|"video", cap}[]` | `id`/`url` lấy nguyên văn từ kết quả upload asset |
| `dev` | `""` \| `new` \| `doing` \| `fixed` \| `retest` \| `verified` \| `wontfix` \| `dup` | Người dùng/dev tự đặt; agent chỉ đặt `new` cho case Fail |
| `by` | `agent` \| `viewer` | |
| `at` | ISO string | |

## Mẫu lệnh

Ghi ý tưởng (một `batch`, tối đa 50 entry mỗi lần; document mới không cần `if_version`):

```json
{"action":"batch","url":"<artifact-url>","writes":[
  {"op":"set","collection":"meta","doc_id":"project","data":{"title":"Kiểm thử Đăng nhập","site":"https://example.com","feature":"Đăng nhập","summary":"…","phase":"ideas","updatedAt":"2026-11-06T03:00:00Z"}},
  {"op":"set","collection":"cases","doc_id":"A01","data":{"id":"A01","group":"A","groupName":"Luồng chính","order":1,"title":"Đăng nhập đúng email và mật khẩu","idea":"Luồng thành công, chuyển tới trang chủ","priority":1,"steps":[],"tags":[],"origin":"agent"}}
]}
```

Bổ sung chi tiết cho case đã có (đọc `list` trước để lấy `version`, rồi `update` có `if_version`, chỉ gửi các trường cần thêm):

```json
{"op":"update","collection":"cases","doc_id":"A01","if_version":3,"data":{"pre":"Có tài khoản test đã kích hoạt","steps":["Mở /login","Nhập email, mật khẩu đúng","Bấm Đăng nhập"],"expected":"Chuyển tới /dashboard, hiện tên người dùng ở góc phải"}}
```

Ghi kết quả Fail kèm bằng chứng:

```json
{"op":"set","collection":"results","doc_id":"A03","data":{"status":"fail","actual":"Bấm Đăng nhập không có phản hồi. Console: TypeError … Network: POST /api/login 500","media":[{"id":"<asset id>","url":"<asset url>","kind":"image","cap":"A03 – sau bước 3"},{"id":"<asset id>","url":"<asset url>","kind":"video","cap":"A03 – toàn bộ thao tác"}],"dev":"new","by":"agent","at":"…"}}
```

Nếu `results/<ID>` đã tồn tại (người dùng đã bấm gì đó), đọc nó trước và ghi với `if_version`.

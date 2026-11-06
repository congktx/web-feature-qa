# web-feature-qa

Plugin Claude Code giúp agent kiểm thử một tính năng website từ **URL + tài liệu mô tả**:

1. Mở website bằng Chrome DevTools MCP (báo bạn khi gặp màn đăng nhập).
2. Brainstorm ý tưởng testcase, ghi vào một **artifact báo cáo** trên claude.ai.
3. Chờ bạn sửa / xoá / thêm ý tưởng ngay trên artifact.
4. Viết testcase chi tiết, hỏi trước khi chạy.
5. Chạy test; case Fail/Blocked được chụp màn hình và quay video (ffmpeg), tải lên artifact.

Artifact vừa là nơi duyệt testcase vừa là báo cáo: lọc theo ưu tiên/kết quả/trạng thái dev, xem ảnh/video, tạo bản tóm tắt lỗi để dán vào ticket.

## Yêu cầu

- Claude Code có MCP server `chrome-devtools` (`npx chrome-devtools-mcp@latest`).
- `ffmpeg` (khuyến nghị có `x11grab` và DISPLAY để quay mượt; không có thì dùng screencast của MCP rồi làm mượt bằng ffmpeg).
- Tài khoản claude.ai có Artifact với capability `db` và `assets`.

## Cách dùng

```
/web-feature-qa https://shop.example.com  (đính kèm tài liệu mô tả tính năng)
```

hoặc chỉ cần nói: "Test tính năng giỏ hàng ở https://shop.example.com theo tài liệu này".

## Cấu trúc

```
.claude-plugin/plugin.json
skills/web-feature-qa/
  SKILL.md                  quy trình cho agent
  template/report.html      trang báo cáo (dữ liệu ở db của artifact)
  scripts/record.sh         quay / hậu kỳ video bằng ffmpeg
  references/data-model.md  schema db + lệnh ArtifactData mẫu
```

## Cập nhật plugin

Sửa file, tăng `version` trong `.claude-plugin/plugin.json`, commit, rồi publish lại cho tổ chức (chọn thay thế bản cũ).

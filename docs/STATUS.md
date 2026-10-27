# Trạng thái hiện tại (cuối phiên làm việc đầu tiên)

## Đã hoàn thành VÀ đã chạy kiểm thử thật

- Migration `20261027000001_foundation.sql` chạy trên PostgreSQL 16.
- **Kiểm thử CSDL**: `supabase/tests/10_foundation_tests.sql` (65 khẳng định) và `20_concurrency_test.sh` đều đạt.
  Lưu ý: chạy trên Postgres cục bộ với lớp giả lập tối thiểu của Supabase (`00_supabase_stub.sql`), **chưa chạy trên Supabase thật**.
- **Kiểm thử đơn vị** `tests/unit/validation.test.ts` (10 test) đạt: tuổi, lớp, mật khẩu, phụ huynh, metadata.
- Cú pháp mọi tệp `.ts/.tsx` hợp lệ (esbuild transform).

## Đã viết nhưng CHƯA được build/chạy

Phiên làm việc này **không tải được thư viện npm** (egress proxy từ chối `registry.npmjs.org`), nên:

- `npm install`, `tsc` (kiểm tra kiểu), `vite build`, service worker sinh bởi `vite-plugin-pwa` và toàn bộ giao diện React **chưa được chạy**. Có thể còn lỗi kiểu hoặc lỗi chạy; chưa thử trên trình duyệt, chưa kiểm tra cài đặt PWA.
- Chưa có kiểm thử giao diện/E2E (Playwright), chưa thử luồng đăng ký–đăng nhập với Supabase thật.
- Chưa có tệp khoá `package-lock.json`.

## Chưa làm (các giai đoạn 2–7)

Ngân hàng câu hỏi, chấm đáp án, nhiệm vụ, thành tích, thẻ bài, túi mù, hiệu ứng, quản trị (giao diện), sự kiện, minigame.

## Chưa thực hiện (cần quyền/tài khoản của chủ dự án)

- Chưa tạo repository GitHub, chưa push, chưa tạo dự án Supabase, chưa triển khai. Xem README để tự thực hiện.

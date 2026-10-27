# Wonder Cards – Thế Giới Thẻ Bài Kỳ Diệu

Game sưu tầm thẻ bài kết hợp học tập cho học sinh lớp 1–5. PWA (React + TypeScript + Vite) trên Supabase (PostgreSQL, Auth, RLS).

> **Trạng thái:** mới xong Giai đoạn 1 (nền tảng). Đọc [docs/STATUS.md](docs/STATUS.md) để biết chính xác phần nào đã kiểm thử, phần nào chưa.
> Kiến trúc & lộ trình: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Tài nguyên ảnh: [docs/ASSET_AUDIT.md](docs/ASSET_AUDIT.md).

## Yêu cầu
Node.js ≥ 20, tài khoản [Supabase](https://supabase.com/) (gói miễn phí đủ để thử), Git. Tuỳ chọn: Supabase CLI.

## 1. Chạy trên máy tính
```bash
npm install
cp .env.example .env.local     # điền VITE_SUPABASE_URL và VITE_SUPABASE_ANON_KEY
npm run dev
```
Chỉ dùng khoá **anon**. Không bao giờ đưa khoá `service_role` vào frontend hay GitHub.

## 2. Cấu hình Supabase
1. Tạo project mới trên supabase.com.
2. Mở **SQL Editor**, dán và chạy lần lượt các tệp trong `supabase/migrations/` (hoặc `supabase db push` bằng CLI).
   *Không* chạy `supabase/tests/00_supabase_stub.sql` ở đây – đó là bản giả lập chỉ để test cục bộ.
3. **Authentication → URL Configuration:** đặt *Site URL* là địa chỉ ứng dụng; thêm `<địa chỉ>/dat-lai-mat-khau` vào *Redirect URLs*.
4. **Authentication → Providers → Email:** nên **bật** xác nhận email. Đặt độ dài mật khẩu tối thiểu ≥ 8.
5. Tạo quản trị viên đầu tiên: đăng ký một tài khoản bình thường, rồi chạy trong SQL Editor (quyền cao, chỉ làm thủ công):
   ```sql
   update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'email-cua-ban@example.com');
   ```

## 3. Kiểm thử
```bash
npm test          # kiểm thử đơn vị (tsx + node:test)
npm run typecheck # kiểm tra kiểu TypeScript
npm run test:db   # kiểm thử CSDL – cần Postgres cục bộ (xem dưới)
```
Kiểm thử CSDL cần một Postgres bất kỳ (≥ 14) mà bạn có quyền tạo database:
```bash
PGHOST=localhost PGPORT=5432 PGUSER=postgres PGPASSWORD=... npm run test:db
```
Script tự tạo database tạm, nạp lớp giả lập Supabase, chạy migration, chạy kiểm thử tuần tự và đồng thời, rồi xoá database tạm.

## 4. Tạo repository GitHub
```bash
git remote add origin https://github.com/<tai-khoan>/wonder-cards.git
git push -u origin main
```
Sau đó: bật *Branch protection* cho `main`, làm việc bằng nhánh + Pull Request. CI (`.github/workflows/ci.yml`) tự chạy test, typecheck, build và test CSDL.
Không commit `.env*` (đã có trong `.gitignore`).

## 5. Triển khai
Frontend là tĩnh (`npm run build` → `dist/`): dùng Vercel, Netlify hoặc Cloudflare Pages (đặt hai biến môi trường `VITE_SUPABASE_*`). GitHub Pages dùng được cho giao diện nhưng **không thay được backend** – dữ liệu và Point luôn nằm ở Supabase. Nếu đặt dưới đường dẫn con, đặt `VITE_BASE=/ten-repo/` khi build. PWA cần HTTPS.

## 6. Cập nhật phiên bản
Thêm migration mới (không sửa migration đã chạy), `git push`, chạy migration trên Supabase, rồi deploy frontend. Service worker tự dọn cache cũ.

## 7. Sao lưu & khôi phục
Gói Supabase trả phí có sao lưu tự động. Với mọi gói, có thể tự sao lưu định kỳ:
```bash
pg_dump "postgresql://postgres:<mat-khau>@db.<ref>.supabase.co:5432/postgres" --schema=public -Fc -f backup.dump
pg_restore --clean --if-exists -d "<chuoi-ket-noi-dich>" backup.dump
```
Hãy thử khôi phục vào một database trống trước khi cần dùng thật.

## Cấu trúc
```
src/            giao diện React (pages, components, features, lib)
supabase/       migrations + tests CSDL
tests/unit/     kiểm thử đơn vị
docs/           kiến trúc, trạng thái, kiểm kê ảnh
assets-reference/manifest.json  danh mục ảnh tham khảo (ảnh gốc KHÔNG nằm trong repo)
```

# Kiến trúc Wonder Cards

```
Trình duyệt (React PWA)  ──anon key + JWT──►  Supabase
   │  chỉ ĐỌC dữ liệu của mình (RLS)             ├─ Auth (đăng ký/đăng nhập/khôi phục)
   │  ghi hạn chế: tên, avatar                     ├─ PostgreSQL + RLS + hàm nghiệp vụ
   └─ gọi RPC/Edge Function cho mọi thay đổi Point  └─ Edge Functions (service_role)  ← Giai đoạn 2+
```

## Nguyên tắc bảo vệ Point (đã hiện thực và kiểm thử ở Giai đoạn 1)

| Rủi ro | Biện pháp | Kiểm thử |
|---|---|---|
| Sửa số dư từ trình duyệt | Không GRANT ghi bảng ví/sổ cái cho `authenticated`; chỉ `service_role` gọi `apply_point_transaction` | `10_foundation_tests.sql` |
| Leo thang quyền khi đăng ký | Vai trò/Point/cấp độ không bao giờ đọc từ metadata | idem |
| Cộng/trừ hai lần | Khoá idempotency `(user_id, idempotency_key)` UNIQUE | idem + `20_concurrency_test.sh` |
| Đua yêu cầu làm số dư âm | Khoá hàng ví `FOR UPDATE` + `CHECK (balance >= 0)` | `20_concurrency_test.sh` (8 phiên song song) |
| Sửa lịch sử giao dịch | Trigger chặn UPDATE/DELETE, kể cả quản trị viên | idem |
| Quản trị âm thầm đổi Point/cấu hình | Mọi hàm `admin_*` bắt buộc lý do + ghi `admin_audit_logs` (bất biến) | idem |
| Đổi lớp liên tục | `change_my_grade` giới hạn theo `profile.grade_change_cooldown_days` | idem |
| Xoá dữ liệu trẻ em | `delete_my_account()` xoá theo tầng; cờ xoá chỉ mở trong hàm | idem |

## Lộ trình theo giai đoạn

| GĐ | Nội dung | Trạng thái |
|---|---|---|
| 1 | Nền tảng: auth, hồ sơ, ví Point, sổ cái, cấu hình, audit, PWA | CSDL đã kiểm thử; giao diện đã viết, **chưa build** (xem STATUS.md) |
| 2 | Học tập: ngân hàng câu hỏi, chấm điểm phía máy chủ (Edge Function), 6 chế độ | chưa làm |
| 3 | Point: quy tắc thưởng từ `app_settings`, giới hạn thưởng lặp, chống nhận trùng | lõi đã có; quy tắc thưởng chưa nối |
| 4 | Thẻ bài: thư viện, 10 cấp, kho đồ, sổ sưu tập, thẻ trùng | chưa làm |
| 5 | Túi mù: 6 túi, tỷ lệ, mua + mở nguyên tử, lưu 5 thẻ | chưa làm |
| 6 | Hiệu ứng thẻ/túi, nhiệm vụ, thành tích, cấp độ, sự kiện | chưa làm |
| 7 | Quản trị, tối ưu, bảo mật, tài liệu, triển khai | chưa làm |

## Giả định đã chọn (có thể đổi)

- Độ tuổi chấp nhận: **5–15**; dưới **13** cần email phụ huynh + tuyên bố đồng ý (`consent_status = declared`). Xác minh bằng email phụ huynh (`verified`) là việc của giai đoạn sau; **cần tư vấn pháp lý** về quy định áp dụng (ví dụ luật bảo vệ dữ liệu cá nhân ở Việt Nam, COPPA/GDPR-K nếu có người dùng nước ngoài).
- Đổi lớp: tối thiểu 30 ngày giữa hai lần (cấu hình được).
- Avatar mặc định là emoji (không vướng bản quyền); thay bằng hình gốc ở giai đoạn thẻ bài.
- Cấu hình thưởng nằm ở `app_settings` (khoá `points.reward.*`); chưa có code dùng đến cho tới Giai đoạn 2–3.
- Bảng còn lại trong danh sách 24 bảng đề xuất sẽ được thêm bằng migration ở từng giai đoạn tương ứng.

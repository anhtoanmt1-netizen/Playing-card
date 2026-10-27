-- Kiểm thử tầng CSDL giai đoạn 1. Mỗi lỗi => RAISE EXCEPTION => psql dừng với mã lỗi ≠ 0.
\set ON_ERROR_STOP on
create schema if not exists t;
grant usage on schema t to anon, authenticated, service_role;

create or replace function t.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', u::text, true); execute 'set local role authenticated'; end $$;
create or replace function t.as_anon() returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', '', true); execute 'set local role anon'; end $$;
create or replace function t.as_service() returns void language plpgsql as $$
begin execute 'set local role service_role'; end $$;
create or replace function t.as_root() returns void language plpgsql as $$
begin execute 'reset role'; perform set_config('request.jwt.claim.sub', '', true); end $$;
grant execute on all functions in schema t to anon, authenticated, service_role;

-- expect_fail: câu lệnh PHẢI lỗi (và lỗi chứa chuỗi mong đợi, nếu có)
create or replace function t.expect_fail(sql text, must_contain text default null) returns void language plpgsql as $$
declare msg text;
begin
  begin execute sql; exception when others then get stacked diagnostics msg = message_text;
    if must_contain is not null and position(lower(must_contain) in lower(msg)) = 0 then
      raise exception 'Lỗi không như mong đợi. Cần chứa "%", nhận được: %', must_contain, msg; end if;
    return;
  end;
  raise exception 'Câu lệnh đáng lẽ phải lỗi nhưng đã thành công: %', sql;
end $$;
create or replace function t.eq(label text, actual anyelement, expected anyelement) returns void language plpgsql as $$
begin if actual is distinct from expected then raise exception 'FAIL [%]: nhận % mong đợi %', label, actual, expected; end if; end $$;
grant execute on all functions in schema t to anon, authenticated, service_role;

-- ---------------- Dữ liệu: 3 người chơi + 1 quản trị ----------------
insert into auth.users (id, email, raw_user_meta_data) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.vn', jsonb_build_object('display_name','Bé An','birth_date',(current_date - interval '9 years')::date,'grade',3,'terms_accepted',true,'parent_email','ba.an@x.vn','parent_consent',true)),
 ('bbbbbbbb-0000-0000-0000-000000000002','b@x.vn', jsonb_build_object('display_name','Bé Bình','birth_date',(current_date - interval '7 years')::date,'grade',1,'terms_accepted',true,'parent_email','ba.binh@x.vn','parent_consent',true,
        'role','admin','balance',999999));  -- cố leo thang quyền qua metadata
insert into auth.users (id, email, raw_user_meta_data) values
 ('cccccccc-0000-0000-0000-000000000003','admin@x.vn', jsonb_build_object('display_name','Quản trị','birth_date',(current_date - interval '14 years')::date,'grade',5,'terms_accepted',true));
-- Bé lớn hơn 13 không cần phụ huynh -> OK. Gán quyền admin bằng cách "chính chủ hệ thống" (không qua client).
update public.profiles set role='admin' where id='cccccccc-0000-0000-0000-000000000003';

do $$
declare n int; r record;
begin
  -- 1. Đăng ký tạo hồ sơ + ví
  perform t.eq('profile A', (select count(*) from public.profiles where id='aaaaaaaa-0000-0000-0000-000000000001')::int, 1);
  perform t.eq('wallet A',  (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 0::bigint);
  perform t.eq('consent A', (select consent_status::text from public.profiles where id='aaaaaaaa-0000-0000-0000-000000000001'), 'declared');
  perform t.eq('consent admin>13', (select consent_status::text from public.profiles where id='cccccccc-0000-0000-0000-000000000003'), 'not_required');
  -- metadata không leo thang quyền/Point
  perform t.eq('role không lấy từ metadata', (select role::text from public.profiles where id='bbbbbbbb-0000-0000-0000-000000000002'), 'player');
  perform t.eq('balance không lấy từ metadata', (select balance from public.point_wallets where user_id='bbbbbbbb-0000-0000-0000-000000000002'), 0::bigint);

  -- 2. Đăng ký không hợp lệ bị từ chối
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x1@x.vn', '{"display_name":"A","birth_date":"2017-01-01","grade":2,"terms_accepted":true}')$q$, 'Tên hiển thị');
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x2@x.vn', jsonb_build_object('display_name','Bé Cúc','birth_date',(current_date - interval '9 years')::date,'grade',6,'terms_accepted',true,'parent_email','p@x.vn','parent_consent',true))$q$, 'Lớp học');
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x3@x.vn', jsonb_build_object('display_name','Bé Cúc','birth_date',(current_date - interval '9 years')::date,'grade',3,'terms_accepted',true))$q$, 'phụ huynh');
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x4@x.vn', jsonb_build_object('display_name','Bé Cúc','birth_date',(current_date - interval '9 years')::date,'grade',3,'terms_accepted',false,'parent_email','p@x.vn','parent_consent',true))$q$, 'Điều khoản');
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x5@x.vn', jsonb_build_object('display_name','Ông Cụ','birth_date','1950-01-01','grade',3,'terms_accepted',true))$q$, 'Độ tuổi');
  perform t.expect_fail($q$insert into auth.users(email,raw_user_meta_data) values('x6@x.vn', '{"display_name":"Bé Cúc","birth_date":"không-phải-ngày","grade":3,"terms_accepted":true}')$q$, 'không hợp lệ');
  perform t.eq('đăng ký lỗi không để lại user mồ côi', (select count(*) from auth.users where email like 'x_@x.vn')::int, 0);
end $$;

-- ---------------- RLS & quyền cột ----------------
do $$
declare n int;
begin
  perform t.as_user('aaaaaaaa-0000-0000-0000-000000000001');
  perform t.eq('A chỉ thấy hồ sơ của mình', (select count(*) from public.profiles)::int, 1);
  perform t.eq('A chỉ thấy ví của mình',   (select count(*) from public.point_wallets)::int, 1);
  -- A đổi tên được
  update public.profiles set display_name='Bé An Mới' where id = auth.uid();
  perform t.eq('đổi tên', (select display_name from public.profiles where id = auth.uid()), 'Bé An Mới');
  -- A KHÔNG sửa được cột nhạy cảm / ví / sổ cái
  perform t.expect_fail($q$update public.profiles set role='admin' where id = auth.uid()$q$, 'permission denied');
  perform t.expect_fail($q$update public.profiles set level=99 where id = auth.uid()$q$, 'permission denied');
  perform t.expect_fail($q$update public.profiles set grade=5 where id = auth.uid()$q$, 'permission denied');
  perform t.expect_fail($q$update public.point_wallets set balance=1000000 where user_id = auth.uid()$q$, 'permission denied');
  perform t.expect_fail($q$insert into public.point_transactions(user_id,type,amount,balance_before,balance_after,reason,idempotency_key) values (auth.uid(),'earn_other',100,0,100,'gian lận','cheat-key-0001')$q$, 'permission denied');
  perform t.expect_fail($q$delete from public.point_transactions$q$, 'permission denied');
  -- A không sửa được hồ sơ người khác (RLS lọc => 0 hàng)
  update public.profiles set display_name='Bị hack' where id='bbbbbbbb-0000-0000-0000-000000000002';
  perform t.as_root();
  perform t.eq('B không bị sửa', (select display_name from public.profiles where id='bbbbbbbb-0000-0000-0000-000000000002'), 'Bé Bình');
  -- A không gọi được hàm Point lõi / hàm quản trị
  perform t.as_user('aaaaaaaa-0000-0000-0000-000000000001');
  perform t.expect_fail($q$select public.apply_point_transaction(auth.uid(),'earn_other',500,'tự cộng','self-add-0001')$q$, 'permission denied');
  perform t.expect_fail($q$select public.admin_adjust_points(auth.uid(), 500, 'tự cộng điểm', 'admin-self-0001')$q$, 'quyền quản trị');
  perform t.expect_fail($q$select public.admin_set_account_status('bbbbbbbb-0000-0000-0000-000000000002','locked','thử')$q$, 'quyền quản trị');
  perform t.expect_fail($q$select public.admin_set_setting('points.reward.correct_easy','9999','thử')$q$, 'quyền quản trị');
  perform t.eq('A không đọc được nhật ký quản trị', (select count(*) from public.admin_audit_logs)::int, 0);
  -- Khách (anon)
  perform t.as_anon();
  perform t.expect_fail($q$select * from public.profiles$q$, 'permission denied');
  perform t.expect_fail($q$select * from public.point_wallets$q$, 'permission denied');
  select count(*) into n from public.app_settings; if n = 0 then raise exception 'anon phải đọc được cấu hình công khai'; end if;
  perform t.as_root();
end $$;

-- ---------------- Lõi Point ----------------
do $$
declare tx1 public.point_transactions; tx2 public.point_transactions; tx3 public.point_transactions;
begin
  perform t.as_service();
  tx1 := public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','earn_learning',100,'Trả lời đúng','key-earn-0001','question','q1');
  perform t.eq('số dư sau cộng', (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 100::bigint);
  perform t.eq('before/after', (tx1.balance_before, tx1.balance_after)::text, '(0,100)');
  -- Gửi lại cùng khoá: không cộng lần hai, trả giao dịch cũ
  tx2 := public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','earn_learning',100,'Trả lời đúng','key-earn-0001','question','q1');
  perform t.eq('idempotent id', tx2.id, tx1.id);
  perform t.eq('idempotent số dư', (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 100::bigint);
  perform t.eq('idempotent số dòng sổ cái', (select count(*) from public.point_transactions where user_id='aaaaaaaa-0000-0000-0000-000000000001')::int, 1);
  -- Chi tiêu
  tx3 := public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','spend_blind_bag',-60,'Mua túi','key-spend-0001','bag','khoi_dau');
  perform t.eq('số dư sau chi', (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 40::bigint);
  perform t.eq('lifetime_earned không giảm khi chi', (select lifetime_earned from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 100::bigint);
  -- Không đủ Point
  perform t.expect_fail($q$select public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','spend_blind_bag',-41,'Mua túi','key-spend-0002')$q$, 'Không đủ Point');
  perform t.eq('số dư không đổi khi thất bại', (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 40::bigint);
  -- Dấu số tiền phải khớp loại giao dịch
  perform t.expect_fail($q$select public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','spend_blind_bag',50,'sai dấu','key-sign-0001')$q$, 'tx_sign_matches_type');
  perform t.expect_fail($q$select public.apply_point_transaction('aaaaaaaa-0000-0000-0000-000000000001','earn_learning',0,'số 0','key-zero-0001')$q$, 'không hợp lệ');
  -- Sổ cái bất biến, kể cả với service_role/postgres
  perform t.expect_fail($q$update public.point_transactions set amount=1$q$, 'chỉ được thêm mới');
  perform t.expect_fail($q$delete from public.point_transactions$q$, 'chỉ được thêm mới');
  perform t.as_root();
  perform t.expect_fail($q$update public.point_transactions set amount=1$q$, 'chỉ được thêm mới');
  -- Ví không âm ở mức ràng buộc
  perform t.expect_fail($q$update public.point_wallets set balance=-1$q$, 'check');
  -- Khớp sổ cái và số dư
  perform t.eq('tổng sổ cái = số dư', (select sum(amount) from public.point_transactions where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 40::numeric);
  -- Tài khoản bị khoá không giao dịch được
  update public.profiles set status='locked' where id='bbbbbbbb-0000-0000-0000-000000000002';
  perform t.as_service();
  perform t.expect_fail($q$select public.apply_point_transaction('bbbbbbbb-0000-0000-0000-000000000002','earn_other',10,'quà','key-lock-0001')$q$, 'bị khoá');
  perform t.as_root();
  update public.profiles set status='active' where id='bbbbbbbb-0000-0000-0000-000000000002';
end $$;

-- ---------------- Quản trị ----------------
do $$
declare tx public.point_transactions;
begin
  perform t.as_user('cccccccc-0000-0000-0000-000000000003');
  perform t.eq('admin thấy mọi hồ sơ', (select count(*) from public.profiles)::int, 3);
  perform t.expect_fail($q$select public.admin_adjust_points('aaaaaaaa-0000-0000-0000-000000000001', 50, 'ok', 'adm-key-short')$q$, 'lý do');
  tx := public.admin_adjust_points('aaaaaaaa-0000-0000-0000-000000000001', 50, 'Bồi hoàn lỗi hệ thống', 'adm-key-0001');
  perform t.eq('admin cộng', (select balance from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 90::bigint);
  perform t.eq('admin: lifetime_earned không tăng', (select lifetime_earned from public.point_wallets where user_id='aaaaaaaa-0000-0000-0000-000000000001'), 100::bigint);
  perform t.eq('có nhật ký', (select count(*) from public.admin_audit_logs where action='adjust_points')::int, 1);
  perform t.expect_fail($q$select public.admin_set_account_status(auth.uid(),'locked','tự khoá')$q$, 'tự khoá');
  perform public.admin_set_setting('points.reward.correct_easy','6','cân bằng thử nghiệm');
  perform t.eq('đổi cấu hình', (select value::text from public.app_settings where key='points.reward.correct_easy'), '6');
  perform t.eq('có nhật ký cấu hình', (select count(*) from public.admin_audit_logs where action='set_setting')::int, 1);
  perform t.expect_fail($q$update public.admin_audit_logs set action='x'$q$, 'permission denied');
  perform t.as_root();
  perform t.expect_fail($q$delete from public.admin_audit_logs$q$, 'chỉ được thêm mới');
  -- Admin bị khoá mất quyền
  update public.profiles set status='locked' where id='cccccccc-0000-0000-0000-000000000003';
  perform t.as_user('cccccccc-0000-0000-0000-000000000003');
  perform t.expect_fail($q$select public.admin_adjust_points('aaaaaaaa-0000-0000-0000-000000000001', 50, 'sau khi khoá', 'adm-key-0002')$q$, 'quyền quản trị');
  perform t.as_root();
  update public.profiles set status='active' where id='cccccccc-0000-0000-0000-000000000003';
end $$;

-- ---------------- Đổi lớp có giới hạn ----------------
do $$
declare p public.profiles;
begin
  perform t.as_user('aaaaaaaa-0000-0000-0000-000000000001');
  p := public.change_my_grade(4);
  perform t.eq('đổi lớp lần 1', p.grade::int, 4);
  perform t.expect_fail($q$select public.change_my_grade(5)$q$, 'đổi lớp gần đây');
  perform t.expect_fail($q$select public.change_my_grade(9)$q$, 'từ 1 đến 5');
  p := public.change_my_grade(4);  -- cùng lớp: không lỗi, không đổi mốc thời gian
  perform t.as_root();
  update public.profiles set grade_changed_at = now() - interval '31 days' where id='aaaaaaaa-0000-0000-0000-000000000001';
  perform t.as_user('aaaaaaaa-0000-0000-0000-000000000001');
  p := public.change_my_grade(5);
  perform t.eq('đổi lớp sau hết hạn chờ', p.grade::int, 5);
  perform t.as_root();
end $$;

-- ---------------- Xoá tài khoản (quyền riêng tư) ----------------
do $$
begin
  perform t.as_user('bbbbbbbb-0000-0000-0000-000000000002');
  perform public.delete_my_account();
  perform t.as_root();
  perform t.eq('xoá hồ sơ', (select count(*) from public.profiles where id='bbbbbbbb-0000-0000-0000-000000000002')::int, 0);
  perform t.eq('xoá ví',    (select count(*) from public.point_wallets where user_id='bbbbbbbb-0000-0000-0000-000000000002')::int, 0);
  -- Cờ xoá chỉ có hiệu lực trong giao dịch của hàm: ngoài ra sổ cái vẫn bất biến
  perform t.expect_fail($q$delete from public.point_transactions$q$, 'chỉ được thêm mới');
end $$;

\echo '=== TẤT CẢ KIỂM THỬ TUẦN TỰ ĐẠT ==='

-- =====================================================================
-- Wonder Cards – Migration 0001: Nền tảng (Giai đoạn 1)
-- Bao gồm: profiles, point_wallets, point_transactions, app_settings,
--          admin_audit_logs, RLS, các hàm nghiệp vụ lõi.
--
-- Nguyên tắc:
--  * Trình duyệt KHÔNG được ghi trực tiếp vào Point, cấp độ, vai trò...
--    (không có GRANT ghi + không có policy ghi).
--  * Mọi thay đổi Point đi qua apply_point_transaction() – nguyên tử,
--    idempotent, khoá hàng ví để chống đua (race condition).
--  * point_transactions và admin_audit_logs chỉ được thêm, không sửa/xoá.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Kiểu dữ liệu ----------
create type public.app_role       as enum ('player', 'admin');
create type public.account_status as enum ('active', 'locked');
create type public.consent_status as enum ('not_required', 'declared', 'verified', 'revoked');
create type public.point_tx_type  as enum (
  'earn_learning',      -- Kiếm Point từ học tập
  'earn_mission',       -- Nhận Point từ nhiệm vụ
  'earn_achievement',   -- Nhận Point từ thành tích
  'earn_event',         -- Nhận Point từ sự kiện
  'earn_other',         -- Quà, mốc cấp độ, mốc sưu tập...
  'spend_blind_bag',    -- Chi Point mua túi
  'spend_item',         -- Chi Point sử dụng vật phẩm
  'admin_adjustment'    -- Điều chỉnh bởi quản trị viên
);

-- ---------- Tiện ích ----------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------- app_settings (cấu hình tập trung) ----------
create table public.app_settings (
  key         text primary key,
  value       jsonb       not null,
  description text,
  is_public   boolean     not null default false,  -- true: người chơi được đọc
  updated_by  uuid,
  updated_at  timestamptz not null default now()
);
create trigger trg_app_settings_updated before update on public.app_settings
  for each row execute function public.set_updated_at();

-- ---------- profiles ----------
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  display_name      text not null check (char_length(btrim(display_name)) between 2 and 30),
  avatar_id         text not null default 'avatar_01' check (avatar_id ~ '^[a-z0-9_]{1,40}$'),
  birth_date        date not null,
  grade             smallint not null check (grade between 1 and 5),
  grade_changed_at  timestamptz,
  role              public.app_role       not null default 'player',
  status            public.account_status not null default 'active',
  parent_email      text check (parent_email is null or parent_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  consent_status    public.consent_status not null default 'not_required',
  consent_at        timestamptz,
  level             int    not null default 1 check (level >= 1),
  xp                bigint not null default 0 check (xp >= 0),
  questions_answered int   not null default 0 check (questions_answered >= 0),
  correct_answers   int    not null default 0 check (correct_answers >= 0),
  streak_days       int    not null default 0 check (streak_days >= 0),
  last_study_date   date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (correct_answers <= questions_answered)
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------- point_wallets ----------
create table public.point_wallets (
  user_id         uuid primary key references public.profiles (id) on delete cascade,
  balance         bigint not null default 0 check (balance >= 0),   -- không bao giờ âm
  lifetime_earned bigint not null default 0 check (lifetime_earned >= 0),
  updated_at      timestamptz not null default now()
);

-- ---------- point_transactions (sổ cái, chỉ thêm) ----------
create table public.point_transactions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  type            public.point_tx_type not null,
  amount          bigint not null check (amount <> 0),
  balance_before  bigint not null check (balance_before >= 0),
  balance_after   bigint not null check (balance_after >= 0),
  reason          text   not null check (char_length(reason) between 1 and 300),
  idempotency_key text   not null check (char_length(idempotency_key) between 8 and 200),
  ref_type        text,
  ref_id          text,
  status          text   not null default 'completed' check (status = 'completed'),
  created_at      timestamptz not null default now(),
  constraint tx_balance_math check (balance_after = balance_before + amount),
  constraint tx_sign_matches_type check (
    (type in ('spend_blind_bag','spend_item') and amount < 0)
    or (type in ('earn_learning','earn_mission','earn_achievement','earn_event','earn_other') and amount > 0)
    or type = 'admin_adjustment'
  ),
  constraint tx_idempotent unique (user_id, idempotency_key)
);
create index idx_point_tx_user_time on public.point_transactions (user_id, created_at desc);

-- Chặn sửa/xoá sổ cái. Chỉ cho xoá khi xoá tài khoản (cờ cục bộ do delete_my_account đặt).
create or replace function public.protect_append_only() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' and current_setting('app.allow_account_erasure', true) = 'on' then
    return old;
  end if;
  raise exception 'Bảng % chỉ được thêm mới, không được sửa hoặc xoá', tg_table_name
    using errcode = 'insufficient_privilege';
end $$;

create trigger trg_point_tx_append_only
  before update or delete on public.point_transactions
  for each row execute function public.protect_append_only();

-- ---------- admin_audit_logs (chỉ thêm) ----------
create table public.admin_audit_logs (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid not null,        -- không FK: nhật ký phải tồn tại cả khi tài khoản bị xoá
  action      text not null,
  target_type text,
  target_id   text,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index idx_audit_time on public.admin_audit_logs (created_at desc);
create trigger trg_audit_append_only
  before update or delete on public.admin_audit_logs
  for each row execute function public.protect_append_only();

-- ---------- Hàm phân quyền ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.status = 'active'
  );
$$;

-- ---------- Tạo hồ sơ + ví khi đăng ký ----------
-- Dữ liệu khai báo lấy từ raw_user_meta_data (người dùng tự khai).
-- Vai trò, Point, cấp độ KHÔNG BAO GIỜ lấy từ metadata.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  m          jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_name     text  := btrim(coalesce(m->>'display_name', ''));
  v_birth    date;
  v_grade    int;
  v_age      int;
  v_parent   text  := nullif(btrim(coalesce(m->>'parent_email', '')), '');
  v_consent  boolean := coalesce((m->>'terms_accepted')::boolean, false);
  v_parent_ok boolean := coalesce((m->>'parent_consent')::boolean, false);
  v_status   public.consent_status := 'not_required';
begin
  begin
    v_birth := (m->>'birth_date')::date;
    v_grade := (m->>'grade')::int;
  exception when others then
    raise exception 'Thông tin ngày sinh hoặc lớp học không hợp lệ';
  end;

  if v_name = '' or char_length(v_name) not between 2 and 30 then
    raise exception 'Tên hiển thị phải từ 2 đến 30 ký tự';
  end if;
  if v_birth is null or v_grade is null then
    raise exception 'Cần khai báo ngày sinh và lớp học';
  end if;
  if v_grade not between 1 and 5 then
    raise exception 'Lớp học phải từ 1 đến 5';
  end if;

  v_age := extract(year from age(current_date, v_birth))::int;
  if v_age < 5 or v_age > 15 then
    raise exception 'Độ tuổi chưa phù hợp với trò chơi (5–15 tuổi)';
  end if;
  if not v_consent then
    raise exception 'Cần đồng ý Điều khoản sử dụng và Chính sách quyền riêng tư';
  end if;

  -- Dưới 13 tuổi: cần email phụ huynh và xác nhận đã có sự đồng ý của phụ huynh.
  if v_age < 13 then
    if v_parent is null or not v_parent_ok then
      raise exception 'Bé dưới 13 tuổi cần email phụ huynh và sự đồng ý của phụ huynh';
    end if;
    v_status := 'declared';  -- Giai đoạn sau: gửi email xác minh để chuyển sang 'verified'
  end if;

  insert into public.profiles (id, display_name, birth_date, grade, parent_email, consent_status, consent_at)
  values (new.id, v_name, v_birth, v_grade::smallint,
          case when v_age < 13 then v_parent else null end,
          v_status,
          case when v_age < 13 then now() else null end);

  insert into public.point_wallets (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Lõi Point: cộng/trừ nguyên tử và idempotent ----------
-- Chỉ service_role (Edge Function) và các hàm security definer khác được gọi.
create or replace function public.apply_point_transaction(
  p_user_id         uuid,
  p_type            public.point_tx_type,
  p_amount          bigint,
  p_reason          text,
  p_idempotency_key text,
  p_ref_type        text default null,
  p_ref_id          text default null
) returns public.point_transactions
language plpgsql security definer set search_path = public as $$
declare
  v_wallet public.point_wallets;
  v_tx     public.point_transactions;
  v_status public.account_status;
begin
  if p_amount is null or p_amount = 0 then
    raise exception 'Số Point không hợp lệ' using errcode = '22023';
  end if;

  -- Khoá hàng ví: các yêu cầu đồng thời của cùng người chơi được xếp hàng.
  select * into v_wallet from public.point_wallets where user_id = p_user_id for update;
  if not found then
    raise exception 'Không tìm thấy ví Point' using errcode = 'no_data_found';
  end if;

  -- Gửi lại cùng khoá => trả về giao dịch cũ, không cộng/trừ lần nữa.
  select * into v_tx from public.point_transactions
   where user_id = p_user_id and idempotency_key = p_idempotency_key;
  if found then
    return v_tx;
  end if;

  select status into v_status from public.profiles where id = p_user_id;
  if v_status <> 'active' then
    raise exception 'Tài khoản đang bị khoá' using errcode = 'insufficient_privilege';
  end if;

  if v_wallet.balance + p_amount < 0 then
    raise exception 'Không đủ Point' using errcode = 'check_violation';
  end if;

  insert into public.point_transactions
    (user_id, type, amount, balance_before, balance_after, reason, idempotency_key, ref_type, ref_id)
  values
    (p_user_id, p_type, p_amount, v_wallet.balance, v_wallet.balance + p_amount,
     p_reason, p_idempotency_key, p_ref_type, p_ref_id)
  returning * into v_tx;

  update public.point_wallets
     set balance         = balance + p_amount,
         lifetime_earned = lifetime_earned + greatest(p_amount, 0)
                           * (case when p_type = 'admin_adjustment' then 0 else 1 end),
         updated_at      = now()
   where user_id = p_user_id;

  return v_tx;
end $$;

-- ---------- Đổi lớp có giới hạn tần suất ----------
create or replace function public.change_my_grade(p_new_grade int) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_p        public.profiles;
  v_cooldown int  := coalesce((select (value #>> '{}')::int from public.app_settings
                                where key = 'profile.grade_change_cooldown_days'), 30);
begin
  if v_uid is null then raise exception 'Chưa đăng nhập' using errcode = 'insufficient_privilege'; end if;
  if p_new_grade is null or p_new_grade not between 1 and 5 then
    raise exception 'Lớp học phải từ 1 đến 5';
  end if;
  select * into v_p from public.profiles where id = v_uid for update;
  if v_p.grade = p_new_grade then return v_p; end if;
  if v_p.grade_changed_at is not null
     and v_p.grade_changed_at > now() - make_interval(days => v_cooldown) then
    raise exception 'Bé mới đổi lớp gần đây. Vui lòng thử lại sau % ngày.',
      ceil(extract(epoch from (v_p.grade_changed_at + make_interval(days => v_cooldown) - now())) / 86400)::int;
  end if;
  update public.profiles set grade = p_new_grade::smallint, grade_changed_at = now()
   where id = v_uid returning * into v_p;
  return v_p;
end $$;

-- ---------- Quản trị (luôn ghi nhật ký) ----------
create or replace function public.admin_adjust_points(
  p_target uuid, p_amount bigint, p_reason text, p_idempotency_key text
) returns public.point_transactions
language plpgsql security definer set search_path = public as $$
declare v_tx public.point_transactions;
begin
  if not public.is_admin() then
    raise exception 'Không có quyền quản trị' using errcode = 'insufficient_privilege';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 5 then
    raise exception 'Cần ghi rõ lý do điều chỉnh (tối thiểu 5 ký tự)';
  end if;
  v_tx := public.apply_point_transaction(p_target, 'admin_adjustment', p_amount,
            'Quản trị viên: ' || btrim(p_reason), p_idempotency_key, 'admin', auth.uid()::text);
  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (auth.uid(), 'adjust_points', 'user', p_target::text,
          jsonb_build_object('amount', p_amount, 'reason', p_reason, 'tx_id', v_tx.id));
  return v_tx;
end $$;

create or replace function public.admin_set_account_status(
  p_target uuid, p_status public.account_status, p_reason text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Không có quyền quản trị' using errcode = 'insufficient_privilege';
  end if;
  if p_target = auth.uid() then
    raise exception 'Không thể tự khoá tài khoản của chính mình';
  end if;
  update public.profiles set status = p_status where id = p_target;
  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (auth.uid(), 'set_account_status', 'user', p_target::text,
          jsonb_build_object('status', p_status, 'reason', p_reason));
end $$;

create or replace function public.admin_set_setting(
  p_key text, p_value jsonb, p_reason text
) returns void
language plpgsql security definer set search_path = public as $$
declare v_old jsonb;
begin
  if not public.is_admin() then
    raise exception 'Không có quyền quản trị' using errcode = 'insufficient_privilege';
  end if;
  select value into v_old from public.app_settings where key = p_key;
  if not found then raise exception 'Không có cấu hình %', p_key; end if;
  update public.app_settings set value = p_value, updated_by = auth.uid() where key = p_key;
  insert into public.admin_audit_logs (admin_id, action, target_type, target_id, details)
  values (auth.uid(), 'set_setting', 'setting', p_key,
          jsonb_build_object('old', v_old, 'new', p_value, 'reason', p_reason));
end $$;

-- ---------- Quyền xoá dữ liệu cá nhân (quyền riêng tư trẻ em) ----------
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'Chưa đăng nhập' using errcode = 'insufficient_privilege'; end if;
  perform set_config('app.allow_account_erasure', 'on', true);  -- chỉ trong giao dịch này
  delete from auth.users where id = auth.uid();                 -- cascade: profiles, ví, giao dịch
  perform set_config('app.allow_account_erasure', 'off', true); -- đóng ngay cửa sổ xoá
end $$;

-- =====================================================================
-- ROW LEVEL SECURITY + GRANT
-- =====================================================================
alter table public.profiles          enable row level security;
alter table public.point_wallets     enable row level security;
alter table public.point_transactions enable row level security;
alter table public.app_settings      enable row level security;
alter table public.admin_audit_logs  enable row level security;

-- Thu hồi mặc định, cấp lại tối thiểu.
revoke all on public.profiles, public.point_wallets, public.point_transactions,
              public.app_settings, public.admin_audit_logs from anon, authenticated;

-- service_role (Edge Functions phía máy chủ) cần toàn quyền; khai báo tường minh thay vì dựa vào mặc định.
grant all on public.profiles, public.point_wallets, public.point_transactions,
             public.app_settings, public.admin_audit_logs to service_role;

grant select on public.profiles           to authenticated;
grant select on public.point_wallets      to authenticated;
grant select on public.point_transactions to authenticated;
grant select on public.app_settings       to authenticated, anon;
grant select on public.admin_audit_logs   to authenticated;

-- Người chơi chỉ được sửa tên hiển thị và avatar (cấp cột, không phải cả hàng).
grant update (display_name, avatar_id) on public.profiles to authenticated;

create policy profiles_select_own_or_admin on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy wallets_select_own_or_admin on public.point_wallets
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

create policy tx_select_own_or_admin on public.point_transactions
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

create policy settings_select_public on public.app_settings
  for select to anon, authenticated using (is_public or public.is_admin());

create policy audit_select_admin on public.admin_audit_logs
  for select to authenticated using (public.is_admin());

-- Hàm: mặc định PUBLIC được EXECUTE -> thu hồi, rồi cấp từng hàm.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.is_admin()                                         to anon, authenticated;
grant execute on function public.change_my_grade(int)                               to authenticated;
grant execute on function public.delete_my_account()                                to authenticated;
grant execute on function public.admin_adjust_points(uuid, bigint, text, text)      to authenticated;
grant execute on function public.admin_set_account_status(uuid, public.account_status, text) to authenticated;
grant execute on function public.admin_set_setting(text, jsonb, text)               to authenticated;
-- apply_point_transaction: CHỈ service_role (Edge Functions / hàm nội bộ).
grant execute on function public.apply_point_transaction(uuid, public.point_tx_type, bigint, text, text, text, text) to service_role;

-- =====================================================================
-- Cấu hình khởi tạo (quản trị viên chỉnh được qua admin_set_setting)
-- =====================================================================
insert into public.app_settings (key, value, description, is_public) values
 ('points.reward.correct_easy',   '5',   'Point khi trả lời đúng câu cơ bản',  true),
 ('points.reward.correct_medium', '8',   'Point khi trả lời đúng câu trung bình', true),
 ('points.reward.correct_hard',   '12',  'Point khi trả lời đúng câu khó',     true),
 ('points.reward.lesson_complete','20',  'Point khi hoàn thành một bài học',   true),
 ('points.reward.daily_mission',  '30',  'Point khi hoàn thành nhiệm vụ hằng ngày', true),
 ('points.reward.achievement',    '50',  'Point khi hoàn thành một mốc thành tích', true),
 ('points.reward.weekly_mission', '100', 'Point khi hoàn thành thử thách tuần', true),
 ('profile.grade_change_cooldown_days', '30', 'Số ngày tối thiểu giữa hai lần đổi lớp', true);

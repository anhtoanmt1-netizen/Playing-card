#!/usr/bin/env bash
# Kiểm thử đồng thời: nhiều phiên song song không thể làm số dư âm, và cùng một khoá chỉ tính một lần.
set -uo pipefail
U=dddddddd-0000-0000-0000-000000000004
psql -v ON_ERROR_STOP=1 -q -t -A -o /dev/null <<SQL
insert into auth.users (id,email,raw_user_meta_data) values ('$U','c@x.vn',
 jsonb_build_object('display_name','Bé Đồng Thời','birth_date',(current_date - interval '14 years')::date,'grade',5,'terms_accepted',true));
set role service_role;
select 1 from (select public.apply_point_transaction('$U','earn_other',100,'nạp thử','conc-seed-0001')) s;
SQL
# 1) 8 phiên song song, mỗi phiên chi 30 với khoá khác nhau: đúng 3 phiên thành công (3*30=90 <= 100)
ok=0
for i in $(seq 1 8); do
  ( psql -q -t -A -c "set role service_role; select public.apply_point_transaction('$U','spend_blind_bag',-30,'song song $i','conc-spend-000$i')" >/dev/null 2>&1 && echo OK || echo FAIL ) > /tmp/conc_$i.$$ &
done
wait
for i in $(seq 1 8); do grep -q OK /tmp/conc_$i.$$ && ok=$((ok+1)); rm -f /tmp/conc_$i.$$; done
bal=$(psql -q -t -A -c "select balance from public.point_wallets where user_id='$U'")
n=$(psql -q -t -A -c "select count(*) from public.point_transactions where user_id='$U' and type='spend_blind_bag'")
echo "song song/khác khoá: thành công=$ok, số dư=$bal, số dòng chi=$n"
[ "$ok" = 3 ] && [ "$bal" = 10 ] && [ "$n" = 3 ] || { echo "FAIL: đồng thời khác khoá"; exit 1; }
# 2) 8 phiên song song cùng một khoá (người chơi bấm mua nhiều lần): chỉ trừ một lần
psql -q -c "set role service_role; select public.apply_point_transaction('$U','earn_other',200,'nạp','conc-seed-0002')" >/dev/null
for i in $(seq 1 8); do
  psql -q -t -A -c "set role service_role; select public.apply_point_transaction('$U','spend_blind_bag',-50,'bấm nhiều lần','conc-same-key-1')" >/dev/null 2>&1 &
done
wait
bal=$(psql -q -t -A -c "select balance from public.point_wallets where user_id='$U'")
n=$(psql -q -t -A -c "select count(*) from public.point_transactions where user_id='$U' and idempotency_key='conc-same-key-1'")
echo "song song/cùng khoá: số dư=$bal (mong đợi 160), số dòng=$n (mong đợi 1)"
[ "$bal" = 160 ] && [ "$n" = 1 ] || { echo "FAIL: đồng thời cùng khoá"; exit 1; }
# 3) Sổ cái khớp ví
sum=$(psql -q -t -A -c "select sum(amount) from public.point_transactions where user_id='$U'")
[ "$sum" = "$bal" ] || { echo "FAIL: sổ cái ($sum) ≠ ví ($bal)"; exit 1; }
echo "=== KIỂM THỬ ĐỒNG THỜI ĐẠT ==="

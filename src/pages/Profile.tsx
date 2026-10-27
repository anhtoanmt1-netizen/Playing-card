import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../features/auth/AuthProvider';
import { supabase } from '../lib/supabase';
import { AVATARS, TX_LABEL, type PointTx } from '../lib/types';
import { friendlyAuthError } from '../lib/validation';

const PAGE = 20;

export function ProfilePage() {
  const { profile, wallet, refresh, signOut } = useAuth();
  const [name, setName] = useState(profile?.display_name ?? '');
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [txs, setTxs] = useState<PointTx[]>([]);
  const [more, setMore] = useState(false);
  const [loadingTx, setLoadingTx] = useState(true);

  const loadTx = useCallback(async (from: number) => {
    setLoadingTx(true);
    const { data, error } = await supabase.from('point_transactions').select('*')
      .order('created_at', { ascending: false }).range(from, from + PAGE - 1);
    setLoadingTx(false);
    if (error) { setErr(friendlyAuthError(error.message)); return; }
    setTxs((p) => (from === 0 ? (data as PointTx[]) : [...p, ...(data as PointTx[])]));
    setMore((data?.length ?? 0) === PAGE);
  }, []);
  useEffect(() => { void loadTx(0); }, [loadTx]);
  useEffect(() => { if (profile) setName(profile.display_name); }, [profile]);

  if (!profile) return null;
  const flash = (m: string) => { setMsg(m); setErr(''); setTimeout(() => setMsg(''), 3000); };

  async function updateProfile(patch: { display_name?: string; avatar_id?: string }) {
    const { error } = await supabase.from('profiles').update(patch).eq('id', profile!.id);
    if (error) { setErr(friendlyAuthError(error.message)); return; }
    await refresh(); flash('Đã lưu ✔');
  }
  async function changeGrade(g: number) {
    if (g === profile!.grade) return;
    if (!confirm(`Đổi sang lớp ${g}? Bé chỉ đổi lớp được 1 lần mỗi 30 ngày.`)) return;
    const { error } = await supabase.rpc('change_my_grade', { p_new_grade: g });
    if (error) { setErr(friendlyAuthError(error.message)); return; }
    await refresh(); flash('Đã đổi lớp ✔');
  }
  async function deleteAccount() {
    if (!confirm('Xoá vĩnh viễn tài khoản và toàn bộ dữ liệu? Không thể khôi phục.')) return;
    if (prompt('Gõ XOA để xác nhận') !== 'XOA') return;
    const { error } = await supabase.rpc('delete_my_account');
    if (error) { setErr(friendlyAuthError(error.message)); return; }
    await signOut();
  }

  return (
    <div className="home">
      <h1>Hồ sơ</h1>
      {msg && <div className="toast" role="status">{msg}</div>}
      {err && <div className="notice" role="alert">{err}</div>}
      <section className="card">
        <h2>Ảnh đại diện</h2>
        <div className="avatars">
          {Object.entries(AVATARS).map(([id, emo]) => (
            <button key={id} className={'avatar-opt' + (profile.avatar_id === id ? ' on' : '')} aria-pressed={profile.avatar_id === id}
              aria-label={`Chọn ảnh ${emo}`} onClick={() => updateProfile({ avatar_id: id })}>{emo}</button>
          ))}
        </div>
        <label className="field"><span>Tên hiển thị</span>
          <input value={name} maxLength={30} onChange={(e) => setName(e.target.value)} />
        </label>
        <button className="btn btn-primary" disabled={name.trim().length < 2 || name.trim() === profile.display_name}
          onClick={() => updateProfile({ display_name: name.trim() })}>Lưu tên</button>
      </section>
      <section className="card">
        <h2>Lớp học</h2>
        <div className="grades">
          {[1, 2, 3, 4, 5].map((g) => (
            <button key={g} className={'grade' + (profile.grade === g ? ' on' : '')} aria-pressed={profile.grade === g}
              onClick={() => changeGrade(g)}>Lớp {g}</button>
          ))}
        </div>
      </section>
      <section className="card">
        <h2>Lịch sử Point <small>(số dư: {(wallet?.balance ?? 0).toLocaleString('vi-VN')})</small></h2>
        {loadingTx && txs.length === 0 && <div className="spinner" aria-label="Đang tải" />}
        {!loadingTx && txs.length === 0 && <p>Chưa có giao dịch nào. Học bài để kiếm Point đầu tiên nhé!</p>}
        <ul className="txlist">
          {txs.map((t) => (
            <li key={t.id}>
              <div><b>{TX_LABEL[t.type] ?? t.type}</b><br /><small>{t.reason}</small><br />
                <small>{new Date(t.created_at).toLocaleString('vi-VN')} · Mã {t.id.slice(0, 8)}</small></div>
              <div className={t.amount > 0 ? 'plus' : 'minus'}>
                {t.amount > 0 ? '+' : ''}{t.amount.toLocaleString('vi-VN')}
                <small>{t.balance_before} → {t.balance_after}</small>
              </div>
            </li>
          ))}
        </ul>
        {more && <button className="btn btn-ghost" disabled={loadingTx} onClick={() => loadTx(txs.length)}>Xem thêm</button>}
      </section>
      <button className="btn btn-secondary" onClick={() => signOut()}>Đăng xuất</button>
      <button className="btn btn-danger" onClick={deleteAccount}>Xoá tài khoản và dữ liệu</button>
    </div>
  );
}

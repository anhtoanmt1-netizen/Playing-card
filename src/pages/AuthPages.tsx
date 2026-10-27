import { useMemo, useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import {
  calcAge, friendlyAuthError, needsParentConsent, toSignUpMetadata, validatePassword, validateRegistration,
  type RegistrationInput,
} from '../lib/validation';
import { SetupNotice } from './Public';
import { OfflineBanner } from '../components/Layout';

function Field({ label, error, children }: { label: string; error?: string; children: React.ReactNode }) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
      {error && <small className="err" role="alert">{error}</small>}
    </label>
  );
}

export function Register() {
  const nav = useNavigate();
  const [f, setF] = useState<RegistrationInput>({
    displayName: '', email: '', password: '', birthDate: '', grade: null,
    termsAccepted: false, parentEmail: '', parentConsent: false,
  });
  const [errors, setErrors] = useState<ReturnType<typeof validateRegistration>>({});
  const [busy, setBusy] = useState(false);
  const [serverError, setServerError] = useState('');
  const [done, setDone] = useState(false);
  const young = useMemo(() => needsParentConsent(calcAge(f.birthDate)), [f.birthDate]);
  const set = <K extends keyof RegistrationInput>(k: K, v: RegistrationInput[K]) => setF((p) => ({ ...p, [k]: v }));

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;                      // chặn gửi lặp
    const errs = validateRegistration(f);
    setErrors(errs); setServerError('');
    if (Object.keys(errs).length) return;
    setBusy(true);
    const { data, error } = await supabase.auth.signUp({
      email: f.email.trim(), password: f.password,
      options: { data: toSignUpMetadata(f), emailRedirectTo: window.location.origin },
    });
    setBusy(false);
    if (error) { setServerError(friendlyAuthError(error.message)); return; }
    if (data.session) nav('/', { replace: true });  // đã đăng nhập luôn (khi tắt xác minh email)
    else setDone(true);                              // chờ xác minh email
  }

  if (done) {
    return (
      <div className="doc center-text">
        <h1>📬 Kiểm tra email nhé!</h1>
        <p>Mình đã gửi thư xác nhận tới <b>{f.email}</b>. Bấm vào liên kết trong thư để bắt đầu chơi.</p>
        <Link className="btn btn-primary" to="/dang-nhap">Tới trang đăng nhập</Link>
      </div>
    );
  }
  return (
    <form className="doc form" onSubmit={submit} noValidate>
      <OfflineBanner /><SetupNotice />
      <Link to="/welcome" className="back">← Quay lại</Link>
      <h1>Đăng ký</h1>
      <Field label="Tên hiển thị" error={errors.displayName}>
        <input value={f.displayName} onChange={(e) => set('displayName', e.target.value)} maxLength={30} autoComplete="nickname" />
      </Field>
      <Field label="Email" error={errors.email}>
        <input type="email" value={f.email} onChange={(e) => set('email', e.target.value)} autoComplete="email" />
      </Field>
      <Field label="Mật khẩu (ít nhất 8 ký tự, có chữ và số)" error={errors.password}>
        <input type="password" value={f.password} onChange={(e) => set('password', e.target.value)} autoComplete="new-password" />
      </Field>
      <Field label="Ngày sinh" error={errors.birthDate}>
        <input type="date" value={f.birthDate} onChange={(e) => set('birthDate', e.target.value)} max={new Date().toISOString().slice(0, 10)} />
      </Field>
      <fieldset className="field">
        <legend>Bé học lớp mấy?</legend>
        <div className="grades">
          {[1, 2, 3, 4, 5].map((g) => (
            <button key={g} type="button" className={'grade' + (f.grade === g ? ' on' : '')}
              aria-pressed={f.grade === g} onClick={() => set('grade', g)}>Lớp {g}</button>
          ))}
        </div>
        {errors.grade && <small className="err" role="alert">{errors.grade}</small>}
      </fieldset>
      {young && (
        <div className="card soft">
          <b>Dành cho phụ huynh</b>
          <p>Bé dưới 13 tuổi cần có sự đồng ý của phụ huynh hoặc người giám hộ.</p>
          <Field label="Email phụ huynh" error={errors.parentEmail}>
            <input type="email" value={f.parentEmail} onChange={(e) => set('parentEmail', e.target.value)} />
          </Field>
          <label className="check">
            <input type="checkbox" checked={f.parentConsent} onChange={(e) => set('parentConsent', e.target.checked)} />
            <span>Tôi là phụ huynh/người giám hộ và đồng ý cho bé sử dụng Wonder Cards.</span>
          </label>
          {errors.parentConsent && <small className="err" role="alert">{errors.parentConsent}</small>}
        </div>
      )}
      <label className="check">
        <input type="checkbox" checked={f.termsAccepted} onChange={(e) => set('termsAccepted', e.target.checked)} />
        <span>Đồng ý với <Link to="/quyen-rieng-tu">Điều khoản & Quyền riêng tư</Link></span>
      </label>
      {errors.termsAccepted && <small className="err" role="alert">{errors.termsAccepted}</small>}
      {serverError && <div className="notice" role="alert">{serverError}</div>}
      <button className="btn btn-primary" disabled={busy}>{busy ? 'Đang tạo tài khoản…' : 'Tạo tài khoản'}</button>
      <p className="center-text">Đã có tài khoản? <Link to="/dang-nhap">Đăng nhập</Link></p>
    </form>
  );
}

export function Login() {
  const nav = useNavigate();
  const loc = useLocation();
  const from = (loc.state as { from?: string } | null)?.from ?? '/';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true); setError('');
    const { error: err } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    setBusy(false);
    if (err) setError(friendlyAuthError(err.message)); else nav(from, { replace: true });
  }
  return (
    <form className="doc form" onSubmit={submit}>
      <OfflineBanner /><SetupNotice />
      <Link to="/welcome" className="back">← Quay lại</Link>
      <h1>Đăng nhập</h1>
      <Field label="Email"><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required /></Field>
      <Field label="Mật khẩu"><input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required /></Field>
      {error && <div className="notice" role="alert">{error}</div>}
      <button className="btn btn-primary" disabled={busy}>{busy ? 'Đang vào…' : 'Đăng nhập'}</button>
      <p className="center-text"><Link to="/quen-mat-khau">Quên mật khẩu?</Link> · <Link to="/dang-ky">Đăng ký</Link></p>
    </form>
  );
}

export function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true); setError('');
    const { error: err } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/dat-lai-mat-khau`,
    });
    setBusy(false);
    if (err) setError(friendlyAuthError(err.message)); else setSent(true);
  }
  if (sent) return <div className="doc center-text"><h1>📬 Đã gửi thư</h1><p>Nếu email có trong hệ thống, bé sẽ nhận được liên kết đặt lại mật khẩu.</p><Link className="btn btn-primary" to="/dang-nhap">Về đăng nhập</Link></div>;
  return (
    <form className="doc form" onSubmit={submit}>
      <Link to="/dang-nhap" className="back">← Quay lại</Link>
      <h1>Quên mật khẩu</h1>
      <Field label="Email đã đăng ký"><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></Field>
      {error && <div className="notice" role="alert">{error}</div>}
      <button className="btn btn-primary" disabled={busy}>Gửi liên kết</button>
    </form>
  );
}

export function ResetPassword() {
  const nav = useNavigate();
  const [pw, setPw] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    const v = validatePassword(pw);
    if (v) { setError(v); return; }
    setBusy(true); setError('');
    const { error: err } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (err) setError(friendlyAuthError(err.message)); else nav('/', { replace: true });
  }
  return (
    <form className="doc form" onSubmit={submit}>
      <h1>Đặt mật khẩu mới</h1>
      <Field label="Mật khẩu mới"><input type="password" value={pw} onChange={(e) => setPw(e.target.value)} autoComplete="new-password" /></Field>
      {error && <div className="notice" role="alert">{error}</div>}
      <button className="btn btn-primary" disabled={busy}>Lưu mật khẩu</button>
    </form>
  );
}

import { Link } from 'react-router-dom';
import { useAuth } from '../features/auth/AuthProvider';
import { AVATARS } from '../lib/types';

export function Home() {
  const { profile, wallet } = useAuth();
  if (!profile) return <div className="center"><div className="spinner" aria-label="Đang tải" /></div>;
  const acc = profile.questions_answered > 0
    ? Math.round((profile.correct_answers / profile.questions_answered) * 100) : null;
  return (
    <div className="home">
      <header className="hero card">
        <Link to="/ho-so" className="avatar" aria-label="Mở hồ sơ">{AVATARS[profile.avatar_id] ?? '🐱'}</Link>
        <div className="grow">
          <h1>Chào {profile.display_name}!</h1>
          <p>Lớp {profile.grade} · Cấp {profile.level}</p>
        </div>
        <div className="points" aria-label={`Bạn có ${wallet?.balance ?? 0} Point`}>
          <span aria-hidden="true">🪙</span><b>{(wallet?.balance ?? 0).toLocaleString('vi-VN')}</b><small>Point</small>
        </div>
      </header>
      <section className="stats">
        <div className="stat"><b>{profile.streak_days}</b><span>ngày học liên tiếp</span></div>
        <div className="stat"><b>{profile.questions_answered}</b><span>câu đã làm</span></div>
        <div className="stat"><b>{acc === null ? '–' : acc + '%'}</b><span>trả lời đúng</span></div>
      </section>
      <section className="card soft">
        <h2>Sắp có</h2>
        <p>Học tập, túi mù, bộ sưu tập và nhiệm vụ đang được xây dựng ở các giai đoạn tiếp theo.
          Bé đã sẵn sàng với tài khoản và ví Point rồi đó! 🎉</p>
      </section>
      <Link className="btn btn-secondary" to="/ho-so">Hồ sơ & lịch sử Point</Link>
    </div>
  );
}

export function ComingSoon({ title, icon }: { title: string; icon: string }) {
  return (
    <div className="center-col">
      <div className="big-icon" aria-hidden="true">{icon}</div>
      <h1>{title}</h1>
      <p>Tính năng này sẽ có trong bản cập nhật sau.</p>
    </div>
  );
}

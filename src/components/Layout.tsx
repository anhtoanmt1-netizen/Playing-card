import { useEffect, useState } from 'react';
import { NavLink, Outlet, Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../features/auth/AuthProvider';

export function OfflineBanner() {
  const [online, setOnline] = useState(navigator.onLine);
  useEffect(() => {
    const on = () => setOnline(true), off = () => setOnline(false);
    window.addEventListener('online', on); window.addEventListener('offline', off);
    return () => { window.removeEventListener('online', on); window.removeEventListener('offline', off); };
  }, []);
  if (online) return null;
  return <div className="offline" role="status">📡 Đang ngoại tuyến – Point và túi mù cần có mạng để hoạt động</div>;
}

export function RequireAuth() {
  const { session, loading, profile } = useAuth();
  const loc = useLocation();
  if (loading) return <div className="center"><div className="spinner" aria-label="Đang tải" /></div>;
  if (!session) return <Navigate to="/welcome" replace state={{ from: loc.pathname }} />;
  if (profile?.status === 'locked') {
    return <div className="center"><div className="card"><h2>Tài khoản đang tạm khoá</h2><p>Hãy nhờ phụ huynh liên hệ hỗ trợ nhé.</p></div></div>;
  }
  return <AppShell />;
}

const TABS = [
  { to: '/', label: 'Trang chủ', icon: '🏠', end: true },
  { to: '/hoc-tap', label: 'Học tập', icon: '📚' },
  { to: '/cua-hang', label: 'Cửa hàng', icon: '🎁' },
  { to: '/bo-suu-tap', label: 'Bộ sưu tập', icon: '🃏' },
  { to: '/nhiem-vu', label: 'Nhiệm vụ', icon: '⭐' },
];

function AppShell() {
  return (
    <div className="shell">
      <OfflineBanner />
      <main className="page"><Outlet /></main>
      <nav className="tabbar" aria-label="Điều hướng chính">
        {TABS.map((t) => (
          <NavLink key={t.to} to={t.to} end={t.end} className={({ isActive }) => 'tab' + (isActive ? ' active' : '')}>
            <span aria-hidden="true" className="tab-icon">{t.icon}</span>
            <span>{t.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

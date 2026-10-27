import { Route, Routes, Navigate } from 'react-router-dom';
import { AuthProvider } from './features/auth/AuthProvider';
import { RequireAuth } from './components/Layout';
import { About, Guide, Privacy, Welcome } from './pages/Public';
import { ForgotPassword, Login, Register, ResetPassword } from './pages/AuthPages';
import { ComingSoon, Home } from './pages/Home';
import { ProfilePage } from './pages/Profile';

export default function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/welcome" element={<Welcome />} />
        <Route path="/gioi-thieu" element={<About />} />
        <Route path="/huong-dan" element={<Guide />} />
        <Route path="/quyen-rieng-tu" element={<Privacy />} />
        <Route path="/dang-ky" element={<Register />} />
        <Route path="/dang-nhap" element={<Login />} />
        <Route path="/quen-mat-khau" element={<ForgotPassword />} />
        <Route path="/dat-lai-mat-khau" element={<ResetPassword />} />
        <Route element={<RequireAuth />}>
          <Route path="/" element={<Home />} />
          <Route path="/hoc-tap" element={<ComingSoon title="Học tập" icon="📚" />} />
          <Route path="/cua-hang" element={<ComingSoon title="Cửa hàng túi mù" icon="🎁" />} />
          <Route path="/bo-suu-tap" element={<ComingSoon title="Bộ sưu tập" icon="🃏" />} />
          <Route path="/nhiem-vu" element={<ComingSoon title="Nhiệm vụ" icon="⭐" />} />
          <Route path="/ho-so" element={<ProfilePage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}

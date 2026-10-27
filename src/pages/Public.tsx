import { Link, Navigate } from 'react-router-dom';
import { useAuth } from '../features/auth/AuthProvider';
import { isSupabaseConfigured } from '../lib/supabase';
import { OfflineBanner } from '../components/Layout';

export function SetupNotice() {
  if (isSupabaseConfigured) return null;
  return (
    <div className="notice" role="alert">
      ⚙️ Chưa cấu hình Supabase. Hãy tạo tệp <code>.env.local</code> theo <code>.env.example</code> (xem README).
    </div>
  );
}

export function Welcome() {
  const { session, loading } = useAuth();
  if (!loading && session) return <Navigate to="/" replace />;
  return (
    <div className="welcome">
      <OfflineBanner />
      <SetupNotice />
      <img src="/icons/icon-192.png" alt="Logo Wonder Cards" width={120} height={120} className="logo" />
      <h1>Wonder Cards</h1>
      <p className="tagline">Thế Giới Thẻ Bài Kỳ Diệu</p>
      <p>Học thật vui, kiếm Point, mở túi mù và sưu tầm những tấm thẻ đáng yêu!</p>
      <div className="stack">
        <Link className="btn btn-primary" to="/dang-ky">Đăng ký</Link>
        <Link className="btn btn-secondary" to="/dang-nhap">Đăng nhập</Link>
        <Link className="btn btn-ghost" to="/gioi-thieu">Giới thiệu trò chơi</Link>
        <Link className="btn btn-ghost" to="/huong-dan">Hướng dẫn</Link>
      </div>
    </div>
  );
}

export function About() {
  return (
    <div className="doc">
      <Link to="/welcome" className="back">← Quay lại</Link>
      <h1>Giới thiệu trò chơi</h1>
      <p>Wonder Cards là trò chơi học tập dành cho học sinh lớp 1 đến lớp 5. Bé trả lời câu hỏi để kiếm <b>Point</b>,
        dùng Point mua <b>túi mù</b> và sưu tầm thẻ bài có nhiều cấp độ hiếm.</p>
      <p><b>Point là tiền ảo trong game</b>, kiếm được nhờ học tập – không mua bằng tiền thật và không đổi thành tiền.</p>
      <p>Các tính năng học tập, túi mù và sưu tập sẽ được mở dần qua các bản cập nhật.</p>
    </div>
  );
}

export function Guide() {
  return (
    <div className="doc">
      <Link to="/welcome" className="back">← Quay lại</Link>
      <h1>Hướng dẫn</h1>
      <ol>
        <li>Đăng ký tài khoản (bé dưới 13 tuổi cần email và sự đồng ý của phụ huynh).</li>
        <li>Chọn lớp của bé để nhận câu hỏi phù hợp.</li>
        <li>Học mỗi ngày để nhận Point.</li>
        <li>Dùng Point mua túi mù, mỗi túi có 5 thẻ.</li>
        <li>Sưu tầm đủ bộ thẻ để nhận phần thưởng.</li>
      </ol>
      <p>Bé có thể nghỉ ngơi bất cứ lúc nào – không bị phạt khi nghỉ một ngày.</p>
    </div>
  );
}

export function Privacy() {
  return (
    <div className="doc">
      <Link to="/welcome" className="back">← Quay lại</Link>
      <h1>Điều khoản & Quyền riêng tư</h1>
      <p><b>BẢN NHÁP – cần được rà soát bởi người có chuyên môn pháp lý trước khi phát hành.</b></p>
      <ul>
        <li>Chỉ thu thập: tên hiển thị, email, ngày sinh, lớp, và (với bé dưới 13 tuổi) email phụ huynh.</li>
        <li>Không thu thập địa chỉ nhà hay số điện thoại.</li>
        <li>Không hiển thị email hay ngày sinh cho người chơi khác.</li>
        <li>Bé hoặc phụ huynh có thể xoá toàn bộ dữ liệu trong mục Hồ sơ.</li>
      </ul>
    </div>
  );
}

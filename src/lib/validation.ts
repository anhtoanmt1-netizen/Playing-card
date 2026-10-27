// Quy tắc kiểm tra đăng ký – PHẢN ÁNH đúng ràng buộc trong handle_new_user() (supabase/migrations).
// Frontend kiểm tra để báo lỗi sớm, nhưng CSDL mới là nơi quyết định cuối cùng.
export const MIN_AGE = 5;
export const MAX_AGE = 15;
export const PARENT_CONSENT_AGE = 13;
export const GRADES = [1, 2, 3, 4, 5] as const;

export interface RegistrationInput {
  displayName: string;
  email: string;
  password: string;
  birthDate: string; // yyyy-mm-dd
  grade: number | null;
  termsAccepted: boolean;
  parentEmail: string;
  parentConsent: boolean;
}
export type RegistrationErrors = Partial<Record<keyof RegistrationInput, string>>;

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** Tuổi tròn tại ngày `today`; null nếu ngày sinh không hợp lệ hoặc ở tương lai. */
export function calcAge(birthDate: string, today: Date = new Date()): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDate);
  if (!m) return null;
  const y = +m[1], mo = +m[2], d = +m[3];
  const dt = new Date(Date.UTC(y, mo - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return null;
  let age = today.getFullYear() - y;
  const beforeBirthday =
    today.getMonth() + 1 < mo || (today.getMonth() + 1 === mo && today.getDate() < d);
  if (beforeBirthday) age -= 1;
  return age < 0 ? null : age;
}

export function needsParentConsent(age: number | null): boolean {
  return age !== null && age < PARENT_CONSENT_AGE;
}

export function validatePassword(pw: string): string | null {
  if (pw.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
  if (!/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return 'Mật khẩu cần có cả chữ và số';
  return null;
}

export function validateRegistration(i: RegistrationInput, today: Date = new Date()): RegistrationErrors {
  const e: RegistrationErrors = {};
  const name = i.displayName.trim();
  if (name.length < 2 || name.length > 30) e.displayName = 'Tên hiển thị cần từ 2 đến 30 ký tự';
  if (!EMAIL_RE.test(i.email.trim())) e.email = 'Email chưa đúng định dạng';
  const pwErr = validatePassword(i.password);
  if (pwErr) e.password = pwErr;

  const age = calcAge(i.birthDate, today);
  if (age === null) e.birthDate = 'Ngày sinh chưa hợp lệ';
  else if (age < MIN_AGE || age > MAX_AGE) e.birthDate = `Trò chơi dành cho bé từ ${MIN_AGE} đến ${MAX_AGE} tuổi`;

  if (i.grade === null || !GRADES.includes(i.grade as (typeof GRADES)[number])) e.grade = 'Hãy chọn lớp từ 1 đến 5';
  if (!i.termsAccepted) e.termsAccepted = 'Cần đồng ý Điều khoản và Chính sách quyền riêng tư';

  if (needsParentConsent(age)) {
    const pe = i.parentEmail.trim();
    if (!EMAIL_RE.test(pe)) e.parentEmail = 'Bé dưới 13 tuổi cần email của phụ huynh';
    else if (pe.toLowerCase() === i.email.trim().toLowerCase()) e.parentEmail = 'Email phụ huynh cần khác email của bé';
    if (!i.parentConsent) e.parentConsent = 'Cần có sự đồng ý của phụ huynh hoặc người giám hộ';
  }
  return e;
}

/** Dữ liệu gửi vào auth.signUp -> raw_user_meta_data (khớp handle_new_user). Không bao giờ chứa role/Point. */
export function toSignUpMetadata(i: RegistrationInput, today: Date = new Date()) {
  const young = needsParentConsent(calcAge(i.birthDate, today));
  return {
    display_name: i.displayName.trim(),
    birth_date: i.birthDate,
    grade: i.grade,
    terms_accepted: i.termsAccepted,
    ...(young ? { parent_email: i.parentEmail.trim(), parent_consent: i.parentConsent } : {}),
  };
}

/** Việt hoá lỗi thường gặp từ Supabase/Postgres. */
export function friendlyAuthError(message: string): string {
  const m = message.toLowerCase();
  if (m.includes('invalid login')) return 'Email hoặc mật khẩu chưa đúng';
  if (m.includes('already registered') || m.includes('already been registered')) return 'Email này đã được đăng ký';
  if (m.includes('email not confirmed')) return 'Hãy mở email và xác nhận tài khoản trước nhé';
  if (m.includes('rate limit') || m.includes('too many')) return 'Thử lại sau ít phút nhé';
  if (m.includes('failed to fetch') || m.includes('network')) return 'Không có kết nối mạng. Hãy kiểm tra và thử lại';
  // Lỗi nghiệp vụ tiếng Việt do CSDL trả về được giữ nguyên.
  if (/[à-ỹ]/i.test(message)) return message.replace(/^Database error saving new user:?\s*/i, '');
  return 'Có lỗi xảy ra, bé thử lại nhé';
}

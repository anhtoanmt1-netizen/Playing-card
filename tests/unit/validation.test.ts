import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcAge, validateRegistration, toSignUpMetadata, needsParentConsent, friendlyAuthError, type RegistrationInput } from '../../src/lib/validation.ts';

const TODAY = new Date(2026, 9, 27); // 27/10/2026
const base: RegistrationInput = {
  displayName: 'Bé An', email: 'an@example.com', password: 'matkhau123',
  birthDate: '2017-03-15', grade: 3, termsAccepted: true,
  parentEmail: 'mẹ@example.com', parentConsent: true,
};
const ok = { ...base, parentEmail: 'me.an@example.com' };

test('calcAge: trước/sau sinh nhật, năm nhuận, không hợp lệ', () => {
  assert.equal(calcAge('2017-10-27', TODAY), 9);   // đúng sinh nhật
  assert.equal(calcAge('2017-10-28', TODAY), 8);   // ngày mai sinh nhật
  assert.equal(calcAge('2016-02-29', TODAY), 10);
  assert.equal(calcAge('2017-02-30', TODAY), null); // ngày không tồn tại
  assert.equal(calcAge('2030-01-01', TODAY), null); // tương lai
  assert.equal(calcAge('abc', TODAY), null);
});
test('đăng ký hợp lệ', () => assert.deepEqual(validateRegistration(ok, TODAY), {}));
test('tên quá ngắn / quá dài', () => {
  assert.ok(validateRegistration({ ...ok, displayName: 'A' }, TODAY).displayName);
  assert.ok(validateRegistration({ ...ok, displayName: 'x'.repeat(31) }, TODAY).displayName);
  assert.ok(validateRegistration({ ...ok, displayName: '  A  ' }, TODAY).displayName); // cắt khoảng trắng
});
test('mật khẩu', () => {
  assert.ok(validateRegistration({ ...ok, password: 'short1' }, TODAY).password);
  assert.ok(validateRegistration({ ...ok, password: 'chiconchu' }, TODAY).password);
  assert.ok(validateRegistration({ ...ok, password: '12345678' }, TODAY).password);
});
test('độ tuổi 5–15', () => {
  assert.ok(validateRegistration({ ...ok, birthDate: '2024-01-01' }, TODAY).birthDate); // 2 tuổi
  assert.ok(validateRegistration({ ...ok, birthDate: '1990-01-01' }, TODAY).birthDate);
  assert.equal(validateRegistration({ ...ok, birthDate: '2021-10-27' }, TODAY).birthDate, undefined); // đúng 5 tuổi
});
test('lớp 1–5', () => {
  for (const g of [0, 6, null]) assert.ok(validateRegistration({ ...ok, grade: g }, TODAY).grade);
  for (const g of [1, 2, 3, 4, 5]) assert.equal(validateRegistration({ ...ok, grade: g }, TODAY).grade, undefined);
});
test('điều khoản bắt buộc', () => assert.ok(validateRegistration({ ...ok, termsAccepted: false }, TODAY).termsAccepted));
test('dưới 13 tuổi cần phụ huynh; từ 13 thì không', () => {
  assert.equal(needsParentConsent(12), true);
  assert.equal(needsParentConsent(13), false);
  assert.ok(validateRegistration({ ...ok, parentEmail: '' }, TODAY).parentEmail);
  assert.ok(validateRegistration({ ...ok, parentConsent: false }, TODAY).parentConsent);
  assert.ok(validateRegistration({ ...ok, parentEmail: 'an@example.com' }, TODAY).parentEmail); // trùng email của bé
  const teen = { ...ok, birthDate: '2012-01-01', parentEmail: '', parentConsent: false }; // 14 tuổi
  assert.deepEqual(validateRegistration(teen, TODAY), {});
});
test('metadata đăng ký không chứa role/Point/cấp độ', () => {
  const md = toSignUpMetadata(ok, TODAY) as Record<string, unknown>;
  for (const k of ['role', 'balance', 'level', 'xp', 'points']) assert.ok(!(k in md), k);
  assert.equal(md.parent_consent, true);
  const teen = toSignUpMetadata({ ...ok, birthDate: '2012-01-01' }, TODAY) as Record<string, unknown>;
  assert.ok(!('parent_email' in teen));
});
test('lỗi thân thiện', () => {
  assert.equal(friendlyAuthError('Invalid login credentials'), 'Email hoặc mật khẩu chưa đúng');
  assert.equal(friendlyAuthError('User already registered'), 'Email này đã được đăng ký');
  assert.equal(friendlyAuthError('Database error saving new user: Lớp học phải từ 1 đến 5'), 'Lớp học phải từ 1 đến 5');
  assert.equal(friendlyAuthError('boom'), 'Có lỗi xảy ra, bé thử lại nhé');
});

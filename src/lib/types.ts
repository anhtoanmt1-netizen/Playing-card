export interface Profile {
  id: string;
  display_name: string;
  avatar_id: string;
  birth_date: string;
  grade: number;
  role: 'player' | 'admin';
  status: 'active' | 'locked';
  consent_status: 'not_required' | 'declared' | 'verified' | 'revoked';
  level: number;
  xp: number;
  questions_answered: number;
  correct_answers: number;
  streak_days: number;
  created_at: string;
}
export interface Wallet { user_id: string; balance: number; lifetime_earned: number }
export interface PointTx {
  id: string; type: string; amount: number;
  balance_before: number; balance_after: number;
  reason: string; status: string; created_at: string;
}
export const AVATARS: Record<string, string> = {
  avatar_01: '🐱', avatar_02: '🐶', avatar_03: '🐰', avatar_04: '🦊',
  avatar_05: '🐼', avatar_06: '🐸', avatar_07: '🦄', avatar_08: '🐢',
};
export const TX_LABEL: Record<string, string> = {
  earn_learning: 'Học tập', earn_mission: 'Nhiệm vụ', earn_achievement: 'Thành tích',
  earn_event: 'Sự kiện', earn_other: 'Quà tặng', spend_blind_bag: 'Mua túi mù',
  spend_item: 'Dùng vật phẩm', admin_adjustment: 'Điều chỉnh',
};

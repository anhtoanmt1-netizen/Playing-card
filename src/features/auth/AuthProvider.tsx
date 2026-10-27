import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '../../lib/supabase';
import type { Profile, Wallet } from '../../lib/types';

interface AuthState {
  session: Session | null;
  profile: Profile | null;
  wallet: Wallet | null;
  loading: boolean;
  refresh: () => Promise<void>;
  signOut: () => Promise<void>;
}
const Ctx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async (s: Session | null) => {
    if (!s) { setProfile(null); setWallet(null); return; }
    const [p, w] = await Promise.all([
      supabase.from('profiles').select('*').eq('id', s.user.id).maybeSingle(),
      supabase.from('point_wallets').select('*').eq('user_id', s.user.id).maybeSingle(),
    ]);
    // Dữ liệu LUÔN lấy từ máy chủ (RLS chỉ trả về dữ liệu của chính tài khoản này).
    setProfile((p.data as Profile) ?? null);
    setWallet((w.data as Wallet) ?? null);
  }, []);

  useEffect(() => {
    let alive = true;
    supabase.auth.getSession().then(async ({ data }) => {
      if (!alive) return;
      setSession(data.session);
      await load(data.session);
      if (alive) setLoading(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_evt, s) => {
      setSession(s);
      // Đổi/đăng xuất tài khoản: xoá ngay dữ liệu cũ để không lộ dữ liệu của người trước.
      setProfile(null); setWallet(null);
      void load(s);
    });
    return () => { alive = false; sub.subscription.unsubscribe(); };
  }, [load]);

  const refresh = useCallback(() => load(session), [load, session]);
  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    setProfile(null); setWallet(null);
  }, []);

  const value = useMemo(() => ({ session, profile, wallet, loading, refresh, signOut }),
    [session, profile, wallet, loading, refresh, signOut]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth phải nằm trong AuthProvider');
  return v;
}

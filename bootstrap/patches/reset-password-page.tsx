'use client';
import Link from 'next/link';
import { FormEvent, Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';

function ResetPasswordContent(){
  const params=useSearchParams();
  const token=params.get('token')??'';
  const [error,setError]=useState('');
  const [done,setDone]=useState(false);
  const [busy,setBusy]=useState(false);
  async function submit(e:FormEvent<HTMLFormElement>){
    e.preventDefault();
    const d=new FormData(e.currentTarget);
    const p=String(d.get('password')??'');
    const r=String(d.get('repeat')??'');
    if(p!==r){setError('Пароли не совпадают');return;}
    setBusy(true);setError('');
    const res=await fetch('/api/auth/password-reset/confirm',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({token,newPassword:p})});
    const b=await res.json().catch(()=>({}));
    if(res.ok)setDone(true);else setError(b.message??'Ссылка недействительна или устарела');
    setBusy(false);
  }
  return <main className="authShell"><section className="authVisual"><div className="authBrand">M</div><div><p className="eyebrow">МОИ ФИНАНСЫ</p><h1>Новый пароль.<br/>Чистый старт сессий.</h1><p>Финансовые данные сохраняются, меняется только доступ к аккаунту.</p></div><div className="authLandscape"/></section><section className="authPanel">{done?<div className="authCard"><p className="eyebrow">Готово</p><h2>Пароль изменён</h2><p>Все старые сессии завершены. Войдите с новым паролем.</p><Link className="primaryAction" href="/login">Войти</Link></div>:<form className="authCard" onSubmit={submit}><p className="eyebrow">Безопасность</p><h2>Установить новый пароль</h2>{!token&&<div className="formError">В ссылке отсутствует токен восстановления.</div>}<label>Новый пароль<input name="password" type="password" minLength={10} required autoComplete="new-password"/></label><label>Повторите пароль<input name="repeat" type="password" minLength={10} required autoComplete="new-password"/></label>{error&&<div className="formError">{error}</div>}<button className="primaryAction" disabled={busy||!token}>{busy?'Сохраняем…':'Сохранить пароль'}</button><p className="authHint"><Link href="/login">← Ко входу</Link></p></form>}</section></main>;
}

export default function ResetPasswordPage(){
  return <Suspense fallback={<main className="authShell"><section className="authPanel"><div className="authCard"><p>Загружаем…</p></div></section></main>}><ResetPasswordContent/></Suspense>;
}
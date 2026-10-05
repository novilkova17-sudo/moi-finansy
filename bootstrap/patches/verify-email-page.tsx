'use client';
import Link from 'next/link';
import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';

function VerifyEmailContent(){
  const token=useSearchParams().get('token')??'';
  const [state,setState]=useState<'loading'|'ok'|'error'>('loading');
  useEffect(()=>{if(!token){setState('error');return;}fetch('/api/auth/email-verification/confirm',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({token})}).then(r=>setState(r.ok?'ok':'error')).catch(()=>setState('error'));},[token]);
  return <main className="authShell"><section className="authVisual"><div className="authBrand">M</div><div><p className="eyebrow">МОИ ФИНАНСЫ</p><h1>Один аккаунт.<br/>Все ваши устройства.</h1><p>Подтверждённый email нужен для восстановления доступа и защиты аккаунта.</p></div><div className="authLandscape"/></section><section className="authPanel"><div className="authCard"><p className="eyebrow">Email</p><h2>{state==='loading'?'Проверяем ссылку…':state==='ok'?'Email подтверждён':'Не удалось подтвердить email'}</h2><p>{state==='ok'?'Адрес подтверждён. Можно вернуться в приложение.':state==='error'?'Ссылка могла устареть или уже была использована.':'Это займёт несколько секунд.'}</p><Link className="primaryAction" href={state==='ok'?'/settings':'/login'}>{state==='ok'?'Открыть настройки':'Вернуться'}</Link></div></section></main>;
}

export default function VerifyEmailPage(){
  return <Suspense fallback={<main className="authShell"><section className="authPanel"><div className="authCard"><p>Проверяем ссылку…</p></div></section></main>}><VerifyEmailContent/></Suspense>;
}
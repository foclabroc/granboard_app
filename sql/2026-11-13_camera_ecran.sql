-- Foclaboard : caméra d'un écran (tablette) affichée sur un autre écran (TV).
--   • le téléphone qui pilote demande aux 2 écrans de se connecter (état TV
--     « cam ») ; les écrans s'échangent les messages de mise en relation de
--     la vidéo (WebRTC) ici, puis l'image passe en direct par le Wi-Fi,
--     jamais par le serveur
--   • 2 écrans ne se parlent que si le téléphone l'a demandé à tous les deux
-- Relançable. À lancer en postgres APRÈS 2026-11-11_salon_tv.sql et
-- 2026-11-12_en_ligne.sql (gb_config) :
--   psql -U postgres -d postgres -f 2026-11-13_camera_ecran.sql

begin;

create table if not exists public.gb_tv_signals (
  id         bigserial primary key,
  to_code    text not null,
  from_code  text not null,
  msg        jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists gb_tv_signals_to_ix on public.gb_tv_signals (to_code, id);
alter table public.gb_tv_signals owner to rc_owner;
alter sequence public.gb_tv_signals_id_seq owner to rc_owner;
revoke all on public.gb_tv_signals from public, anon, authenticated;
revoke all on sequence public.gb_tv_signals_id_seq from public, anon, authenticated;

-- Un écran envoie un message à un autre écran du même téléphone : id
create or replace function public.gb_tv_signal(p_code text, p_key text, p_to text, p_msg jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_me gb_tv;
  v_to gb_tv;
  v_id bigint;
begin
  select * into v_me from gb_tv
   where code = upper(p_code) and tv_key_hash = gb__sha(coalesce(p_key, ''));
  if v_me.code is null then
    raise exception 'tv_gone';
  end if;
  select * into v_to from gb_tv where code = upper(p_to);
  -- le téléphone qui pilote a demandé la caméra entre ces 2 écrans
  -- (état « cam » {from, to} envoyé avec sa clé à chacun des 2)
  if v_to.code is null or v_to.code = v_me.code or not coalesce(
       (select bool_and(coalesce((c->>'from' = v_me.code and c->>'to' = v_to.code)
                     or (c->>'from' = v_to.code and c->>'to' = v_me.code), false))
          from (values (v_me.state->'cam'), (v_to.state->'cam')) x(c)), false) then
    raise exception 'tv_peer';
  end if;
  if octet_length(p_msg::text) > 16384 then
    raise exception 'too_big';
  end if;
  delete from gb_tv_signals where created_at < now() - interval '5 minutes';
  insert into gb_tv_signals (to_code, from_code, msg)
  values (v_to.code, v_me.code, p_msg) returning id into v_id;
  perform rc__rt_safe(gb__tv_topic(v_to.code), 'gb', jsonb_build_object('sig', v_id));
  return v_id;
end $$;

-- Messages reçus depuis p_since : {last, ice, signals: [{id, from, msg}]}
create or replace function public.gb_tv_signals(p_code text, p_key text, p_since bigint default 0)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_code text;
  v_list jsonb;
begin
  select code into v_code from gb_tv
   where code = upper(p_code) and tv_key_hash = gb__sha(coalesce(p_key, ''));
  if v_code is null then
    return jsonb_build_object('error', 'tv_gone');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'from', from_code, 'msg', msg) order by id), '[]')
    into v_list
    from gb_tv_signals
   where to_code = v_code and id > coalesce(p_since, 0)
     and created_at > now() - interval '5 minutes';
  return jsonb_build_object(
    'last', coalesce((select max(id) from gb_tv_signals where to_code = v_code), 0),
    'ice', coalesce((select value from gb_config where key = 'ice'), '[]'::jsonb),
    'signals', v_list);
end $$;

alter function public.gb_tv_signal(text, text, text, jsonb) owner to rc_owner;
alter function public.gb_tv_signals(text, text, bigint) owner to rc_owner;
grant execute on function public.gb_tv_signal(text, text, text, jsonb) to anon;
grant execute on function public.gb_tv_signals(text, text, bigint) to anon;

commit;

notify pgrst, 'reload schema';

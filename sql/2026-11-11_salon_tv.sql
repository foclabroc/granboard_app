-- GranBoard : salon TV. La TV affiche un code, le téléphone s'y relie et
-- envoie l'état de la partie ; la TV est prévenue par le relais temps réel
-- de Pixel Trade (pg_notify via rc__rt_safe) puis relit l'état.
-- Un téléphone peut piloter plusieurs écrans (TV + tablette) : un salon par écran.
-- Préparé pour le jeu à distance (plusieurs téléphones dans le même salon).
-- Relançable. À lancer en postgres APRÈS 2026-11-11_comptes_stats.sql :
--   psql -U postgres -d postgres -f 2026-11-11_salon_tv.sql

begin;

create table if not exists public.gb_tv (
  code          text primary key,          -- 4 caractères affichés sur la TV
  tv_key_hash   text not null,             -- clé de la TV (lecture)
  host_key_hash text,                      -- clé du téléphone qui pilote
  host_name     text,
  state         jsonb,
  seq           bigint not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.gb_tv add column if not exists tv_name text;  -- « TV », « Tablette »
alter table public.gb_tv owner to rc_owner;
revoke all on public.gb_tv from public, anon, authenticated;

-- Canal du relais pour un salon (même forme que les canaux de Pixel Trade)
create or replace function public.gb__tv_topic(p_code text) returns text
 language sql immutable
 set search_path to 'public'
as $$ select 'rc_' || left(encode(extensions.digest('gbtv|' || p_code, 'sha256'), 'hex'), 24) $$;

-- L'écran ouvre un salon : {code, key, topic}
drop function if exists public.gb_tv_open();
create or replace function public.gb_tv_open(p_name text default null)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_alpha constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_key  text := encode(extensions.gen_random_bytes(16), 'hex');
  i int;
begin
  -- Ménage : salons inactifs depuis 2 jours
  delete from gb_tv where updated_at < now() - interval '2 days';
  loop
    v_code := '';
    for i in 1..4 loop
      v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::int, 1);
    end loop;
    exit when not exists (select 1 from gb_tv where code = v_code);
  end loop;
  insert into gb_tv (code, tv_key_hash, tv_name)
  values (v_code, gb__sha(v_key), left(coalesce(nullif(btrim(p_name), ''), 'Écran'), 20));
  return jsonb_build_object('code', v_code, 'key', v_key, 'topic', gb__tv_topic(v_code));
end $$;

-- Le téléphone se relie avec le code : {code, host_key, name}. Le dernier relié pilote.
create or replace function public.gb_tv_link(p_code text, p_name text default null)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_key  text := encode(extensions.gen_random_bytes(16), 'hex');
  v_name text;
begin
  update gb_tv
     set host_key_hash = gb__sha(v_key),
         host_name = left(btrim(coalesce(p_name, '')), 16),
         state = jsonb_build_object('screen', 'lobby', 'host', left(btrim(coalesce(p_name, '')), 16)),
         seq = seq + 1,
         updated_at = now()
   where code = v_code
  returning coalesce(tv_name, 'Écran') into v_name;
  if v_name is null then
    return jsonb_build_object('error', 'tv_code');
  end if;
  perform rc__rt_safe(gb__tv_topic(v_code), 'gb', jsonb_build_object('seq', 0));
  return jsonb_build_object('code', v_code, 'host_key', v_key, 'name', v_name);
end $$;

-- Le téléphone envoie l'état (128 Ko max) : renvoie le nouveau numéro
create or replace function public.gb_tv_push(p_code text, p_host_key text, p_state jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_seq bigint;
begin
  if octet_length(p_state::text) > 131072 then
    raise exception 'too_big';
  end if;
  update gb_tv
     set state = p_state, seq = seq + 1, updated_at = now()
   where code = upper(p_code) and host_key_hash = gb__sha(coalesce(p_host_key, ''))
  returning seq into v_seq;
  if v_seq is null then
    raise exception 'tv_host';  -- code inconnu ou un autre téléphone a pris la main
  end if;
  perform rc__rt_safe(gb__tv_topic(upper(p_code)), 'gb', jsonb_build_object('seq', v_seq));
  return v_seq;
end $$;

-- La TV lit l'état s'il a changé depuis p_since : {seq, state} ou {seq} seul
create or replace function public.gb_tv_get(p_code text, p_key text, p_since bigint default 0)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v gb_tv;
begin
  select * into v from gb_tv where code = upper(p_code) and tv_key_hash = gb__sha(coalesce(p_key, ''));
  if v.code is null then
    return jsonb_build_object('error', 'tv_gone');
  end if;
  if v.seq <= coalesce(p_since, 0) then
    return jsonb_build_object('seq', v.seq);
  end if;
  return jsonb_build_object('seq', v.seq, 'state', v.state);
end $$;

-- Propriétaire et droits
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'gb\_%tv%'
  loop
    execute format('alter function %s owner to rc_owner', f.sig);
    if f.proname like 'gb\_\_%' then
      execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    else
      execute format('grant execute on function %s to anon', f.sig);
    end if;
  end loop;
end $$;

commit;

notify pgrst, 'reload schema';

select
  (select count(*) from pg_tables where schemaname = 'public' and tablename = 'gb_tv') as table_tv,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('gb_tv_open', 'gb_tv_link', 'gb_tv_push', 'gb_tv_get')) as rpc_tv;

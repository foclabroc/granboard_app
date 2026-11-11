-- GranBoard : photo de profil et son du tour de chaque joueur.
-- Photo = JPEG 256 × 256 en base64, son = un son fourni (id) ou la voix
-- enregistrée du joueur (AAC en base64, 3 s). Le tout dans une table à part
-- pour garder gb_players léger ; `v` augmente à chaque changement (cache).
-- Relançable. À lancer en postgres après les fichiers précédents :
--   psql -U postgres -d postgres -f 2026-11-11_photo_son.sql

begin;

create table if not exists public.gb_media (
  player_id  bigint primary key references public.gb_players (id) on delete cascade,
  photo      text,
  sound      text not null default '',   -- '' = aucun, 'voice' = voix, sinon id d'un son fourni
  voice      text,
  v          int  not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.gb_media owner to rc_owner;
revoke all on public.gb_media from public, anon, authenticated;

-- Compte renvoyé à la connexion : + version des médias et son choisi
create or replace function public.gb__account(p_pid bigint, p_token text) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object('id', p.id, 'pseudo', p.pseudo, 'color', p.color,
                            'token', p_token,
                            'media_v', coalesce(m.v, 0),
                            'sound', coalesce(m.sound, ''))
    from gb_players p left join gb_media m on m.player_id = p.id
   where p.id = p_pid
$$;

-- Photo (null = retirer). JPEG en base64, 80 000 caractères max (~60 Ko).
create or replace function public.gb_set_photo(p_token text, p_photo text)
 returns int
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_v int;
begin
  if p_photo is not null and (length(p_photo) > 80000 or left(p_photo, 4) <> '/9j/') then
    raise exception 'photo';
  end if;
  insert into gb_media (player_id, photo) values (v_pid, p_photo)
  on conflict (player_id) do update
     set photo = excluded.photo, v = gb_media.v + 1, updated_at = now()
  returning v into v_v;
  return v_v;
end $$;

-- Son du tour : '' (aucun), id d'un son fourni, ou 'voice' avec la voix
-- (AAC en base64, 120 000 caractères max ~ 90 Ko). Voix null = garder l'ancienne.
create or replace function public.gb_set_sound(p_token text, p_sound text, p_voice text default null)
 returns int
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_v int; v_s text := coalesce(p_sound, '');
begin
  if v_s !~ '^[a-z0-9_]{0,24}$' then
    raise exception 'sound';
  end if;
  if p_voice is not null and length(p_voice) > 120000 then
    raise exception 'voice';
  end if;
  insert into gb_media (player_id, sound, voice) values (v_pid, v_s, p_voice)
  on conflict (player_id) do update
     set sound = excluded.sound,
         voice = coalesce(excluded.voice, gb_media.voice),
         v = gb_media.v + 1, updated_at = now()
  returning v into v_v;
  if v_s = 'voice' and (select voice from gb_media where player_id = v_pid) is null then
    raise exception 'voice';
  end if;
  return v_v;
end $$;

-- Médias de plusieurs joueurs (32 max). p_known = {"id": version déjà en cache} :
-- seuls les joueurs dont la version a changé sont renvoyés en entier,
-- {"id": {"v", "photo", "sound", "voice"}} (v = 0 : rien).
create or replace function public.gb_media(p_ids bigint[], p_known jsonb default '{}')
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  select coalesce(jsonb_object_agg(p.id::text,
           case when coalesce(m.v, 0) = coalesce((p_known->>(p.id::text))::int, -1)
                then jsonb_build_object('v', coalesce(m.v, 0))
                else jsonb_build_object('v', coalesce(m.v, 0), 'photo', m.photo,
                                        'sound', coalesce(m.sound, ''),
                                        'voice', case when m.sound = 'voice' then m.voice end)
           end), '{}'::jsonb)
    from gb_players p left join gb_media m on m.player_id = p.id
   where p.id = any (p_ids[1:32])
$$;

-- Droits : fonctions à rc_owner, internes fermées, RPC ouvertes à anon
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'gb\_%'
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

-- Contrôle : 3 nouvelles RPC
select count(*) as fonctions_photo_son
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('gb_set_photo', 'gb_set_sound', 'gb_media');

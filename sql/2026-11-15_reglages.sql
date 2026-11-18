-- Foclaboard : sauvegarde des réglages du téléphone sur le compte du profil
-- principal (thème, cible, sons, favoris, réglages des parties, fond d'écran
-- et ses photos), pour les retrouver sur un autre téléphone.
-- Relançable. À lancer en postgres APRÈS 2026-11-11_comptes_stats.sql :
--   psql -U postgres -d postgres -f 2026-11-15_reglages.sql

begin;

create table if not exists public.gb_settings (
  player_id  bigint primary key references public.gb_players(id) on delete cascade,
  data       jsonb not null default '{}',   -- réglages (clé de préférence → valeur)
  walls      jsonb not null default '{}',   -- photos de fond d'écran (nom → JPEG base64)
  v          int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.gb_settings owner to rc_owner;
revoke all on public.gb_settings from anon, authenticated;

-- Enregistre les réglages. p_walls null = photos gardées telles quelles.
create or replace function public.gb_settings_set(p_token text, p_data jsonb, p_walls jsonb default null)
 returns int
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_v int; k text; w jsonb;
begin
  if p_data is null or jsonb_typeof(p_data) <> 'object'
     or octet_length(p_data::text) > 100000 then
    raise exception 'settings';
  end if;
  if p_walls is not null then
    if jsonb_typeof(p_walls) <> 'object'
       or (select count(*) from jsonb_object_keys(p_walls)) > 6 then
      raise exception 'walls';
    end if;
    for k, w in select key, value from jsonb_each(p_walls) loop
      if k !~ '^[A-Za-z0-9_.-]{1,40}$' or jsonb_typeof(w) <> 'string'
         or left(w #>> '{}', 4) <> '/9j/' or length(w #>> '{}') > 700000 then
        raise exception 'walls';
      end if;
    end loop;
  end if;
  insert into gb_settings (player_id, data, walls, v)
  values (v_pid, p_data, coalesce(p_walls, '{}'), 1)
  on conflict (player_id) do update
     set data = excluded.data,
         walls = case when p_walls is null then gb_settings.walls else excluded.walls end,
         v = gb_settings.v + 1, updated_at = now()
  returning v into v_v;
  return v_v;
end $$;

-- Réglages du compte : {v: 0} si rien, {v} si p_known est à jour,
-- sinon {v, at, data, walls}
create or replace function public.gb_settings_get(p_token text, p_known int default -1)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); s gb_settings;
begin
  select * into s from gb_settings where player_id = v_pid;
  if not found then return jsonb_build_object('v', 0); end if;
  if s.v = p_known then
    return jsonb_build_object('v', s.v, 'at', s.updated_at);
  end if;
  return jsonb_build_object('v', s.v, 'at', s.updated_at, 'data', s.data, 'walls', s.walls);
end $$;

alter function public.gb_settings_set(text, jsonb, jsonb) owner to rc_owner;
alter function public.gb_settings_get(text, int) owner to rc_owner;
grant execute on function public.gb_settings_set(text, jsonb, jsonb) to anon;
grant execute on function public.gb_settings_get(text, int) to anon;

commit;

notify pgrst, 'reload schema';

-- Foclaboard : jeu en ligne en double (2 contre 2, une maison par équipe).
--   • le défi part avec 3 joueurs : moi, mon coéquipier (compte ou invité
--     « guest-… ») et l'adversaire ; la partie porte « double: true » et
--     « home » = {id joueur: 'a' (qui défie) | 'b'}
--   • l'adversaire accepte en choisissant son coéquipier : il renvoie la
--     partie complète (4 joueurs) avec gb_on_answer(…, p_game)
--   • le reste ne change pas (salle, journal d'actions, vidéo entre les 2
--     appareils, stats envoyées par chaque appareil pour ses comptes)
-- Relançable. À lancer en postgres APRÈS 2026-11-12_en_ligne.sql :
--   psql -U postgres -d postgres -f 2026-11-13_double.sql

begin;

-- Joueurs d'une partie en ligne : ids uniques, comptes existants ou invités
create or replace function public.gb__on_players_ok(p_game jsonb) returns boolean
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_typeof(p_game->'players') = 'array'
     and (select count(*) = count(distinct e->>'id')
            from jsonb_array_elements(p_game->'players') e)
     and not exists (
       select 1 from jsonb_array_elements(p_game->'players') e
        where e->>'id' not like 'guest-%'
          and not exists (select 1 from gb_players p where p.id::text = e->>'id'))
$$;
alter function public.gb__on_players_ok(jsonb) owner to rc_owner;
revoke all on function public.gb__on_players_ok(jsonb) from public, anon, authenticated;

create or replace function public.gb_on_invite(p_token text, p_to bigint, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v_id bigint;
  v_ids text[];
  v_double boolean := coalesce((p_game->>'double')::boolean, false);
begin
  if p_to is null or p_to = v_pid then
    raise exception 'on_player';
  end if;
  if octet_length(p_game::text) > 65536 or jsonb_typeof(p_game->'players') <> 'array' then
    raise exception 'on_game';
  end if;
  select array_agg(e->>'id' order by e->>'id') into v_ids from jsonb_array_elements(p_game->'players') e;
  if not v_double then
    -- 1 contre 1 : les 2 joueurs de la partie sont bien les 2 comptes
    if v_ids is distinct from (select array_agg(x order by x) from unnest(array[v_pid::text, p_to::text]) x) then
      raise exception 'on_game';
    end if;
  else
    -- Double : moi, mon coéquipier et l'adversaire (son coéquipier à la réponse)
    if coalesce(array_length(v_ids, 1), 0) <> 3
       or not (v_pid::text = any(v_ids) and p_to::text = any(v_ids))
       or not gb__on_players_ok(p_game) then
      raise exception 'on_game';
    end if;
  end if;
  if not gb__on_here(p_to) then
    return jsonb_build_object('error', 'on_offline');
  end if;
  if exists (select 1 from gb_online where player_id = p_to and busy)
     or exists (select 1 from gb_on_invites
                 where to_id = p_to and status = 'pending' and from_id <> v_pid
                   and created_at > now() - interval '45 seconds') then
    return jsonb_build_object('error', 'on_busy');
  end if;
  update gb_on_invites set status = 'cancelled' where from_id = v_pid and status = 'pending';
  insert into gb_on_invites (from_id, to_id, game) values (v_pid, p_to, p_game) returning id into v_id;
  perform gb__on_notify('u' || p_to);
  return jsonb_build_object('id', v_id);
end $$;

-- Réponse à un défi. En double, [p_game] = la partie complétée par celui qui
-- accepte (son coéquipier ajouté) : seuls « players » et « home » changent.
drop function if exists public.gb_on_answer(text, bigint, boolean);
create or replace function public.gb_on_answer(p_token text, p_invite bigint, p_accept boolean,
                                               p_game jsonb default null)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v gb_on_invites;
  v_room bigint;
  v_game jsonb;
begin
  select * into v from gb_on_invites
   where id = p_invite and to_id = v_pid and status = 'pending'
     and created_at > now() - interval '60 seconds'
   for update;
  if v.id is null then
    return jsonb_build_object('error', 'on_gone');
  end if;
  if not coalesce(p_accept, false) then
    update gb_on_invites set status = 'declined' where id = v.id;
    perform gb__on_notify('u' || v.from_id);
    return '{}'::jsonb;
  end if;
  v_game := v.game;
  if coalesce((v.game->>'double')::boolean, false) then
    if p_game is null
       or octet_length(p_game::text) > 65536
       or (p_game - 'players' - 'home') is distinct from (v.game - 'players' - 'home')
       or jsonb_typeof(p_game->'players') <> 'array'
       or jsonb_array_length(p_game->'players') <> 4
       or not gb__on_players_ok(p_game)
       -- les 3 joueurs du défi sont toujours là
       or exists (select 1 from jsonb_array_elements(v.game->'players') e
                   where not exists (select 1 from jsonb_array_elements(p_game->'players') f
                                      where f->>'id' = e->>'id')) then
      raise exception 'on_game';
    end if;
    v_game := p_game;
  end if;
  insert into gb_on_rooms (a_id, b_id, game) values (v.from_id, v_pid, v_game) returning id into v_room;
  update gb_on_invites set status = 'accepted', room_id = v_room where id = v.id;
  update gb_online set busy = true where player_id in (v.from_id, v_pid);
  perform gb__on_notify('u' || v.from_id);
  return jsonb_build_object('room', v_room);
end $$;

alter function public.gb_on_invite(text, bigint, jsonb) owner to rc_owner;
alter function public.gb_on_answer(text, bigint, boolean, jsonb) owner to rc_owner;
grant execute on function public.gb_on_invite(text, bigint, jsonb) to anon, authenticated;
grant execute on function public.gb_on_answer(text, bigint, boolean, jsonb) to anon, authenticated;

commit;

notify pgrst, 'reload schema';

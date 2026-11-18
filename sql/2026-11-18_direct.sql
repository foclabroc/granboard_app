-- Foclaboard : regarder en direct les parties à la maison (pas en ligne).
-- Le téléphone qui joue envoie l'état de la partie (au plus ~1 fois / s) ;
-- n'importe quel joueur du serveur (sauf blocage dans un sens ou l'autre)
-- peut la regarder, comme une partie en ligne. Relançable.
begin;

-- Une partie en direct par compte « hôte » (le 1er compte du téléphone
-- présent dans la partie) ; players = comptes du serveur dans la partie.
create table if not exists public.gb_live (
  owner_id   bigint primary key references public.gb_players(id) on delete cascade,
  players    bigint[] not null default '{}',
  state      jsonb not null,
  seq        int not null default 0,
  updated_at timestamptz not null default now()
);
create index if not exists gb_live_players on public.gb_live using gin (players);
alter table public.gb_live owner to rc_owner;
revoke all on public.gb_live from public, anon, authenticated;

-- Envoi de l'état (p_state null = partie finie ou abandonnée)
create or replace function public.gb_live_push(p_token text, p_state jsonb, p_players bigint[])
 returns int
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_seq int;
begin
  delete from gb_live where updated_at < now() - interval '1 day';
  if p_state is null then
    delete from gb_live where owner_id = v_pid;
    return 0;
  end if;
  if pg_column_size(p_state) > 400000 then raise exception 'live_big'; end if;
  insert into gb_live (owner_id, players, state)
  values (v_pid,
          array(select distinct x from unnest(coalesce(p_players, '{}') || v_pid) x
                 where exists (select 1 from gb_players where id = x)),
          p_state)
  on conflict (owner_id) do update
     set players = excluded.players, state = excluded.state,
         seq = gb_live.seq + 1, updated_at = now()
  returning seq into v_seq;
  return v_seq;
end $$;

-- Regarder : la partie en ligne de p_player, sinon sa partie à la maison
-- (variables v_room / v_live : « r » à la fois variable et alias de table
-- rendait r.a_id ambigu, « Regarder » échouait déjà en ligne)
create or replace function public.gb_on_watch(p_token text, p_player bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_room gb_on_rooms; v_live gb_live;
begin
  if p_player is null or gb__blocked(v_pid, p_player)
     or not exists (select 1 from gb_players where id = p_player) then
    raise exception 'on_player';
  end if;
  select * into v_room from gb_on_rooms r
   where (p_player in (r.a_id, r.b_id)
          or exists (select 1 from gb_on_homes h where h.room_id = r.id and h.player_id = p_player and h.left_at is null))
     and r.left_by is null
     and r.updated_at > now() - interval '3 minutes'
   order by r.id desc limit 1;
  if found then
    return jsonb_build_object('room', v_room.id, 'seq', v_room.seq, 'game', v_room.game);
  end if;
  select * into v_live from gb_live l
   where p_player = any(l.players) and l.updated_at > now() - interval '3 minutes'
   order by l.updated_at desc limit 1;
  if found then
    return jsonb_build_object('live', true, 'seq', v_live.seq, 'game', v_live.state -> 'game', 'state', v_live.state);
  end if;
  return jsonb_build_object('error', 'on_gone');
end $$;

-- Liste des joueurs : « room » (on peut regarder) pour tous, pas que les amis
create or replace function public.gb_on_people(p_token text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  return coalesce((
    select jsonb_agg(x.j order by x.ord, x.name)
      from (
        select lower(p.pseudo) as name,
               gb__on_player(p.id) || jsonb_build_object(
                 'state', case when o.player_id is null or hid.a_id is not null then 'off'
                               when o.busy then 'busy' else 'free' end,
                 'dnd', p.dnd,
                 'seen', p.seen_at,
                 'motto', p.motto,
                 'title', gb__title(p.id),
                 'friend', case when blk.a_id is not null then 'blocked'
                                when f.status = 'ok' then 'ok'
                                when f.a_id = v_pid then 'sent'
                                when f.b_id = v_pid then 'ask' else '' end,
                 'want', exists (select 1 from gb_on_wants w where w.from_id = p.id and w.to_id = v_pid),
                 'wanted', exists (select 1 from gb_on_wants w where w.from_id = v_pid and w.to_id = p.id),
                 'room', blk.a_id is null and hid.a_id is null and (
                   exists (select 1 from gb_on_rooms r
                            where (p.id in (r.a_id, r.b_id) or exists (select 1 from gb_on_homes h where h.room_id = r.id and h.player_id = p.id and h.left_at is null))
                              and r.left_by is null
                              and r.updated_at > now() - interval '3 minutes')
                   or exists (select 1 from gb_live l
                               where p.id = any(l.players)
                                 and l.updated_at > now() - interval '3 minutes')))
               || case when f.status = 'ok' then gb__h2h(v_pid, p.id) else '{}'::jsonb end as j,
               case when f.status = 'pending' and f.b_id = v_pid then 0
                    when blk.a_id is not null then 5
                    when o.player_id is not null and hid.a_id is null and not o.busy then 1
                    when o.player_id is not null and hid.a_id is null then 2
                    when f.status = 'ok' then 3 else 4 end as ord
          from gb_players p
          left join gb_online o on o.player_id = p.id
                               and o.seen_at > now() - interval '40 seconds'
          left join gb_friends f on (f.a_id = v_pid and f.b_id = p.id)
                                 or (f.b_id = v_pid and f.a_id = p.id)
          left join gb_blocks blk on blk.a_id = v_pid and blk.b_id = p.id  -- je l'ai bloqué
          left join gb_blocks hid on hid.a_id = p.id and hid.b_id = v_pid  -- il m'a bloqué
         where p.id <> v_pid
         order by ord, name
         limit 300) x), '[]');
end $$;

alter function public.gb_live_push(text, jsonb, bigint[]) owner to rc_owner;
alter function public.gb_on_watch(text, bigint) owner to rc_owner;
alter function public.gb_on_people(text) owner to rc_owner;
grant execute on function public.gb_live_push(text, jsonb, bigint[]) to anon;
grant execute on function public.gb_on_watch(text, bigint) to anon;
grant execute on function public.gb_on_people(text) to anon;

commit;

notify pgrst, 'reload schema';

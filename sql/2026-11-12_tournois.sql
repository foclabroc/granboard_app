-- Foclaboard : tournois en ligne à élimination directe (4, 8 ou 16 joueurs).
--   • un joueur crée le tournoi (nom, taille, règles des matchs = une partie
--     modèle 01 / Cricket / Match), les autres s'inscrivent
--   • le créateur lance : tirage au sort, exempts au 1er tour s'il manque des
--     joueurs (tableau à la puissance de 2 au-dessus)
--   • chaque match se joue comme un défi « En ligne » (gb_tn_challenge crée le
--     défi avec la partie du tournoi, marquée « tn ») ; en fin de partie
--     l'appli envoie le vainqueur (gb_tn_report), qui passe au tour suivant
--   • le créateur peut déclarer un vainqueur (forfait) ou supprimer le tournoi
-- Relançable. À lancer en postgres APRÈS 2026-11-12_rangs.sql :
--   psql -U postgres -d postgres -f 2026-11-12_tournois.sql

begin;

create table if not exists public.gb_tournaments (
  id         bigserial primary key,
  name       text   not null,
  owner_id   bigint not null references public.gb_players(id) on delete cascade,
  size       int    not null,              -- 4, 8 ou 16 places
  label      text   not null default '',   -- « 501 », « Cricket », « Match 3 legs »…
  game       jsonb  not null,              -- partie modèle (réglages ; joueurs remplacés à chaque match)
  status     text   not null default 'open',  -- open | running | done
  rounds     int,                          -- nombre de tours du tableau
  winner_id  bigint references public.gb_players(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gb_tn_players (
  t_id      bigint not null references public.gb_tournaments(id) on delete cascade,
  player_id bigint not null references public.gb_players(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (t_id, player_id)
);

-- Un match du tableau : tour 1 = premier tour, emplacement 0.. de haut en bas.
-- a_id / b_id null = pas encore connu (ou exempt au 1er tour).
create table if not exists public.gb_tn_matches (
  t_id      bigint not null references public.gb_tournaments(id) on delete cascade,
  round     int    not null,
  slot      int    not null,
  a_id      bigint references public.gb_players(id) on delete set null,
  b_id      bigint references public.gb_players(id) on delete set null,
  bye       boolean not null default false,  -- exempt : a passe sans jouer
  winner_id bigint references public.gb_players(id) on delete set null,
  forfeit   boolean not null default false,  -- vainqueur déclaré par le créateur
  played_at timestamptz,
  primary key (t_id, round, slot)
);

alter table public.gb_tournaments owner to rc_owner;
alter table public.gb_tn_players  owner to rc_owner;
alter table public.gb_tn_matches  owner to rc_owner;
alter sequence public.gb_tournaments_id_seq owner to rc_owner;
revoke all on public.gb_tournaments, public.gb_tn_players, public.gb_tn_matches
  from public, anon, authenticated;
revoke all on sequence public.gb_tournaments_id_seq from public, anon, authenticated;

-- ─── Fonctions internes ────────────────────────────────────────────────────

-- Vainqueur d'un match : passe au match suivant (ou gagne le tournoi)
create or replace function public.gb__tn_advance(p_t bigint, p_round int, p_slot int, p_winner bigint)
 returns void
 language plpgsql
 set search_path to 'public'
as $$
declare v_rounds int;
begin
  update gb_tn_matches set winner_id = p_winner, played_at = now()
   where t_id = p_t and round = p_round and slot = p_slot;
  select rounds into v_rounds from gb_tournaments where id = p_t;
  if p_round >= v_rounds then
    update gb_tournaments set status = 'done', winner_id = p_winner, updated_at = now()
     where id = p_t;
    return;
  end if;
  if p_slot % 2 = 0 then
    update gb_tn_matches set a_id = p_winner where t_id = p_t and round = p_round + 1 and slot = p_slot / 2;
  else
    update gb_tn_matches set b_id = p_winner where t_id = p_t and round = p_round + 1 and slot = p_slot / 2;
  end if;
  update gb_tournaments set updated_at = now() where id = p_t;
end $$;

-- Tournoi complet pour l'appli : infos, inscrits (fiche courte), matchs
create or replace function public.gb__tn_json(p_t bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
    'id', t.id, 'name', t.name, 'size', t.size, 'label', t.label, 'game', t.game,
    'status', t.status, 'rounds', t.rounds, 'owner', t.owner_id, 'winner', t.winner_id,
    'created', t.created_at,
    'players', coalesce((
      select jsonb_agg(gb__on_player(p.player_id) order by p.joined_at)
        from gb_tn_players p where p.t_id = t.id), '[]'),
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object('r', m.round, 's', m.slot, 'a', m.a_id, 'b', m.b_id,
                                          'bye', m.bye, 'winner', m.winner_id, 'forfeit', m.forfeit)
                       order by m.round, m.slot)
        from gb_tn_matches m where m.t_id = t.id), '[]'))
    from gb_tournaments t where t.id = p_t
$$;

-- ─── Fonctions de l'appli ──────────────────────────────────────────────────

-- Liste : tournois ouverts ou en cours, et terminés depuis moins de 30 jours
create or replace function public.gb_tn_list(p_token text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  delete from gb_tournaments
   where (status = 'done' and updated_at < now() - interval '30 days')
      or (status <> 'done' and updated_at < now() - interval '60 days');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', t.id, 'name', t.name, 'size', t.size, 'label', t.label, 'status', t.status,
             'owner', gb__on_player(t.owner_id), 'winner', gb__on_player(t.winner_id),
             'count', (select count(*) from gb_tn_players p where p.t_id = t.id),
             'joined', exists (select 1 from gb_tn_players p where p.t_id = t.id and p.player_id = v_pid),
             'created', t.created_at)
           order by (t.status = 'done'), t.created_at desc)
      from (select * from gb_tournaments order by created_at desc limit 60) t), '[]');
end $$;

create or replace function public.gb_tn_get(p_id bigint)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'public'
as $$
declare v jsonb := gb__tn_json(p_id);
begin
  if v is null then
    return jsonb_build_object('error', 'tn_gone');
  end if;
  return v;
end $$;

-- Crée un tournoi (le créateur est inscrit) → {id}
create or replace function public.gb_tn_create(p_token text, p_name text, p_size int, p_label text, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v_name text := left(btrim(coalesce(p_name, '')), 40);
  v_id bigint;
begin
  if v_name = '' then
    raise exception 'tn_name';
  end if;
  if p_size not in (4, 8, 16) then
    raise exception 'tn_size';
  end if;
  if p_game is null or jsonb_typeof(p_game) <> 'object' or octet_length(p_game::text) > 32768
     or coalesce(p_game->>'kind', '') not in ('x01', 'cricket', 'match') then
    raise exception 'tn_game';
  end if;
  if (select count(*) from gb_tournaments where owner_id = v_pid and status <> 'done') >= 5 then
    return jsonb_build_object('error', 'tn_too_many');
  end if;
  insert into gb_tournaments (name, owner_id, size, label, game)
  values (v_name, v_pid, p_size, left(coalesce(p_label, ''), 40), p_game - 'players' - 'actions')
  returning id into v_id;
  insert into gb_tn_players (t_id, player_id) values (v_id, v_pid);
  return jsonb_build_object('id', v_id);
end $$;

-- Inscription → {ok} ou {error: tn_gone | tn_started | tn_full}
create or replace function public.gb_tn_join(p_token text, p_id bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); t gb_tournaments;
begin
  select * into t from gb_tournaments where id = p_id for update;
  if t.id is null then return jsonb_build_object('error', 'tn_gone'); end if;
  if t.status <> 'open' then return jsonb_build_object('error', 'tn_started'); end if;
  if exists (select 1 from gb_tn_players where t_id = t.id and player_id = v_pid) then
    return jsonb_build_object('ok', true);
  end if;
  if (select count(*) from gb_tn_players where t_id = t.id) >= t.size then
    return jsonb_build_object('error', 'tn_full');
  end if;
  insert into gb_tn_players (t_id, player_id) values (t.id, v_pid);
  update gb_tournaments set updated_at = now() where id = t.id;
  return jsonb_build_object('ok', true);
end $$;

-- Désinscription (avant le lancement ; le créateur ne peut pas, il supprime)
create or replace function public.gb_tn_leave(p_token text, p_id bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  delete from gb_tn_players p using gb_tournaments t
   where p.t_id = p_id and p.player_id = v_pid and t.id = p.t_id
     and t.status = 'open' and t.owner_id <> v_pid;
end $$;

-- Suppression par le créateur (à tout moment)
create or replace function public.gb_tn_delete(p_token text, p_id bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
begin
  delete from gb_tournaments where id = p_id and owner_id = gb__auth(p_token);
end $$;

-- Lancement par le créateur (2 inscrits minimum) : tirage au sort, tableau
-- à la puissance de 2 au-dessus du nombre d'inscrits, exempts au 1er tour.
create or replace function public.gb_tn_start(p_token text, p_id bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  t gb_tournaments;
  v_ids bigint[];
  n int; v_size int := 2; v_rounds int := 1; v_byes int;
  r int; s int; i int;
begin
  select * into t from gb_tournaments where id = p_id and owner_id = v_pid for update;
  if t.id is null then return jsonb_build_object('error', 'tn_gone'); end if;
  if t.status <> 'open' then return jsonb_build_object('error', 'tn_started'); end if;
  select array_agg(player_id order by random()) into v_ids from gb_tn_players where t_id = t.id;
  n := coalesce(array_length(v_ids, 1), 0);
  if n < 2 then return jsonb_build_object('error', 'tn_few'); end if;
  while v_size < n loop
    v_size := v_size * 2; v_rounds := v_rounds + 1;
  end loop;
  v_byes := v_size - n;  -- toujours moins que la moitié : jamais 2 exempts face à face
  delete from gb_tn_matches where t_id = t.id;
  for r in 1..v_rounds loop
    for s in 0..(v_size / (2 ^ r))::int - 1 loop
      insert into gb_tn_matches (t_id, round, slot) values (t.id, r, s);
    end loop;
  end loop;
  -- 1er tour : exempts répartis un match sur deux (emplacements pairs, puis
  -- impairs) pour qu'un exempt retrouve au 2e tour le vainqueur d'un vrai match
  i := 1;
  for s in 0..(v_size / 2) - 1 loop
    if (s % 2 = 0 and s / 2 < v_byes)
       or (s % 2 = 1 and (s - 1) / 2 < v_byes - v_size / 4) then
      update gb_tn_matches set a_id = v_ids[i], bye = true
       where t_id = t.id and round = 1 and slot = s;
      i := i + 1;
    else
      update gb_tn_matches set a_id = v_ids[i], b_id = v_ids[i + 1]
       where t_id = t.id and round = 1 and slot = s;
      i := i + 2;
    end if;
  end loop;
  update gb_tournaments set status = 'running', rounds = v_rounds, updated_at = now() where id = t.id;
  for s in (select slot from gb_tn_matches where t_id = t.id and round = 1 and bye order by slot) loop
    perform gb__tn_advance(t.id, 1, s, (select a_id from gb_tn_matches where t_id = t.id and round = 1 and slot = s));
  end loop;
  return gb__tn_json(t.id);
end $$;

-- Lance mon match : défi « En ligne » à l'adversaire avec la partie du
-- tournoi (joueurs dans un ordre tiré au sort, marque « tn »)
-- → {id} ou {error: tn_match | on_offline | on_busy}
create or replace function public.gb_tn_challenge(p_token text, p_id bigint, p_round int, p_slot int)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  t gb_tournaments;
  m gb_tn_matches;
  v_opp bigint;
  v_me jsonb; v_him jsonb;
  v_game jsonb;
  v_inv bigint;
begin
  select * into t from gb_tournaments where id = p_id;
  select * into m from gb_tn_matches where t_id = p_id and round = p_round and slot = p_slot;
  if t.id is null or t.status <> 'running' or m.t_id is null or m.winner_id is not null
     or m.a_id is null or m.b_id is null or v_pid not in (m.a_id, m.b_id) then
    return jsonb_build_object('error', 'tn_match');
  end if;
  v_opp := case when m.a_id = v_pid then m.b_id else m.a_id end;
  if not gb__on_here(v_opp) then
    return jsonb_build_object('error', 'on_offline');
  end if;
  if exists (select 1 from gb_online where player_id = v_opp and busy)
     or exists (select 1 from gb_on_invites
                 where to_id = v_opp and status = 'pending' and from_id <> v_pid
                   and created_at > now() - interval '45 seconds') then
    return jsonb_build_object('error', 'on_busy');
  end if;
  select jsonb_build_object('id', id::text, 'name', pseudo) into v_me from gb_players where id = v_pid;
  select jsonb_build_object('id', id::text, 'name', pseudo) into v_him from gb_players where id = v_opp;
  v_game := t.game || jsonb_build_object(
    'players', case when random() < 0.5
                    then jsonb_build_array(v_me || '{"team":0}', v_him || '{"team":1}')
                    else jsonb_build_array(v_him || '{"team":0}', v_me || '{"team":1}') end,
    'actions', '[]'::jsonb,
    'tn', jsonb_build_object('t', t.id, 'r', m.round, 's', m.slot, 'name', t.name,
                             'rounds', t.rounds));
  update gb_on_invites set status = 'cancelled' where from_id = v_pid and status = 'pending';
  insert into gb_on_invites (from_id, to_id, game) values (v_pid, v_opp, v_game) returning id into v_inv;
  perform gb__on_notify('u' || v_opp);
  return jsonb_build_object('id', v_inv);
end $$;

-- Résultat envoyé par un des 2 joueurs en fin de partie (le premier compte)
create or replace function public.gb_tn_report(p_token text, p_id bigint, p_round int, p_slot int, p_winner bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); m gb_tn_matches;
begin
  select * into m from gb_tn_matches where t_id = p_id and round = p_round and slot = p_slot for update;
  if m.t_id is null or v_pid not in (m.a_id, m.b_id) or p_winner not in (m.a_id, m.b_id)
     or not exists (select 1 from gb_tournaments where id = p_id and status = 'running') then
    return jsonb_build_object('error', 'tn_match');
  end if;
  if m.winner_id is null then
    perform gb__tn_advance(p_id, p_round, p_slot, p_winner);
  end if;
  return gb__tn_json(p_id);
end $$;

-- Le créateur déclare le vainqueur d'un match (forfait, match joué hors appli)
create or replace function public.gb_tn_set_winner(p_token text, p_id bigint, p_round int, p_slot int, p_winner bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); m gb_tn_matches;
begin
  if not exists (select 1 from gb_tournaments where id = p_id and owner_id = v_pid and status = 'running') then
    return jsonb_build_object('error', 'tn_owner');
  end if;
  select * into m from gb_tn_matches where t_id = p_id and round = p_round and slot = p_slot for update;
  if m.t_id is null or m.winner_id is not null or m.a_id is null or m.b_id is null
     or p_winner not in (m.a_id, m.b_id) then
    return jsonb_build_object('error', 'tn_match');
  end if;
  update gb_tn_matches set forfeit = true where t_id = p_id and round = p_round and slot = p_slot;
  perform gb__tn_advance(p_id, p_round, p_slot, p_winner);
  return gb__tn_json(p_id);
end $$;

-- Propriétaire et droits (même règle que les autres fichiers)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and (p.proname like 'gb\_tn\_%' or p.proname like 'gb\_\_tn\_%')
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

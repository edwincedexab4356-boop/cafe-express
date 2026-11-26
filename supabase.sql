-- Cafe Express · tarjeta de sellos
-- Pegar todo en Supabase > SQL Editor > Run. Antes, cambia las claves de abajo.

create extension if not exists pgcrypto with schema extensions;

create table if not exists puestos(
  id int primary key,
  nombre text not null,
  clave text not null
);

create table if not exists ajustes(
  id int primary key default 1 check (id = 1),
  clave_dueno text not null,
  meta int not null default 15,
  max_dia int not null default 1,
  espera_min int not null default 20,
  vigencia_seg int not null default 40,
  cupon_seg int not null default 120
);

create table if not exists clientes(
  id uuid primary key default gen_random_uuid(),
  telefono text unique not null,
  nombre text not null,
  pin text not null,
  token uuid not null default gen_random_uuid(),
  sellos int not null default 0,
  ultimo_puesto int references puestos,
  ultimo_scan timestamptz,
  creado timestamptz not null default now()
);

create table if not exists codigos(
  codigo text primary key,
  puesto int not null references puestos,
  vence timestamptz not null
);

create table if not exists movimientos(
  id bigserial primary key,
  cliente uuid references clientes,
  puesto int references puestos,
  tipo text not null check (tipo in ('sello','canje','bloqueado')),
  ts timestamptz not null default now()
);
create index if not exists mov_puesto_ts on movimientos(puesto, ts);
create index if not exists mov_cliente_ts on movimientos(cliente, ts);

-- Nadie lee las tablas directo: todo pasa por las funciones de abajo
alter table puestos enable row level security;
alter table ajustes enable row level security;
alter table clientes enable row level security;
alter table codigos enable row level security;
alter table movimientos enable row level security;

-- ===== CAMBIA ESTAS CLAVES =====
insert into ajustes(id, clave_dueno) values (1, 'CAMBIA-clave-dueno') on conflict (id) do nothing;
insert into puestos(id, nombre, clave) values
  (1, 'Puesto 1', 'CAMBIA-clave-1'),
  (2, 'Puesto 2', 'CAMBIA-clave-2'),
  (3, 'Puesto 3', 'CAMBIA-clave-3'),
  (4, 'Puesto 4', 'CAMBIA-clave-4')
on conflict (id) do nothing;

create or replace function dia_pa(t timestamptz) returns date
language sql immutable as $$ select (t at time zone 'America/Panama')::date $$;

create or replace function registrar(p_tel text, p_nombre text, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare c clientes; t text := regexp_replace(coalesce(p_tel,''), '\D', '', 'g');
begin
  if length(t) < 7 then raise exception 'Número de celular no válido'; end if;
  if coalesce(p_pin,'') !~ '^\d{4}$' then raise exception 'El PIN debe tener 4 números'; end if;
  if exists(select 1 from clientes where telefono = t) then raise exception 'Ese número ya tiene tarjeta. Toca «Ya tengo tarjeta».'; end if;
  insert into clientes(telefono, nombre, pin)
  values (t, coalesce(nullif(left(trim(p_nombre), 40), ''), 'Cliente'), crypt(p_pin, gen_salt('bf')))
  returning * into c;
  return json_build_object('id', c.id, 'token', c.token, 'nombre', c.nombre, 'sellos', c.sellos);
end $$;

create or replace function entrar(p_tel text, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare c clientes;
begin
  select * into c from clientes
  where telefono = regexp_replace(coalesce(p_tel,''), '\D', '', 'g') and pin = crypt(coalesce(p_pin,''), pin);
  if not found then perform pg_sleep(1); raise exception 'Número o PIN incorrecto'; end if;
  return json_build_object('id', c.id, 'token', c.token, 'nombre', c.nombre, 'sellos', c.sellos);
end $$;

create or replace function tarjeta(p_id uuid, p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
declare c clientes; a ajustes;
begin
  select * into c from clientes where id = p_id and token = p_token;
  if not found then raise exception 'Sesión no válida. Vuelve a entrar.'; end if;
  select * into a from ajustes where id = 1;
  return json_build_object('id', c.id, 'nombre', c.nombre, 'sellos', c.sellos, 'meta', a.meta,
    'puede_canjear', c.sellos >= a.meta and c.ultimo_scan > now() - interval '10 minutes');
end $$;

create or replace function escanear(p_id uuid, p_token uuid, p_puesto int, p_codigo text) returns json
language plpgsql security definer set search_path = public as $$
declare c clientes; a ajustes; n int;
begin
  select * into c from clientes where id = p_id and token = p_token for update;
  if not found then raise exception 'Sesión no válida. Vuelve a entrar.'; end if;
  select * into a from ajustes where id = 1;
  if not exists(select 1 from codigos where codigo = p_codigo and puesto = p_puesto and vence > now()) then
    insert into movimientos(cliente, puesto, tipo)
      select c.id, p_puesto, 'bloqueado' where exists(select 1 from puestos where id = p_puesto);
    return json_build_object('ok', false, 'sellos', c.sellos, 'msg', 'Este código ya venció. Escanea el QR que está ahora en la pantalla del puesto.');
  end if;
  update codigos set vence = now() where codigo = p_codigo;
  update clientes set ultimo_scan = now(), ultimo_puesto = p_puesto where id = c.id;
  if c.sellos >= a.meta then
    return json_build_object('ok', true, 'sellos', c.sellos, 'msg', '¡Tienes tu bebida gratis! Toca «Canjear ahora».');
  end if;
  if (select count(*) from movimientos where cliente = c.id and tipo = 'sello' and dia_pa(ts) = dia_pa(now())) >= a.max_dia then
    return json_build_object('ok', false, 'sellos', c.sellos, 'msg', case when a.max_dia = 1 then 'Ya sumaste tu sello de hoy. Vuelve mañana por el siguiente.' else 'Ya sumaste ' || a.max_dia || ' sellos hoy. Mañana sigues acumulando.' end);
  end if;
  if exists(select 1 from movimientos where cliente = c.id and tipo = 'sello' and ts > now() - make_interval(mins => a.espera_min)) then
    return json_build_object('ok', false, 'sellos', c.sellos, 'msg', 'Ya sumaste un sello hace poco. El próximo, en tu siguiente compra.');
  end if;
  update clientes set sellos = sellos + 1 where id = c.id returning sellos into n;
  insert into movimientos(cliente, puesto, tipo) values (c.id, p_puesto, 'sello');
  return json_build_object('ok', true, 'sellos', n, 'msg',
    case when n >= a.meta then '¡Completaste ' || a.meta || '! Tu bebida es gratis.' else '+1 sello. Llevas ' || n || ' de ' || a.meta || '.' end);
end $$;

create or replace function canjear(p_id uuid, p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
declare c clientes; a ajustes; n int;
begin
  select * into c from clientes where id = p_id and token = p_token for update;
  if not found then raise exception 'Sesión no válida. Vuelve a entrar.'; end if;
  select * into a from ajustes where id = 1;
  if c.sellos < a.meta then raise exception 'Todavía no tienes % sellos.', a.meta; end if;
  if c.ultimo_scan is null or c.ultimo_scan < now() - interval '10 minutes' then
    raise exception 'Primero escanea el QR del puesto donde estás.';
  end if;
  update clientes set sellos = sellos - a.meta where id = c.id returning sellos into n;
  insert into movimientos(cliente, puesto, tipo) values (c.id, c.ultimo_puesto, 'canje');
  return json_build_object('ok', true, 'sellos', n,
    'puesto', (select nombre from puestos where id = c.ultimo_puesto),
    'hasta', now() + make_interval(secs => a.cupon_seg));
end $$;

drop function if exists estado_puesto(int, text);
create or replace function estado_puesto(p_puesto int, p_clave text, p_codigo text default null) returns json
language plpgsql security definer set search_path = public as $$
declare p puestos;
begin
  select * into p from puestos where id = p_puesto and clave = p_clave;
  if not found then raise exception 'Puesto o clave incorrecta'; end if;
  return json_build_object(
    'nombre', p.nombre,
    'vigente', p_codigo is null or exists(select 1 from codigos where codigo = p_codigo and puesto = p.id and vence > now()),
    'recientes', (select coalesce(json_agg(z order by z.ts desc), '[]'::json) from (
        select split_part(c.nombre, ' ', 1) as nombre, m.tipo, c.sellos, m.ts
        from movimientos m join clientes c on c.id = m.cliente
        where m.puesto = p.id and m.tipo in ('sello','canje') and m.ts > now() - interval '3 minutes'
        order by m.ts desc limit 5) z),
    'hoy_sellos', (select count(*) from movimientos where puesto = p.id and tipo = 'sello' and dia_pa(ts) = dia_pa(now())),
    'hoy_canjes', (select count(*) from movimientos where puesto = p.id and tipo = 'canje' and dia_pa(ts) = dia_pa(now())));
end $$;

create or replace function nuevo_qr(p_puesto int, p_clave text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare e json; cod text := encode(gen_random_bytes(6), 'hex'); a ajustes;
begin
  e := estado_puesto(p_puesto, p_clave);
  select * into a from ajustes where id = 1;
  delete from codigos where vence < now() - interval '1 hour';
  insert into codigos(codigo, puesto, vence) values (cod, p_puesto, now() + make_interval(secs => a.vigencia_seg));
  return (e::jsonb || jsonb_build_object('codigo', cod))::json;
end $$;

create or replace function reporte(p_clave text, p_fecha date) returns json
language plpgsql security definer set search_path = public as $$
declare a ajustes;
begin
  select * into a from ajustes where id = 1;
  if a.clave_dueno is distinct from p_clave then perform pg_sleep(1); raise exception 'Clave incorrecta'; end if;
  return json_build_object(
    'fecha', p_fecha, 'max_dia', a.max_dia,
    'puestos', (select coalesce(json_agg(x order by x.id), '[]'::json) from (
        select p.id, p.nombre,
          (select count(*) from movimientos m where m.puesto = p.id and m.tipo = 'sello' and dia_pa(m.ts) = p_fecha) as sellos,
          (select count(*) from movimientos m where m.puesto = p.id and m.tipo = 'canje' and dia_pa(m.ts) = p_fecha) as canjes,
          (select count(distinct m.cliente) from movimientos m where m.puesto = p.id and m.tipo <> 'bloqueado' and dia_pa(m.ts) = p_fecha) as clientes
        from puestos p) x),
    'nuevos', (select count(*) from clientes where dia_pa(creado) = p_fecha),
    'total_clientes', (select count(*) from clientes),
    'bloqueados', (select count(*) from movimientos where tipo = 'bloqueado' and dia_pa(ts) = p_fecha),
    'al_limite', (select coalesce(json_agg(y), '[]'::json) from (
        select c.nombre, c.telefono, count(*) as sellos
        from movimientos m join clientes c on c.id = m.cliente
        where m.tipo = 'sello' and dia_pa(m.ts) = p_fecha
        group by c.id, c.nombre, c.telefono having count(*) >= a.max_dia) y));
end $$;

-- Solo las funciones públicas quedan disponibles para la página
revoke execute on function dia_pa(timestamptz) from public, anon;
grant execute on function registrar(text,text,text), entrar(text,text), tarjeta(uuid,uuid),
  escanear(uuid,uuid,int,text), canjear(uuid,uuid), estado_puesto(int,text,text), nuevo_qr(int,text),
  reporte(text,date) to anon;

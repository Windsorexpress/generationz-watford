-- ============================================================
--  WINDSOR EXPRESS — COMPLETE DATABASE SETUP  (run this ONE file)
--  Supabase Dashboard -> SQL Editor -> New query -> paste ALL -> Run.
--  Safe to run more than once (won't duplicate or wipe data).
-- ============================================================

-- ---------- 1. PHONES FOR SALE ----------
create table if not exists public.phones (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null, storage text, color text, condition text,
  price numeric(10,2) not null, image_url text, description text,
  stock integer not null default 1
);

-- ---------- 2. REPAIR BOOKINGS ----------
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  type text default 'repair', service_type text, brand text, model text, issue text,
  quality text, quoted_price text, addons jsonb default '[]'::jsonb,
  addon_total numeric(10,2) default 0, total_amount numeric(10,2) default 0,
  time_slot text, address text, name text, phone text, email text,
  payment_method text default 'in_store', payment_status text default 'unpaid',
  stripe_session_id text, done boolean not null default false
);
alter table public.bookings add column if not exists done boolean not null default false;

-- ---------- 3. PHONE ORDERS ----------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  type text default 'phone_order', product_id uuid, product_name text, product_price numeric(10,2),
  addons jsonb default '[]'::jsonb, addon_total numeric(10,2) default 0,
  fulfillment text, postage_fee numeric(10,2) default 0, total_amount numeric(10,2) default 0,
  name text, phone text, email text, address text,
  payment_method text default 'in_store', payment_status text default 'unpaid',
  stripe_session_id text, done boolean not null default false
);
alter table public.orders add column if not exists done boolean not null default false;

-- ---------- 4. SELL ENQUIRIES ----------
create table if not exists public.sell_inquiries (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  device text, condition text, name text, phone text, email text,
  done boolean not null default false
);

-- ---------- 5. REPAIR PRICES ----------
create table if not exists public.repair_prices (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  brand text not null, model text not null,
  lcd numeric(10,2), fhd numeric(10,2), oled numeric(10,2), original numeric(10,2),
  battery numeric(10,2), back_glass numeric(10,2), charging_port numeric(10,2),
  rear_camera numeric(10,2), speaker numeric(10,2),
  sort_order integer not null default 0, active boolean not null default true
);
alter table public.repair_prices add column if not exists battery numeric(10,2);
alter table public.repair_prices add column if not exists back_glass numeric(10,2);
alter table public.repair_prices add column if not exists charging_port numeric(10,2);
alter table public.repair_prices add column if not exists rear_camera numeric(10,2);
alter table public.repair_prices add column if not exists speaker numeric(10,2);
alter table public.repair_prices add column if not exists original numeric(10,2);

-- ============================================================
--  ROW LEVEL SECURITY
--  Public (anon key) can: read phones + repair_prices, and INSERT
--  bookings/orders/sell_inquiries. Public CANNOT read private data.
--  Your admin page + edge functions use the service_role key (bypasses RLS).
-- ============================================================
alter table public.phones         enable row level security;
alter table public.bookings       enable row level security;
alter table public.orders         enable row level security;
alter table public.sell_inquiries enable row level security;
alter table public.repair_prices  enable row level security;

drop policy if exists "phones_public_read"        on public.phones;
create policy "phones_public_read"        on public.phones        for select to anon, authenticated using (true);
drop policy if exists "repair_public_read"        on public.repair_prices;
create policy "repair_public_read"        on public.repair_prices for select to anon, authenticated using (true);
drop policy if exists "bookings_public_insert"     on public.bookings;
create policy "bookings_public_insert"     on public.bookings      for insert to anon, authenticated with check (true);
drop policy if exists "orders_public_insert"       on public.orders;
create policy "orders_public_insert"       on public.orders        for insert to anon, authenticated with check (true);
drop policy if exists "sell_public_insert"         on public.sell_inquiries;
create policy "sell_public_insert"         on public.sell_inquiries for insert to anon, authenticated with check (true);

-- ============================================================
--  SAMPLE PHONES (only if the shop is empty) — delete/replace in admin later
-- ============================================================
insert into public.phones (name, storage, color, condition, price, description, stock)
select * from (values
  ('iPhone 12','64GB','Black','Excellent',219.00,'Fully tested, battery 90%+, unlocked.',1),
  ('iPhone 13 Pro','128GB','Graphite','Like New',399.00,'Pristine, unlocked, 12-month warranty.',1),
  ('Samsung S21','128GB','Phantom Grey','Good',179.00,'Great everyday Android, unlocked.',1)
) as s(name,storage,color,condition,price,description,stock)
where not exists (select 1 from public.phones);

-- ============================================================
--  REPAIR MODELS (only if empty). iPhone has prices; Samsung blank
--  (shows "call for quote" until you set prices in the admin page).
-- ============================================================
insert into public.repair_prices (brand, model, lcd, fhd, oled, original, sort_order)
select * from (values
  ('Apple iPhone','X / Xs / XR / 11',39.99,NULL,59.99,99.99,10),
  ('Apple iPhone','Xs Max',44.99,NULL,64.99,109.99,20),
  ('Apple iPhone','11 Pro',44.99,NULL,64.99,109.99,30),
  ('Apple iPhone','11 Pro Max',49.99,NULL,69.99,119.99,40),
  ('Apple iPhone','12 / 12 Mini',49.99,NULL,74.99,124.99,50),
  ('Apple iPhone','12 Pro / 12 Pro Max',54.99,NULL,79.99,134.99,60),
  ('Apple iPhone','13 / 13 Mini',54.99,NULL,84.99,139.99,70),
  ('Apple iPhone','13 Pro',64.99,79.99,134.99,199.99,80),
  ('Apple iPhone','13 Pro Max',69.99,84.99,139.99,209.99,90),
  ('Apple iPhone','14 / 14 Plus',59.99,NULL,94.99,159.99,100),
  ('Apple iPhone','14 Pro',69.99,89.99,149.99,219.99,110),
  ('Apple iPhone','14 Pro Max',79.99,99.99,154.99,229.99,120),
  ('Apple iPhone','15 / 15 Plus',74.99,94.99,154.99,224.99,130),
  ('Apple iPhone','15 Pro',79.99,99.99,159.99,239.99,140),
  ('Apple iPhone','15 Pro Max',89.99,109.99,169.99,259.99,150),
  ('Apple iPhone','16 / 16 Plus',94.99,114.99,174.99,259.99,160),
  ('Apple iPhone','16 Pro',109.99,129.99,219.99,309.99,170),
  ('Apple iPhone','16 Pro Max',119.99,139.99,229.99,329.99,180),
  ('Apple iPhone','17',NULL,169.99,249.99,349.99,190),
  ('Apple iPhone','17 Pro',NULL,179.99,279.99,389.99,200),
  ('Apple iPhone','17 Pro Max',NULL,189.99,289.99,399.99,210),
  ('Samsung','Galaxy S20',NULL,NULL,NULL,NULL,220),
  ('Samsung','Galaxy S20+',NULL,NULL,NULL,NULL,230),
  ('Samsung','Galaxy S20 Ultra',NULL,NULL,NULL,NULL,240),
  ('Samsung','Galaxy S20 FE',NULL,NULL,NULL,NULL,250),
  ('Samsung','Galaxy S21',NULL,NULL,NULL,NULL,260),
  ('Samsung','Galaxy S21+',NULL,NULL,NULL,NULL,270),
  ('Samsung','Galaxy S21 Ultra',NULL,NULL,NULL,NULL,280),
  ('Samsung','Galaxy S21 FE',NULL,NULL,NULL,NULL,290),
  ('Samsung','Galaxy S22',NULL,NULL,NULL,NULL,300),
  ('Samsung','Galaxy S22+',NULL,NULL,NULL,NULL,310),
  ('Samsung','Galaxy S22 Ultra',NULL,NULL,NULL,NULL,320),
  ('Samsung','Galaxy S23',NULL,NULL,NULL,NULL,330),
  ('Samsung','Galaxy S23+',NULL,NULL,NULL,NULL,340),
  ('Samsung','Galaxy S23 Ultra',NULL,NULL,NULL,NULL,350),
  ('Samsung','Galaxy S23 FE',NULL,NULL,NULL,NULL,360),
  ('Samsung','Galaxy S24',NULL,NULL,NULL,NULL,370),
  ('Samsung','Galaxy S24+',NULL,NULL,NULL,NULL,380),
  ('Samsung','Galaxy S24 Ultra',NULL,NULL,NULL,NULL,390),
  ('Samsung','Galaxy S24 FE',NULL,NULL,NULL,NULL,400),
  ('Samsung','Galaxy S25',NULL,NULL,NULL,NULL,410),
  ('Samsung','Galaxy S25+',NULL,NULL,NULL,NULL,420),
  ('Samsung','Galaxy S25 Ultra',NULL,NULL,NULL,NULL,430),
  ('Samsung','Galaxy A05',NULL,NULL,NULL,NULL,440),
  ('Samsung','Galaxy A05s',NULL,NULL,NULL,NULL,450),
  ('Samsung','Galaxy A06',NULL,NULL,NULL,NULL,460),
  ('Samsung','Galaxy A14',NULL,NULL,NULL,NULL,470),
  ('Samsung','Galaxy A15',NULL,NULL,NULL,NULL,480),
  ('Samsung','Galaxy A16',NULL,NULL,NULL,NULL,490),
  ('Samsung','Galaxy A24',NULL,NULL,NULL,NULL,500),
  ('Samsung','Galaxy A25',NULL,NULL,NULL,NULL,510),
  ('Samsung','Galaxy A34',NULL,NULL,NULL,NULL,520),
  ('Samsung','Galaxy A35',NULL,NULL,NULL,NULL,530),
  ('Samsung','Galaxy A54',NULL,NULL,NULL,NULL,540),
  ('Samsung','Galaxy A55',NULL,NULL,NULL,NULL,550)
) as s(brand,model,lcd,fhd,oled,original,sort_order)
where not exists (select 1 from public.repair_prices);

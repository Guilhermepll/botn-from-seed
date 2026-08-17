-- Born From Seed: catálogo, clientes, pedidos e administração.
create extension if not exists pgcrypto;

create type public.user_role as enum ('admin', 'customer');
create type public.order_status as enum ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  category text not null default 'Camisetas',
  base_price numeric(10,2) not null check (base_price >= 0),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text unique,
  color text,
  size text,
  price numeric(10,2) check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  created_at timestamptz not null default now()
);

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.profiles(id) on delete set null,
  status public.order_status not null default 'pending',
  payment_method text,
  payment_status text not null default 'pending',
  shipping_postal_code text,
  shipping_tracking_code text,
  subtotal numeric(10,2) not null default 0,
  shipping_cost numeric(10,2) not null default 0,
  total numeric(10,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_name text not null,
  variant_name text,
  quantity integer not null check (quantity > 0),
  unit_price numeric(10,2) not null check (unit_price >= 0)
);

create index product_variants_product_id_idx on public.product_variants(product_id);
create index product_images_product_id_idx on public.product_images(product_id);
create index orders_customer_id_idx on public.orders(customer_id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;

create trigger products_updated_at before update on public.products for each row execute procedure public.set_updated_at();
create trigger orders_updated_at before update on public.orders for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create policy "profiles own read" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles own update" on public.profiles for update using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "public catalog" on public.products for select using (published or public.is_admin());
create policy "admin manages products" on public.products for all using (public.is_admin()) with check (public.is_admin());
create policy "public variants" on public.product_variants for select using (exists (select 1 from public.products p where p.id = product_id and (p.published or public.is_admin())));
create policy "admin manages variants" on public.product_variants for all using (public.is_admin()) with check (public.is_admin());
create policy "public images" on public.product_images for select using (exists (select 1 from public.products p where p.id = product_id and (p.published or public.is_admin())));
create policy "admin manages images" on public.product_images for all using (public.is_admin()) with check (public.is_admin());
create policy "customers own orders" on public.orders for select using (customer_id = auth.uid() or public.is_admin());
create policy "admin manages orders" on public.orders for all using (public.is_admin()) with check (public.is_admin());
create policy "customers own items" on public.order_items for select using (exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "admin manages items" on public.order_items for all using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
on conflict (id) do nothing;
create policy "public product images" on storage.objects for select using (bucket_id = 'product-images');
create policy "admins upload product images" on storage.objects for insert with check (bucket_id = 'product-images' and public.is_admin());
create policy "admins update product images" on storage.objects for update using (bucket_id = 'product-images' and public.is_admin());
create policy "admins delete product images" on storage.objects for delete using (bucket_id = 'product-images' and public.is_admin());

-- Milestone 1: Core Supabase schema for Albania Service & Booking Hub
-- Tables: users, businesses, bookings
-- Run this file in the Supabase SQL editor or with `supabase db push`.

create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'business_owner', 'admin');
create type public.preferred_language as enum ('sq', 'en');
create type public.business_category as enum ('car_rental', 'barber', 'dentist', 'other');
create type public.subscription_status as enum ('trial', 'active', 'past_due', 'canceled');
create type public.booking_status as enum ('pending', 'confirmed', 'completed', 'canceled');

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  phone text,
  avatar_url text,
  role public.app_role not null default 'customer',
  preferred_language public.preferred_language not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  category public.business_category not null,
  phone text,
  email text,
  website_url text,
  address_line text,
  city text not null,
  country text not null default 'Albania',
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  subscription_status public.subscription_status not null default 'trial',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint businesses_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint businesses_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint businesses_longitude_range check (longitude is null or longitude between -180 and 180)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  status public.booking_status not null default 'pending',
  service_name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  price_amount numeric(10, 2),
  currency char(3) not null default 'ALL',
  customer_notes text,
  business_notes text,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_valid_time_range check (ends_at > starts_at),
  constraint bookings_non_negative_price check (price_amount is null or price_amount >= 0),
  constraint bookings_currency_uppercase check (currency = upper(currency))
);

create index businesses_owner_id_idx on public.businesses(owner_id);
create index businesses_category_city_idx on public.businesses(category, city);
create index businesses_active_idx on public.businesses(is_active) where is_active = true;

create index bookings_business_id_starts_at_idx on public.bookings(business_id, starts_at);
create index bookings_customer_id_starts_at_idx on public.bookings(customer_id, starts_at);
create index bookings_status_idx on public.bookings(status);

create unique index bookings_no_duplicate_active_slot_idx
  on public.bookings(business_id, starts_at, ends_at)
  where status in ('pending', 'confirmed');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

create trigger set_businesses_updated_at
before update on public.businesses
for each row execute function public.set_updated_at();

create trigger set_bookings_updated_at
before update on public.bookings
for each row execute function public.set_updated_at();

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name)
  values (
    new.id,
    new.email,
    nullif(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger create_user_profile_after_signup
after insert on auth.users
for each row execute function public.create_user_profile();

alter table public.users enable row level security;
alter table public.businesses enable row level security;
alter table public.bookings enable row level security;

create policy "Users can read their own profile"
on public.users for select
using (auth.uid() = id);

create policy "Users can update their own profile"
on public.users for update
using (auth.uid() = id)
with check (auth.uid() = id);

create policy "Anyone can read active businesses"
on public.businesses for select
using (is_active = true);

create policy "Business owners can read their businesses"
on public.businesses for select
using (auth.uid() = owner_id);

create policy "Business owners can create businesses"
on public.businesses for insert
with check (auth.uid() = owner_id);

create policy "Business owners can update their businesses"
on public.businesses for update
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

create policy "Business owners can delete their businesses"
on public.businesses for delete
using (auth.uid() = owner_id);

create policy "Customers can create their own bookings"
on public.bookings for insert
with check (auth.uid() = customer_id);

create policy "Customers can read their own bookings"
on public.bookings for select
using (auth.uid() = customer_id);

create policy "Business owners can read bookings for their businesses"
on public.bookings for select
using (
  exists (
    select 1
    from public.businesses
    where businesses.id = bookings.business_id
      and businesses.owner_id = auth.uid()
  )
);

create policy "Customers can update their pending bookings"
on public.bookings for update
using (auth.uid() = customer_id and status = 'pending')
with check (auth.uid() = customer_id);

create policy "Business owners can update bookings for their businesses"
on public.bookings for update
using (
  exists (
    select 1
    from public.businesses
    where businesses.id = bookings.business_id
      and businesses.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.businesses
    where businesses.id = bookings.business_id
      and businesses.owner_id = auth.uid()
  )
);

-- Smart POS Round 14 schema contract for index.html. Single-shop deployment; no multi-tenant shop records.
-- PostgreSQL / Supabase. Idempotent for table/function creation; does not DROP shop data.
-- Review SECURITY/RLS before production. PIN values supplied by frontend are expected to be SHA-256 hashes.

create extension if not exists pgcrypto;

create table if not exists public.shop_settings (
  id uuid primary key default gen_random_uuid(), shop_name text not null default '', phone text, tax_id text,
  address text, updated_at timestamptz not null default now()
);
create table if not exists public.app_users (
  id uuid primary key, auth_user_id uuid unique, name text not null, pin text not null,
  role text not null default 'CASHIER', permissions jsonb not null default '[]'::jsonb,
  is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.categories (
  id uuid primary key, name text not null, icon text default '📁', color text default '#4F46E5',
  display_order integer default 0, created_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key, sku text unique, name text not null, image_url text,
  min_stock_alert numeric not null default 5, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  group_name text, display_order integer default 0
);
create table if not exists public.product_categories (
  product_id uuid not null references public.products(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key(product_id,category_id)
);
create table if not exists public.product_variants (
  id uuid primary key, product_id uuid not null references public.products(id) on delete cascade,
  variant_name text not null default 'ปกติ', barcode text unique, price numeric not null default 0,
  cost_price numeric not null default 0, stock_quantity numeric not null default 0,
  is_active boolean not null default true, created_at timestamptz not null default now(), sku text unique, image_url text
);
create table if not exists public.product_fractions (
  id uuid primary key, variant_id uuid not null references public.product_variants(id) on delete cascade,
  fraction_name text not null, quantity_ratio numeric not null default 1 check(quantity_ratio > 0),
  price numeric not null default 0, barcode text unique
);
create table if not exists public.customers (
  id uuid primary key, name text not null, phone text, address text not null default '',
  credit_limit numeric not null default 50000, created_at timestamptz not null default now()
);
create table if not exists public.customer_balances (
  customer_id uuid primary key references public.customers(id) on delete cascade,
  balance numeric not null default 0, updated_at timestamptz not null default now(),
  initial_seeded boolean not null default false
);
create table if not exists public.suppliers (
  id uuid primary key, name text not null, phone text, address text not null default '', created_at timestamptz not null default now()
);
create table if not exists public.shifts (
  id uuid primary key, opened_at timestamptz not null default now(), closed_at timestamptz,
  opening_cash numeric not null default 0, closing_cash numeric, expected_cash numeric,
  close_note text, cash_variance numeric, status text not null default 'OPEN' check(status in ('OPEN','CLOSED')),
  opened_by uuid references public.app_users(id), closed_by uuid references public.app_users(id),
  user_id uuid references public.app_users(id)
);
create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(), bill_number text not null unique,
  customer_id uuid references public.customers(id), user_id uuid references public.app_users(id),
  shift_id uuid references public.shifts(id), subtotal numeric not null default 0,
  discount_amount numeric not null default 0, tax_amount numeric not null default 0, total numeric not null default 0,
  payment_method text not null default 'CASH', status text not null default 'PAID',
  created_at timestamptz not null default now(), client_ref text unique, tax_mode text default 'NONE'
);
create table if not exists public.bill_items (
  id uuid primary key default gen_random_uuid(), bill_id uuid not null references public.bills(id) on delete cascade,
  product_id uuid references public.products(id), variant_id uuid references public.product_variants(id),
  fraction_id uuid references public.product_fractions(id), item_name text not null,
  quantity numeric not null, unit_price numeric not null, line_total numeric not null,
  stock_quantity_delta numeric not null default 0
);
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(), bill_id uuid not null references public.bills(id) on delete cascade,
  method text not null, amount numeric not null default 0, reference text, return_id uuid, created_at timestamptz not null default now()
);
create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.product_variants(id),
  change_qty numeric not null, reason text not null, ref_type text, ref_id uuid, operation_key text unique, created_at timestamptz not null default now()
);
create table if not exists public.cash_ledger (
  id uuid primary key default gen_random_uuid(), shift_id uuid references public.shifts(id), type text not null,
  income numeric not null default 0, expense numeric not null default 0, description text, ref_id text,
  created_at timestamptz not null default now(), payment_method text default 'CASH', created_by uuid references public.app_users(id), operation_key text unique
);
alter table public.cash_ledger add column if not exists operation_key text;
create unique index if not exists cash_ledger_operation_key_unique on public.cash_ledger(operation_key) where operation_key is not null;
create table if not exists public.customer_payments (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id),
  amount numeric not null check(amount > 0), shift_id uuid references public.shifts(id), payment_method text not null default 'CASH',
  reference text, op_ref text unique, created_at timestamptz not null default now(), received_by uuid references public.app_users(id)
);
create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(), bill_id uuid not null references public.bills(id), return_ref text unique,
  shift_id uuid references public.shifts(id), total numeric not null default 0, full_return boolean not null default false,
  created_at timestamptz not null default now(), created_by uuid references public.app_users(id)
);
alter table public.payments drop constraint if exists payments_return_id_fkey;
alter table public.payments add constraint payments_return_id_fkey foreign key (return_id) references public.returns(id) on delete set null;

create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(), return_id uuid not null references public.returns(id) on delete cascade,
  product_id uuid references public.products(id), variant_id uuid references public.product_variants(id), fraction_id uuid references public.product_fractions(id),
  quantity numeric not null, unit_price numeric not null, line_total numeric not null default 0, stock_quantity_delta numeric not null default 0
);
alter table public.return_items add column if not exists product_id uuid references public.products(id);
alter table public.bill_items add column if not exists cost_total_at_sale numeric not null default 0;
alter table public.return_items add column if not exists cost_total_at_return numeric not null default 0;
comment on column public.bill_items.cost_total_at_sale is 'Historical COGS snapshot at sale time; zero means unknown/not captured.';
comment on column public.return_items.cost_total_at_return is 'Historical cost reversed for returned quantity; zero may indicate legacy unknown cost.';
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(), client_ref text unique, supplier_id uuid references public.suppliers(id),
  doc_ref text, terms integer default 30, received_at timestamptz not null default now(), total numeric not null default 0,
  status text not null default 'RECEIVED', created_at timestamptz not null default now(), created_by uuid references public.app_users(id)
);
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(), purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid references public.products(id), variant_id uuid references public.product_variants(id),
  quantity numeric not null, unit_cost numeric not null default 0, line_total numeric not null default 0
);
create table if not exists public.accounts_payable (
  id uuid primary key default gen_random_uuid(), supplier_id uuid references public.suppliers(id),
  purchase_order_id uuid references public.purchase_orders(id), doc_ref text, amount numeric not null default 0,
  credit_terms integer default 30, status text not null default 'OPEN', created_at timestamptz not null default now(), paid_at timestamptz
);
create table if not exists public.income_expenses (
  id uuid primary key default gen_random_uuid(), shift_id uuid references public.shifts(id), type text not null,
  amount numeric not null default 0, description text, created_at timestamptz not null default now(), created_by uuid references public.app_users(id)
);
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_user_id uuid references public.app_users(id), actor_name text,
  action text not null, entity_type text, entity_id text, details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_variants_product on public.product_variants(product_id);
create index if not exists idx_inventory_variant_time on public.inventory_movements(variant_id,created_at desc);
create index if not exists idx_bills_created on public.bills(created_at desc);
create index if not exists idx_bills_customer on public.bills(customer_id,created_at desc);
create index if not exists idx_cash_ledger_shift on public.cash_ledger(shift_id,created_at);
create index if not exists idx_purchase_orders_supplier on public.purchase_orders(supplier_id,created_at desc);
alter table public.shifts add column if not exists user_id uuid references public.app_users(id);
alter table public.customer_balances add column if not exists initial_seeded boolean not null default false;
create unique index if not exists app_users_one_active_owner on public.app_users ((role)) where role='OWNER' and is_active;
alter table public.payments add column if not exists return_id uuid;
alter table public.inventory_movements add column if not exists operation_key text;
create unique index if not exists idx_inventory_movements_operation_key on public.inventory_movements(operation_key) where operation_key is not null;

-- Security boundary: a Supabase Auth session must be linked to an active shop user.
-- PIN-only staff are local actor identities; they do not independently authenticate to Supabase.
create or replace function public.pos_is_authenticated_shop_user() returns boolean
language sql stable security definer set search_path=public,auth set row_security=off as $$
 select auth.uid() is not null and exists(
   select 1 from public.app_users u where u.auth_user_id=auth.uid() and u.is_active
 )
$$;
create or replace function public.pos_current_app_user_id() returns uuid
language sql stable security definer set search_path=public,auth set row_security=off as $$
 select id from public.app_users where auth_user_id=auth.uid() and is_active limit 1
$$;

create or replace function public.pos_schema_version() returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object('version','smart-pos-round14','contract','SMART-POS-STARTER-ROUND14','stock_table','inventory_movements','rpc_contract','create_sale/process_return/receive_customer_payment/receive_goods/shift-reconciliation/profit-report')
$$;

-- Client activity events are recorded through this RPC so the browser cannot choose
-- actor_user_id or write arbitrary rows directly to the audit table.
create or replace function public.record_audit_event(
 p_action text, p_entity_type text default 'application',
 p_entity_id text default null, p_details jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_actor uuid; v_id uuid;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 v_actor := public.pos_current_app_user_id();
 if v_actor is null then raise exception 'ไม่พบบัญชีผู้ใช้ร้านที่ผูกกับ Supabase Auth'; end if;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(v_actor,left(coalesce(nullif(trim(p_action),''),'ACTIVITY'),80),left(coalesce(p_entity_type,'application'),80),left(p_entity_id,200),coalesce(p_details,'{}'::jsonb))
 returning id into v_id;
 return jsonb_build_object('id',v_id,'recorded',true);
end $$;

create or replace function public.bootstrap_first_owner(p_name text,p_pin text) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'ต้องเข้าสู่ระบบ Supabase ก่อน'; end if;
 perform pg_advisory_xact_lock(hashtextextended('smartpos:bootstrap-owner',0));
 select id into v_id from public.app_users where auth_user_id=auth.uid() and is_active;
 if v_id is not null then return jsonb_build_object('id',v_id,'already_linked',true); end if;
 if exists(select 1 from public.app_users where role='OWNER' and is_active) then raise exception 'มี OWNER อยู่แล้ว'; end if;
 insert into public.app_users(id,auth_user_id,name,pin,role,permissions,is_active)
 values(gen_random_uuid(),auth.uid(),trim(p_name),p_pin,'OWNER','["ALL"]'::jsonb,true) returning id into v_id;
 insert into public.audit_logs(actor_user_id,actor_name,action,entity_type,entity_id,details)
 values(v_id,trim(p_name),'BOOTSTRAP_OWNER','app_users',v_id::text,'{}'::jsonb);
 return jsonb_build_object('id',v_id,'already_linked',false);
end $$;

create or replace function public.seed_variant_stock(p_items jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_id uuid; v_stock numeric; v_count int:=0;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 for x in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
  v_id:=(x->>'variant_id')::uuid; v_stock:=greatest(coalesce((x->>'stock')::numeric,0),0);
  update public.product_variants set stock_quantity=v_stock where id=v_id and stock_quantity=0
    and not exists(select 1 from public.inventory_movements m where m.operation_key='seed-stock:'||v_id::text);
  if found then
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id,operation_key)
   values(v_id,v_stock,'INITIAL_STOCK','SEED',v_id,'seed-stock:'||v_id::text); v_count:=v_count+1;
  end if;
 end loop;
 return jsonb_build_object('seeded',v_count);
end $$;

create or replace function public.seed_customer_debt(p_items jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_id uuid; v_debt numeric; v_count int:=0;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 for x in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
  v_id:=(x->>'customer_id')::uuid; v_debt:=greatest(coalesce((x->>'debt')::numeric,0),0);
  insert into public.customer_balances(customer_id,balance,initial_seeded) values(v_id,v_debt,true)
  on conflict(customer_id) do update set balance=excluded.balance,initial_seeded=true,updated_at=now()
  where public.customer_balances.initial_seeded=false;
  if found then v_count:=v_count+1; end if;
 end loop;
 return jsonb_build_object('seeded',v_count);
end $$;

create or replace function public.adjust_stock(p_variant_id uuid,p_mode text,p_value numeric,p_reason text,p_op_ref text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_old numeric; v_new numeric; v_delta numeric;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_op_ref is not null then perform pg_advisory_xact_lock(hashtextextended('smartpos:adjust:'||p_op_ref,0)); end if;
 if p_op_ref is not null and exists(select 1 from public.inventory_movements where operation_key='adjust:'||p_op_ref) then
  return jsonb_build_object('duplicate',true);
 end if;
 select stock_quantity into v_old from public.product_variants where id=p_variant_id and is_active for update;
 if not found then raise exception 'ไม่พบรุ่นสินค้าหรือถูกปิดใช้งาน'; end if;
 if upper(p_mode)='SET' then v_new:=p_value; elsif upper(p_mode)='ADD' then v_new:=v_old+p_value; elsif upper(p_mode)='SUBTRACT' then v_new:=v_old-p_value; else raise exception 'p_mode ต้องเป็น SET, ADD หรือ SUBTRACT'; end if;
 if v_new<0 then raise exception 'สต็อกต้องไม่ติดลบ'; end if;
 v_delta:=v_new-v_old;
 update public.product_variants set stock_quantity=v_new where id=p_variant_id;
 insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id,operation_key)
 values(p_variant_id,v_delta,coalesce(nullif(p_reason,''),'ปรับสต็อก'),'ADJUST',case when p_op_ref ~* '^[0-9a-f-]{36}$' then p_op_ref::uuid else null end,case when p_op_ref is null then null else 'adjust:'||p_op_ref end);
 return jsonb_build_object('variant_id',p_variant_id,'old_stock',v_old,'stock_quantity',v_new,'change_qty',v_delta);
end $$;

create or replace function public.create_sale(
 p_bill_number text,p_customer_id uuid,p_user_id uuid,p_shift_id uuid,p_discount_amount numeric,p_tax_amount numeric,
 p_payment_method text,p_items jsonb,p_allow_negative boolean,p_tax_mode text,p_expected_total numeric default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare x jsonb; v_bill_id uuid; v_subtotal numeric:=0; v_total numeric; v_line numeric; v_qty numeric; v_stock_qty numeric; v_ratio numeric; v_price numeric; v_variant uuid; v_fraction uuid; v_product uuid; v_name text; v_customer_balance numeric:=0; v_credit numeric:=0; v_shift_status text; v_unit_cost numeric:=0; v_cost_total numeric:=0;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 perform pg_advisory_xact_lock(hashtextextended('smartpos:bill:'||coalesce(p_bill_number,''),0));
 if exists(select 1 from public.bills where bill_number=p_bill_number) then
  select id,total into v_bill_id,v_total from public.bills where bill_number=p_bill_number;
  return jsonb_build_object('bill_id',v_bill_id,'total',v_total,'duplicate',true);
 end if;
 if p_user_id is not null and not exists(select 1 from public.app_users where id=p_user_id and is_active) then raise exception 'ไม่พบผู้ใช้ที่ทำรายการหรือบัญชีถูกปิด'; end if;
 if p_shift_id is null then raise exception 'ต้องเปิดกะก่อนขาย เพื่อให้ยอดขายผูกกับการกระทบยอดกะ'; end if;
 select status into v_shift_status from public.shifts where id=p_shift_id for update;
 if not found or v_shift_status<>'OPEN' then raise exception 'กะขายไม่เปิดอยู่ กรุณาเปิดกะใหม่ก่อนขาย'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'ไม่มีรายการสินค้า'; end if;
 for x in select value from jsonb_array_elements(p_items) loop
  v_qty:=coalesce((x->>'quantity')::numeric,0); v_price:=coalesce((x->>'unit_price')::numeric,0); v_line:=v_qty*v_price;
  if v_qty<=0 or v_price<0 then raise exception 'จำนวนหรือราคาสินค้าไม่ถูกต้อง'; end if;
  v_subtotal:=v_subtotal+v_line;
 end loop;
 v_total:=greatest(0,v_subtotal-greatest(coalesce(p_discount_amount,0),0)+greatest(coalesce(p_tax_amount,0),0));
 if p_expected_total is not null and abs(v_total-p_expected_total)>0.02 then raise exception 'ยอดบิลไม่ตรง: คำนวณได้ %, หน้า POS ส่ง %',v_total,p_expected_total; end if;
 if upper(coalesce(p_payment_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then
  if p_customer_id is null then raise exception 'ขายเชื่อต้องระบุลูกค้า'; end if;
  select coalesce(c.credit_limit,50000) into v_credit from public.customers c where c.id=p_customer_id for update;
  if not found then raise exception 'ไม่พบลูกค้า'; end if;
  select coalesce(cb.balance,0) into v_customer_balance from public.customer_balances cb where cb.customer_id=p_customer_id for update;
  if not found then v_customer_balance:=0; end if;
  if v_customer_balance+v_total>v_credit then raise exception 'ยอดหนี้เกินวงเงินลูกค้า'; end if;
 end if;
 insert into public.bills(bill_number,customer_id,user_id,shift_id,subtotal,discount_amount,tax_amount,total,payment_method,status,tax_mode)
 values(p_bill_number,p_customer_id,p_user_id,p_shift_id,v_subtotal,coalesce(p_discount_amount,0),coalesce(p_tax_amount,0),v_total,coalesce(p_payment_method,'CASH'),case when upper(coalesce(p_payment_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then 'CREDIT' else 'PAID' end,p_tax_mode)
 returning id into v_bill_id;
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid; v_variant:=nullif(x->>'variant_id','')::uuid; v_fraction:=nullif(x->>'fraction_id','')::uuid;
  v_qty:=(x->>'quantity')::numeric; v_price:=(x->>'unit_price')::numeric; v_name:=coalesce(x->>'item_name','สินค้า'); v_stock_qty:=v_qty; v_unit_cost:=0; v_cost_total:=0;
  if v_variant is not null then
   if v_fraction is not null then select quantity_ratio into v_ratio from public.product_fractions where id=v_fraction and variant_id=v_variant; if not found then raise exception 'ไม่พบหน่วยย่อยสินค้า %',v_fraction; end if; v_stock_qty:=v_qty/v_ratio; end if;
   select stock_quantity,cost_price into v_ratio,v_unit_cost from public.product_variants where id=v_variant and is_active for update;
   if not found then raise exception 'ไม่พบรุ่นสินค้า %',v_variant; end if;
   if not p_allow_negative and v_ratio<v_stock_qty then raise exception 'สต็อกไม่พอสำหรับ % (เหลือ %)',v_name,v_ratio; end if;
   v_cost_total:=round(v_stock_qty*greatest(coalesce(v_unit_cost,0),0),2);
   update public.product_variants set stock_quantity=stock_quantity-v_stock_qty where id=v_variant;
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id) values(v_variant,-v_stock_qty,'ขายสินค้า','SALE',v_bill_id);
  end if;
  insert into public.bill_items(bill_id,product_id,variant_id,fraction_id,item_name,quantity,unit_price,line_total,stock_quantity_delta,cost_total_at_sale)
  values(v_bill_id,v_product,v_variant,v_fraction,v_name,v_qty,v_price,v_qty*v_price,v_stock_qty,v_cost_total);
 end loop;
 if upper(coalesce(p_payment_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then
  insert into public.customer_balances(customer_id,balance) values(p_customer_id,v_total) on conflict(customer_id) do update set balance=public.customer_balances.balance+excluded.balance,updated_at=now();
 else
  insert into public.payments(bill_id,method,amount) values(v_bill_id,upper(coalesce(p_payment_method,'CASH')),v_total);
  if upper(coalesce(p_payment_method,'CASH')) in ('CASH','เงินสด') then insert into public.cash_ledger(shift_id,type,income,description,ref_id,payment_method,created_by) values(p_shift_id,'SALE',v_total,'รับเงินขายสินค้า',v_bill_id::text,'CASH',p_user_id); end if;
 end if;
 -- Audit actor comes from the verified Supabase Auth session, not a caller-supplied user id.
 -- Keep the selected cashier separately for sales-by-cashier reports.
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(public.pos_current_app_user_id(),'CREATE_SALE','bills',v_bill_id::text,
 jsonb_build_object('bill_number',p_bill_number,'total',v_total,'items',jsonb_array_length(p_items),'cashier_user_id',p_user_id));
 return jsonb_build_object('bill_id',v_bill_id,'bill_number',p_bill_number,'subtotal',v_subtotal,'total',v_total,'stock_updated',true);
end $$;

create or replace function public.process_return(p_bill_id uuid,p_items jsonb,p_full_return boolean,p_return_ref text default null,p_shift_id uuid default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
 x jsonb; v_return_id uuid; v_total numeric:=0; v_qty numeric; v_price numeric;
 v_variant uuid; v_fraction uuid; v_product uuid; v_ratio numeric; v_stock numeric;
 v_sold numeric; v_returned numeric; v_requested numeric; v_gross numeric;
 v_item record; v_bill_method text; v_customer_id uuid; v_subtotal numeric; v_bill_total numeric;
 v_effective_full boolean:=true; v_sold_all numeric; v_returned_all numeric; v_requested_all numeric; v_cost_sold numeric; v_cost_return numeric;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_shift_id is null then raise exception 'ต้องเปิดกะก่อนบันทึกคืนสินค้า'; end if;
 if nullif(trim(coalesce(p_return_ref,'')),'') is null then raise exception 'ต้องมีรหัสอ้างอิงการคืนสินค้าเพื่อป้องกันบันทึกซ้ำ'; end if;
 perform pg_advisory_xact_lock(hashtextextended('smartpos:return:'||p_return_ref,0));
 if exists(select 1 from public.returns where return_ref=p_return_ref) then
  select id,total into v_return_id,v_total from public.returns where return_ref=p_return_ref;
  return jsonb_build_object('return_id',v_return_id,'total',v_total,'duplicate',true);
 end if;
 select payment_method,customer_id,subtotal,total into v_bill_method,v_customer_id,v_subtotal,v_bill_total
 from public.bills where id=p_bill_id for update;
 if not found then raise exception 'ไม่พบบิลต้นทาง'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'ไม่มีรายการคืนสินค้า'; end if;
 perform 1 from public.shifts where id=p_shift_id and status='OPEN' for update;
 if not found then raise exception 'กะขายไม่เปิดอยู่ ไม่สามารถบันทึกการคืนได้'; end if;
 -- Validate the combined quantities in this request, not each row independently.
 -- Refund price is calculated from the original server-side bill, never trusted from the browser.
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid;
  v_variant:=nullif(x->>'variant_id','')::uuid;
  v_fraction:=nullif(x->>'fraction_id','')::uuid;
  v_qty:=coalesce(nullif(x->>'quantity','')::numeric,0);
  if v_qty<=0 then raise exception 'จำนวนคืนต้องมากกว่า 0'; end if;
  if v_product is null and v_variant is null then raise exception 'รายการคืนไม่มีรหัสสินค้า/รุ่นสินค้า'; end if;
  select coalesce(sum(bi.quantity),0),coalesce(sum(bi.quantity*bi.unit_price),0)
    into v_sold,v_gross from public.bill_items bi
   where bi.bill_id=p_bill_id
     and (v_product is null or bi.product_id=v_product)
     and bi.variant_id is not distinct from v_variant
     and bi.fraction_id is not distinct from v_fraction;
  if v_sold<=0 then raise exception 'สินค้า/หน่วยที่เลือกไม่มีอยู่ในบิลต้นทาง'; end if;
  select coalesce(sum(ri.quantity),0) into v_returned
    from public.return_items ri join public.returns r on r.id=ri.return_id
   where r.bill_id=p_bill_id
     and (ri.product_id is null or ri.product_id is not distinct from v_product)
     and ri.variant_id is not distinct from v_variant
     and ri.fraction_id is not distinct from v_fraction;
  select coalesce(sum((e->>'quantity')::numeric),0) into v_requested
    from jsonb_array_elements(p_items) e
   where nullif(e->>'product_id','')::uuid is not distinct from v_product
     and nullif(e->>'variant_id','')::uuid is not distinct from v_variant
     and nullif(e->>'fraction_id','')::uuid is not distinct from v_fraction;
  if v_requested>v_sold-v_returned+0.000001 then raise exception 'จำนวนคืนเกินจำนวนที่ขาย (ขาย %, คืนแล้ว %, ขอคืน %)',v_sold,v_returned,v_requested; end if;
  v_ratio:=case when coalesce(v_subtotal,0)>0 then greatest(0,v_bill_total/v_subtotal) else 0 end;
  v_price:=round((v_gross/v_sold)*v_ratio,2);
  v_total:=v_total+round(v_qty*v_price,2);
 end loop;
 -- Derive full-return status on the server instead of trusting the browser flag.
 for v_item in
  select bi.product_id,bi.variant_id,bi.fraction_id,sum(bi.quantity) sold_qty
    from public.bill_items bi where bi.bill_id=p_bill_id
   group by bi.product_id,bi.variant_id,bi.fraction_id
 loop
  select coalesce(sum(ri.quantity),0) into v_returned_all from public.return_items ri join public.returns r on r.id=ri.return_id
   where r.bill_id=p_bill_id and (ri.product_id is null or ri.product_id is not distinct from v_item.product_id)
     and ri.variant_id is not distinct from v_item.variant_id and ri.fraction_id is not distinct from v_item.fraction_id;
  select coalesce(sum((e->>'quantity')::numeric),0) into v_requested_all from jsonb_array_elements(p_items) e
   where nullif(e->>'product_id','')::uuid is not distinct from v_item.product_id
     and nullif(e->>'variant_id','')::uuid is not distinct from v_item.variant_id
     and nullif(e->>'fraction_id','')::uuid is not distinct from v_item.fraction_id;
  if v_returned_all+v_requested_all<v_item.sold_qty-0.000001 then v_effective_full:=false; end if;
 end loop;
 insert into public.returns(bill_id,return_ref,shift_id,total,full_return,created_by)
 values(p_bill_id,p_return_ref,p_shift_id,round(v_total,2),v_effective_full,public.pos_current_app_user_id()) returning id into v_return_id;
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid; v_variant:=nullif(x->>'variant_id','')::uuid;
  v_fraction:=nullif(x->>'fraction_id','')::uuid; v_qty:=(x->>'quantity')::numeric;
  select coalesce(sum(bi.quantity),0),coalesce(sum(bi.quantity*bi.unit_price),0),coalesce(sum(bi.cost_total_at_sale),0) into v_sold,v_gross,v_cost_sold
   from public.bill_items bi where bi.bill_id=p_bill_id
    and (v_product is null or bi.product_id=v_product)
    and bi.variant_id is not distinct from v_variant and bi.fraction_id is not distinct from v_fraction;
  v_cost_return:=case when v_sold>0 then round((v_cost_sold/v_sold)*v_qty,2) else 0 end;
  v_ratio:=case when coalesce(v_subtotal,0)>0 then greatest(0,v_bill_total/v_subtotal) else 0 end;
  v_price:=round((v_gross/nullif(v_sold,0))*v_ratio,2);
  v_stock:=v_qty;
  if v_variant is not null then
   if v_fraction is not null then
    select quantity_ratio into v_ratio from public.product_fractions where id=v_fraction and variant_id=v_variant;
    if not found or coalesce(v_ratio,0)<=0 then raise exception 'หน่วยย่อยไม่ตรงกับรุ่นสินค้า'; end if;
    v_stock:=v_qty/v_ratio;
   end if;
   update public.product_variants set stock_quantity=stock_quantity+v_stock where id=v_variant;
   if not found then raise exception 'ไม่พบรุ่นสินค้าสำหรับคืนสต็อก'; end if;
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id)
   values(v_variant,v_stock,'คืนสินค้า','RETURN',v_return_id);
  end if;
  insert into public.return_items(return_id,product_id,variant_id,fraction_id,quantity,unit_price,line_total,stock_quantity_delta,cost_total_at_return)
  values(v_return_id,v_product,v_variant,v_fraction,v_qty,v_price,round(v_qty*v_price,2),v_stock,v_cost_return);
 end loop;
 if upper(coalesce(v_bill_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then
  if v_customer_id is null then raise exception 'บิลขายเชื่อไม่มีลูกค้า จึงไม่สามารถปรับยอดหนี้ได้'; end if;
  insert into public.customer_balances(customer_id,balance) values(v_customer_id,0) on conflict(customer_id) do nothing;
  update public.customer_balances set balance=greatest(0,balance-round(v_total,2)),updated_at=now() where customer_id=v_customer_id;
 elsif upper(coalesce(v_bill_method,'CASH')) in ('CASH','เงินสด') then
  insert into public.cash_ledger(shift_id,type,expense,description,ref_id,payment_method,created_by)
  values(p_shift_id,'RETURN',round(v_total,2),'คืนเงินสดลูกค้า',v_return_id::text,'CASH',public.pos_current_app_user_id());
  insert into public.payments(bill_id,method,amount,reference,return_id)
  values(p_bill_id,'RETURN_CASH',-round(v_total,2),v_return_id::text,v_return_id);
 else
  insert into public.payments(bill_id,method,amount,reference,return_id)
  values(p_bill_id,'RETURN_'||upper(coalesce(v_bill_method,'TRANSFER')),-round(v_total,2),v_return_id::text,v_return_id);
 end if;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(public.pos_current_app_user_id(),'PROCESS_RETURN','returns',v_return_id::text,
 jsonb_build_object('bill_id',p_bill_id,'total',round(v_total,2),'original_method',v_bill_method,'customer_id',v_customer_id,'full_return',v_effective_full));
 return jsonb_build_object('return_id',v_return_id,'total',round(v_total,2),'stock_restored',true,'full_return',v_effective_full);
end $$;

-- Round 10: auditable gross-profit report based on cost snapshots taken at sale time.
-- Existing historical bills without snapshots remain flagged as missing cost, never guessed from current cost.
create or replace function public.get_profit_report(p_from timestamptz default null,p_to timestamptz default null)
returns table(
 bill_id uuid,bill_number text,sold_at timestamptz,payment_method text,
 revenue numeric,returned_revenue numeric,net_revenue numeric,
 cost_of_goods numeric,returned_cost numeric,net_cost numeric,gross_profit numeric,cost_missing boolean
) language plpgsql stable security definer set search_path=public as $$
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 return query
 select b.id,b.bill_number,b.created_at,b.payment_method,
        round(b.total,2),round(coalesce(r.returned_revenue,0),2),round(b.total-coalesce(r.returned_revenue,0),2),
        round(coalesce(c.cost_of_goods,0),2),round(coalesce(r.returned_cost,0),2),
        round(greatest(0,coalesce(c.cost_of_goods,0)-coalesce(r.returned_cost,0)),2),
        round((b.total-coalesce(r.returned_revenue,0))-greatest(0,coalesce(c.cost_of_goods,0)-coalesce(r.returned_cost,0)),2),
        coalesce(c.cost_missing,true)
 from public.bills b
 left join lateral (
   select sum(ri.line_total) returned_revenue,sum(ri.cost_total_at_return) returned_cost
   from public.returns rr join public.return_items ri on ri.return_id=rr.id where rr.bill_id=b.id
 ) r on true
 left join lateral (
   select sum(bi.cost_total_at_sale) cost_of_goods,
          bool_or(bi.variant_id is not null and bi.cost_total_at_sale=0) cost_missing
   from public.bill_items bi where bi.bill_id=b.id
 ) c on true
 where (p_from is null or b.created_at>=p_from) and (p_to is null or b.created_at<p_to)
 order by b.created_at desc;
end $$;

create or replace function public.receive_customer_payment(p_customer_id uuid,p_amount numeric,p_shift_id uuid,p_op_ref text default null,p_payment_method text default 'CASH',p_reference text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_balance numeric; v_shift_status text;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_shift_id is null then raise exception 'ต้องเปิดกะก่อนรับชำระหนี้ เพื่อให้ตรวจสอบยอดเงินได้'; end if;
 if nullif(trim(coalesce(p_op_ref,'')),'') is null then raise exception 'ต้องมีรหัสรายการรับชำระเพื่อป้องกันบันทึกซ้ำ'; end if;
 -- Check idempotency before shift status so a successful retry can return its original result after the shift closes.
 perform pg_advisory_xact_lock(hashtextextended('smartpos:customer-payment:'||p_op_ref,0));
 select id into v_id from public.customer_payments where op_ref=p_op_ref; if v_id is not null then return jsonb_build_object('payment_id',v_id,'duplicate',true); end if;
 if p_amount is null or p_amount<=0 then raise exception 'ยอดรับชำระต้องมากกว่า 0'; end if;
 select status into v_shift_status from public.shifts where id=p_shift_id for update;
 if not found or v_shift_status<>'OPEN' then raise exception 'กะรับชำระไม่เปิดอยู่ กรุณาเปิดกะใหม่ก่อนรับชำระ'; end if;
 perform 1 from public.customers where id=p_customer_id for update; if not found then raise exception 'ไม่พบลูกค้า'; end if;
 insert into public.customer_payments(customer_id,amount,shift_id,payment_method,reference,op_ref,received_by)
 values(p_customer_id,p_amount,p_shift_id,upper(p_payment_method),p_reference,p_op_ref,public.pos_current_app_user_id()) returning id into v_id;
 insert into public.customer_balances(customer_id,balance) values(p_customer_id,0) on conflict(customer_id) do nothing;
 select balance into v_balance from public.customer_balances where customer_id=p_customer_id for update;
 if p_amount>v_balance then raise exception 'ยอดรับชำระมากกว่ายอดหนี้คงเหลือ (%). ต้องบันทึกเงินส่วนเกินแยกต่างหาก',v_balance; end if;
 update public.customer_balances set balance=balance-p_amount,updated_at=now() where customer_id=p_customer_id;
 select balance into v_balance from public.customer_balances where customer_id=p_customer_id;
 insert into public.cash_ledger(shift_id,type,income,description,ref_id,payment_method,created_by,operation_key)
 values(p_shift_id,'CUSTOMER_PAYMENT',case when upper(p_payment_method) in ('CASH','เงินสด') then p_amount else 0 end,
 'รับชำระหนี้ลูกค้า',v_id::text,upper(p_payment_method),public.pos_current_app_user_id(),
 case when p_op_ref is not null then 'CUSTOMER_PAYMENT:'||p_op_ref else 'CUSTOMER_PAYMENT:'||v_id::text end);
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'CUSTOMER_PAYMENT','customer_payments',v_id::text,jsonb_build_object('customer_id',p_customer_id,'amount',p_amount));
 return jsonb_build_object('payment_id',v_id,'customer_id',p_customer_id,'amount',p_amount,'balance',v_balance);
end $$;

create or replace function public.receive_goods(p_client_ref text,p_supplier_id uuid,p_doc_ref text,p_terms integer,p_received_at timestamptz,p_items jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_po uuid; v_ap uuid; v_variant uuid; v_product uuid; v_qty numeric; v_cost numeric; v_total numeric:=0; v_name text; v_old_qty numeric; v_old_cost numeric; v_new_cost numeric;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_client_ref is not null then perform pg_advisory_xact_lock(hashtextextended('smartpos:receive:'||p_client_ref,0)); end if;
 if p_client_ref is not null then select id into v_po from public.purchase_orders where client_ref=p_client_ref; if v_po is not null then select id into v_ap from public.accounts_payable where purchase_order_id=v_po; return jsonb_build_object('po_id',v_po,'ap_id',v_ap,'duplicate',true); end if; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'ไม่มีรายการรับสินค้า'; end if;
 insert into public.purchase_orders(client_ref,supplier_id,doc_ref,terms,received_at,created_by) values(p_client_ref,p_supplier_id,p_doc_ref,coalesce(p_terms,30),coalesce(p_received_at,now()),public.pos_current_app_user_id()) returning id into v_po;
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid; v_variant:=nullif(x->>'variant_id','')::uuid; v_qty:=coalesce((x->>'quantity')::numeric,0); v_cost:=coalesce((x->>'unit_cost')::numeric,0);
  if v_qty<=0 or v_cost<0 then raise exception 'จำนวนหรือทุนรับสินค้าไม่ถูกต้อง'; end if;
  if v_variant is null then raise exception 'รายการรับสินค้าต้องระบุ variant_id'; end if;
  select stock_quantity,cost_price into v_old_qty,v_old_cost
   from public.product_variants where id=v_variant and (v_product is null or product_id=v_product) for update;
  if not found then raise exception 'ไม่พบรุ่นสินค้า % หรือรุ่นนี้ไม่ตรงกับสินค้า %',v_variant,v_product; end if;
  -- ต้นทุนเฉลี่ยถ่วงน้ำหนัก คิดจากสต็อกเดิมและสินค้าที่รับเข้ารอบนี้
  v_new_cost:=case when coalesce(v_old_qty,0)+v_qty>0 then round(((coalesce(v_old_qty,0)*coalesce(v_old_cost,0))+(v_qty*v_cost))/(coalesce(v_old_qty,0)+v_qty),2) else round(v_cost,2) end;
  update public.product_variants set stock_quantity=coalesce(v_old_qty,0)+v_qty,cost_price=v_new_cost where id=v_variant;
  insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id) values(v_variant,v_qty,'รับสินค้าเข้าสต็อก','PURCHASE',v_po);
  insert into public.purchase_order_items(purchase_order_id,product_id,variant_id,quantity,unit_cost,line_total) values(v_po,v_product,v_variant,v_qty,v_cost,v_qty*v_cost);
  v_total:=v_total+v_qty*v_cost;
 end loop;
 update public.purchase_orders set total=v_total where id=v_po;
 insert into public.accounts_payable(supplier_id,purchase_order_id,doc_ref,amount,credit_terms,status) values(p_supplier_id,v_po,p_doc_ref,v_total,coalesce(p_terms,30),'OPEN') returning id into v_ap;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'RECEIVE_GOODS','purchase_orders',v_po::text,jsonb_build_object('total',v_total,'items',jsonb_array_length(p_items)));
 return jsonb_build_object('po_id',v_po,'ap_id',v_ap,'total',v_total);
end $$;

create or replace function public.open_shift(p_shift_id uuid,p_opening_cash numeric,p_opened_at timestamptz default now()) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_row public.shifts%rowtype;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_shift_id is null or p_opening_cash is null or p_opening_cash<0 then raise exception 'ข้อมูลเปิดกะไม่ถูกต้อง'; end if;
 perform pg_advisory_xact_lock(hashtextextended('smartpos:shift:'||p_shift_id::text,0));
 select * into v_row from public.shifts where id=p_shift_id for update;
 if found then
   if v_row.status='CLOSED' then raise exception 'กะนี้ปิดแล้ว ไม่สามารถเปิดซ้ำได้'; end if;
   if round(v_row.opening_cash,2)<>round(p_opening_cash,2) then raise exception 'รหัสกะเดิมมีเงินเปิดกะไม่ตรงกัน'; end if;
   return jsonb_build_object('shift_id',v_row.id,'status',v_row.status,'duplicate',true);
 end if;
 insert into public.shifts(id,opened_at,opening_cash,status,opened_by,user_id)
 values(p_shift_id,coalesce(p_opened_at,now()),round(p_opening_cash,2),'OPEN',public.pos_current_app_user_id(),public.pos_current_app_user_id()) returning * into v_row;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(public.pos_current_app_user_id(),'OPEN_SHIFT','shifts',p_shift_id::text,jsonb_build_object('opening_cash',round(p_opening_cash,2)));
 return jsonb_build_object('shift_id',v_row.id,'status',v_row.status,'duplicate',false);
end $$;

create or replace function public.record_cash_movement(p_shift_id uuid,p_op_ref text,p_type text,p_amount numeric,p_note text default null,p_created_at timestamptz default now()) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_type text; v_shift public.shifts%rowtype;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_shift_id is null or nullif(trim(coalesce(p_op_ref,'')),'') is null then raise exception 'ต้องระบุกะและรหัสรายการ'; end if;
 if p_amount is null or p_amount<=0 then raise exception 'จำนวนเงินต้องมากกว่า 0'; end if;
 if upper(p_type) not in ('IN','OUT') then raise exception 'ประเภทรายการเงินสดไม่ถูกต้อง'; end if;
 perform pg_advisory_xact_lock(hashtextextended('smartpos:cash:'||p_op_ref,0));
 select id into v_id from public.cash_ledger where operation_key=p_op_ref;
 if v_id is not null then return jsonb_build_object('id',v_id,'duplicate',true); end if;
 select * into v_shift from public.shifts where id=p_shift_id for update;
 if not found or v_shift.status<>'OPEN' then raise exception 'ไม่พบกะที่เปิดอยู่'; end if;
 v_type:=case upper(p_type) when 'IN' then 'SHIFT_CASH_IN' else 'SHIFT_CASH_OUT' end;
 insert into public.cash_ledger(shift_id,type,income,expense,description,created_at,created_by,operation_key)
 values(p_shift_id,v_type,case when upper(p_type)='IN' then round(p_amount,2) else 0 end,case when upper(p_type)='OUT' then round(p_amount,2) else 0 end,nullif(trim(coalesce(p_note,'')),''),coalesce(p_created_at,now()),public.pos_current_app_user_id(),p_op_ref) returning id into v_id;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details)
 values(public.pos_current_app_user_id(),'CASH_MOVEMENT','cash_ledger',v_id::text,jsonb_build_object('type',v_type,'amount',round(p_amount,2),'note',p_note,'shift_id',p_shift_id));
 return jsonb_build_object('id',v_id,'duplicate',false);
end $$;

create or replace function public.get_shift_reconciliation(p_shift_id uuid) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_shift public.shifts%rowtype; v_income numeric; v_expense numeric; v_cash_sales numeric; v_transfer_sales numeric; v_credit_sales numeric; v_customer_cash numeric; v_customer_non_cash numeric; v_cash_returns numeric;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 select * into v_shift from public.shifts where id=p_shift_id;
 if not found then raise exception 'ไม่พบกะที่ต้องการตรวจสอบ'; end if;
 select coalesce(sum(income),0),coalesce(sum(expense),0) into v_income,v_expense from public.cash_ledger where shift_id=p_shift_id;
 select coalesce(sum(case when upper(coalesce(payment_method,'')) in ('CASH','เงินสด') then total else 0 end),0),
        coalesce(sum(case when upper(coalesce(payment_method,'')) not in ('CASH','เงินสด','CREDIT','เครดิต','ON_CREDIT') then total else 0 end),0),
        coalesce(sum(case when upper(coalesce(payment_method,'')) in ('CREDIT','เครดิต','ON_CREDIT') or status='CREDIT' then total else 0 end),0)
 into v_cash_sales,v_transfer_sales,v_credit_sales
 from public.bills where shift_id=p_shift_id and status not in ('VOID','CANCELLED','ยกเลิก');
 select coalesce(sum(case when upper(payment_method) in ('CASH','เงินสด') then amount else 0 end),0),
        coalesce(sum(case when upper(payment_method) not in ('CASH','เงินสด') then amount else 0 end),0)
 into v_customer_cash,v_customer_non_cash from public.customer_payments where shift_id=p_shift_id;
 select coalesce(sum(expense),0) into v_cash_returns from public.cash_ledger where shift_id=p_shift_id and type='RETURN';
 return jsonb_build_object(
   'shift_id',p_shift_id,'status',v_shift.status,'opening_cash',v_shift.opening_cash,
   'ledger_income',round(v_income,2),'ledger_expense',round(v_expense,2),
   'expected_cash',round(v_shift.opening_cash+v_income-v_expense,2),
   'cash_sales_reference',round(v_cash_sales,2),'transfer_sales_reference',round(v_transfer_sales,2),
   'credit_sales_reference',round(v_credit_sales,2),'customer_payments_cash_reference',round(v_customer_cash,2),
   'customer_payments_non_cash_reference',round(v_customer_non_cash,2),'cash_returns_reference',round(v_cash_returns,2),
   'closing_cash',v_shift.closing_cash,'cash_variance',v_shift.cash_variance);
end $$;

create or replace function public.close_shift(p_shift_id uuid,p_actual_cash numeric,p_close_note text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_opening numeric; v_income numeric; v_expense numeric; v_expected numeric; v_variance numeric;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 if p_actual_cash is null or p_actual_cash<0 then raise exception 'ยอดเงินสดที่นับได้ต้องเป็นศูนย์หรือมากกว่า'; end if;
 select opening_cash into v_opening from public.shifts where id=p_shift_id and status='OPEN' for update;
 if not found then raise exception 'ไม่พบกะที่เปิดอยู่'; end if;
 select coalesce(sum(income),0),coalesce(sum(expense),0) into v_income,v_expense from public.cash_ledger where shift_id=p_shift_id;
 v_expected:=round(v_opening+v_income-v_expense,2); v_variance:=round(p_actual_cash-v_expected,2);
 if v_variance<>0 and nullif(trim(coalesce(p_close_note,'')),'') is null then raise exception 'ยอดเงินสดไม่ตรง ต้องระบุสาเหตุ'; end if;
 update public.shifts set status='CLOSED',closed_at=now(),closing_cash=p_actual_cash,expected_cash=v_expected,cash_variance=v_variance,close_note=p_close_note,closed_by=public.pos_current_app_user_id() where id=p_shift_id;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'CLOSE_SHIFT','shifts',p_shift_id::text,jsonb_build_object('opening_cash',v_opening,'expected_cash',v_expected,'actual_cash',p_actual_cash,'variance',v_variance,'note',p_close_note));
 return jsonb_build_object('shift_id',p_shift_id,'expected_cash',v_expected,'actual_cash',p_actual_cash,'variance',v_variance,'status','CLOSED');
end $$;

create or replace function public.delete_entity(p_kind text,p_id uuid,p_note text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_table text; v_count int;
begin
 if not public.pos_is_authenticated_shop_user() then raise exception 'ต้องเข้าสู่ระบบบัญชีร้านก่อน'; end if;
 v_table:=case lower(p_kind) when 'product' then 'products' when 'customer' then 'customers' when 'supplier' then 'suppliers' when 'category' then 'categories' else null end;
 if v_table is null then raise exception 'ไม่รองรับการลบชนิดข้อมูล %',p_kind; end if;
 if v_table='products' then update public.products set is_active=false,updated_at=now() where id=p_id;
 elsif v_table='customers' then delete from public.customers where id=p_id;
 elsif v_table='suppliers' then delete from public.suppliers where id=p_id;
 else delete from public.categories where id=p_id; end if;
 get diagnostics v_count=row_count;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'DELETE_ENTITY',v_table,p_id::text,jsonb_build_object('note',p_note,'affected',v_count));
 return jsonb_build_object('kind',v_table,'id',p_id,'affected',v_count);
end $$;

-- RLS: only a Supabase Auth identity linked to an active shop user can use the Data API.
-- The app's PIN-only staff are actor records inside the shop session, not independent Supabase identities.
do $$ declare t text; begin
 foreach t in array array['shop_settings','app_users','categories','products','product_categories','product_variants','product_fractions','customers','customer_balances','suppliers','shifts','bills','bill_items','payments','inventory_movements','cash_ledger','customer_payments','returns','return_items','purchase_orders','purchase_order_items','accounts_payable','income_expenses','audit_logs'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists shop_authenticated_all on public.%I',t);
  execute format('create policy shop_authenticated_all on public.%I for all to authenticated using (public.pos_is_authenticated_shop_user()) with check (public.pos_is_authenticated_shop_user())',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop;
end $$;
revoke all on all tables in schema public from anon;
-- Audit history is append-only for clients: read directly, append through RPC only.
revoke insert, update, delete, truncate, references, trigger on table public.audit_logs from authenticated;
grant select on table public.audit_logs to authenticated;

-- ROUND 7 hardening: all cash/shift/AP transactions are written through RPCs.
revoke insert, update, delete, truncate, references, trigger on table
 public.bills, public.bill_items, public.payments, public.inventory_movements,
 public.customer_payments, public.returns, public.return_items,
 public.purchase_orders, public.purchase_order_items, public.income_expenses,
 public.shifts, public.cash_ledger, public.accounts_payable
from authenticated;
grant select on table
 public.bills, public.bill_items, public.payments, public.inventory_movements,
 public.customer_payments, public.returns, public.return_items,
 public.purchase_orders, public.purchase_order_items, public.income_expenses,
 public.shifts, public.cash_ledger, public.accounts_payable
to authenticated;
revoke execute on all functions in schema public from public, anon;
grant usage on schema public to authenticated;
grant execute on function public.pos_is_authenticated_shop_user() to authenticated;
grant execute on function public.pos_current_app_user_id() to authenticated;
grant execute on function public.pos_schema_version() to authenticated;
grant execute on function public.record_audit_event(text,text,text,jsonb) to authenticated;
grant execute on function public.bootstrap_first_owner(text,text) to authenticated;
grant execute on function public.seed_variant_stock(jsonb) to authenticated;
grant execute on function public.seed_customer_debt(jsonb) to authenticated;
grant execute on function public.adjust_stock(uuid,text,numeric,text,text) to authenticated;
grant execute on function public.create_sale(text,uuid,uuid,uuid,numeric,numeric,text,jsonb,boolean,text,numeric) to authenticated;
grant execute on function public.process_return(uuid,jsonb,boolean,text,uuid) to authenticated;
grant execute on function public.get_profit_report(timestamptz,timestamptz) to authenticated;
grant execute on function public.receive_customer_payment(uuid,numeric,uuid,text,text,text) to authenticated;
grant execute on function public.receive_goods(text,uuid,text,integer,timestamptz,jsonb) to authenticated;
grant execute on function public.open_shift(uuid,numeric,timestamptz) to authenticated;
grant execute on function public.record_cash_movement(uuid,text,text,numeric,text,timestamptz) to authenticated;
grant execute on function public.get_shift_reconciliation(uuid) to authenticated;
grant execute on function public.close_shift(uuid,numeric,text) to authenticated;
grant execute on function public.delete_entity(text,uuid,text) to authenticated;

-- Supabase Storage buckets used by index.html.
-- Product images and delivery-note photos are public-readable because the frontend
-- uses getPublicUrl(); only authenticated users may upload/update/delete objects.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('product-images', 'product-images', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif']),
  ('delivery-notes', 'delivery-notes', true, 15728640, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists smartpos_storage_read_public on storage.objects;
create policy smartpos_storage_read_public on storage.objects
  for select to public using (bucket_id in ('product-images','delivery-notes'));
drop policy if exists smartpos_storage_insert_authenticated on storage.objects;
create policy smartpos_storage_insert_authenticated on storage.objects
  for insert to authenticated with check (public.pos_is_authenticated_shop_user() and bucket_id in ('product-images','delivery-notes'));
drop policy if exists smartpos_storage_update_authenticated on storage.objects;
create policy smartpos_storage_update_authenticated on storage.objects
  for update to authenticated using (public.pos_is_authenticated_shop_user() and bucket_id in ('product-images','delivery-notes'))
  with check (public.pos_is_authenticated_shop_user() and bucket_id in ('product-images','delivery-notes'));
drop policy if exists smartpos_storage_delete_authenticated on storage.objects;
create policy smartpos_storage_delete_authenticated on storage.objects
  for delete to authenticated using (public.pos_is_authenticated_shop_user() and bucket_id in ('product-images','delivery-notes'));

-- Ensure the direct upserts used by index.html can read/write only after authentication.
comment on schema public is 'Smart POS single-shop schema aligned to index(20261013-181222).html; review RLS and business rules before production.';

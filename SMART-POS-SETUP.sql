-- Smart POS schema generated from index(20261013-181222).html contract
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
  balance numeric not null default 0, updated_at timestamptz not null default now()
);
create table if not exists public.suppliers (
  id uuid primary key, name text not null, phone text, address text not null default '', created_at timestamptz not null default now()
);
create table if not exists public.shifts (
  id uuid primary key, opened_at timestamptz not null default now(), closed_at timestamptz,
  opening_cash numeric not null default 0, closing_cash numeric, expected_cash numeric,
  close_note text, cash_variance numeric, status text not null default 'OPEN' check(status in ('OPEN','CLOSED')),
  opened_by uuid references public.app_users(id), closed_by uuid references public.app_users(id)
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
  method text not null, amount numeric not null default 0, reference text, created_at timestamptz not null default now()
);
create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.product_variants(id),
  change_qty numeric not null, reason text not null, ref_type text, ref_id uuid, created_at timestamptz not null default now()
);
create table if not exists public.cash_ledger (
  id uuid primary key default gen_random_uuid(), shift_id uuid references public.shifts(id), type text not null,
  income numeric not null default 0, expense numeric not null default 0, description text, ref_id text,
  created_at timestamptz not null default now(), payment_method text default 'CASH', created_by uuid references public.app_users(id)
);
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
create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(), return_id uuid not null references public.returns(id) on delete cascade,
  variant_id uuid references public.product_variants(id), fraction_id uuid references public.product_fractions(id),
  quantity numeric not null, unit_price numeric not null, line_total numeric not null default 0, stock_quantity_delta numeric not null default 0
);
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

-- Current authenticated app user, used only for actor attribution. PIN-only staff remain app_users rows.
create or replace function public.pos_current_app_user_id() returns uuid
language sql stable security definer set search_path=public,auth as $$
 select id from public.app_users where auth_user_id=auth.uid() and is_active limit 1
$$;

create or replace function public.pos_schema_version() returns jsonb
language sql stable security definer set search_path=public as $$
 select jsonb_build_object('version','index-html-contract-1','stock_table','inventory_movements','rpc_contract','index(20261013-181222).html')
$$;

create or replace function public.bootstrap_first_owner(p_name text,p_pin text) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'ต้องเข้าสู่ระบบ Supabase ก่อน'; end if;
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
 for x in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
  v_id:=(x->>'variant_id')::uuid; v_stock:=greatest(coalesce((x->>'stock')::numeric,0),0);
  update public.product_variants set stock_quantity=v_stock where id=v_id and stock_quantity=0;
  if found then
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id)
   values(v_id,v_stock,'INITIAL_STOCK','SEED',v_id); v_count:=v_count+1;
  end if;
 end loop;
 return jsonb_build_object('seeded',v_count);
end $$;

create or replace function public.seed_customer_debt(p_items jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_id uuid; v_debt numeric; v_count int:=0;
begin
 for x in select value from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
  v_id:=(x->>'customer_id')::uuid; v_debt:=greatest(coalesce((x->>'debt')::numeric,0),0);
  insert into public.customer_balances(customer_id,balance) values(v_id,v_debt)
  on conflict(customer_id) do update set balance=excluded.balance,updated_at=now()
  where public.customer_balances.balance=0;
  if found then v_count:=v_count+1; end if;
 end loop;
 return jsonb_build_object('seeded',v_count);
end $$;

create or replace function public.adjust_stock(p_variant_id uuid,p_mode text,p_value numeric,p_reason text,p_op_ref text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_old numeric; v_new numeric; v_delta numeric;
begin
 if p_op_ref is not null and exists(select 1 from public.inventory_movements where ref_type='ADJUST' and ref_id=case when p_op_ref ~* '^[0-9a-f-]{36}$' then p_op_ref::uuid else null end) then
  return jsonb_build_object('duplicate',true);
 end if;
 select stock_quantity into v_old from public.product_variants where id=p_variant_id and is_active for update;
 if not found then raise exception 'ไม่พบรุ่นสินค้าหรือถูกปิดใช้งาน'; end if;
 if upper(p_mode)='SET' then v_new:=p_value; elsif upper(p_mode)='ADD' then v_new:=v_old+p_value; elsif upper(p_mode)='SUBTRACT' then v_new:=v_old-p_value; else raise exception 'p_mode ต้องเป็น SET, ADD หรือ SUBTRACT'; end if;
 if v_new<0 then raise exception 'สต็อกต้องไม่ติดลบ'; end if;
 v_delta:=v_new-v_old;
 update public.product_variants set stock_quantity=v_new where id=p_variant_id;
 insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id)
 values(p_variant_id,v_delta,coalesce(nullif(p_reason,''),'ปรับสต็อก'),'ADJUST',case when p_op_ref ~* '^[0-9a-f-]{36}$' then p_op_ref::uuid else null end);
 return jsonb_build_object('variant_id',p_variant_id,'old_stock',v_old,'stock_quantity',v_new,'change_qty',v_delta);
end $$;

create or replace function public.create_sale(
 p_bill_number text,p_customer_id uuid,p_user_id uuid,p_shift_id uuid,p_discount_amount numeric,p_tax_amount numeric,
 p_payment_method text,p_items jsonb,p_allow_negative boolean,p_tax_mode text,p_expected_total numeric default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare x jsonb; v_bill_id uuid; v_subtotal numeric:=0; v_total numeric; v_line numeric; v_qty numeric; v_stock_qty numeric; v_ratio numeric; v_price numeric; v_variant uuid; v_fraction uuid; v_product uuid; v_name text; v_customer_balance numeric:=0; v_credit numeric:=0;
begin
 if exists(select 1 from public.bills where bill_number=p_bill_number) then
  select id,total into v_bill_id,v_total from public.bills where bill_number=p_bill_number;
  return jsonb_build_object('bill_id',v_bill_id,'total',v_total,'duplicate',true);
 end if;
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
  select coalesce(cb.balance,0),coalesce(c.credit_limit,50000) into v_customer_balance,v_credit
  from public.customers c left join public.customer_balances cb on cb.customer_id=c.id where c.id=p_customer_id for update;
  if not found then raise exception 'ไม่พบลูกค้า'; end if;
  if v_customer_balance+v_total>v_credit then raise exception 'ยอดหนี้เกินวงเงินลูกค้า'; end if;
 end if;
 insert into public.bills(bill_number,customer_id,user_id,shift_id,subtotal,discount_amount,tax_amount,total,payment_method,status,tax_mode)
 values(p_bill_number,p_customer_id,p_user_id,p_shift_id,v_subtotal,coalesce(p_discount_amount,0),coalesce(p_tax_amount,0),v_total,coalesce(p_payment_method,'CASH'),case when upper(coalesce(p_payment_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then 'CREDIT' else 'PAID' end,p_tax_mode)
 returning id into v_bill_id;
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid; v_variant:=nullif(x->>'variant_id','')::uuid; v_fraction:=nullif(x->>'fraction_id','')::uuid;
  v_qty:=(x->>'quantity')::numeric; v_price:=(x->>'unit_price')::numeric; v_name:=coalesce(x->>'item_name','สินค้า'); v_stock_qty:=v_qty;
  if v_variant is not null then
   if v_fraction is not null then select quantity_ratio into v_ratio from public.product_fractions where id=v_fraction and variant_id=v_variant; if not found then raise exception 'ไม่พบหน่วยย่อยสินค้า %',v_fraction; end if; v_stock_qty:=v_qty/v_ratio; end if;
   select stock_quantity into v_ratio from public.product_variants where id=v_variant and is_active for update;
   if not found then raise exception 'ไม่พบรุ่นสินค้า %',v_variant; end if;
   if not p_allow_negative and v_ratio<v_stock_qty then raise exception 'สต็อกไม่พอสำหรับ % (เหลือ %)',v_name,v_ratio; end if;
   update public.product_variants set stock_quantity=stock_quantity-v_stock_qty where id=v_variant;
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id) values(v_variant,-v_stock_qty,'ขายสินค้า','SALE',v_bill_id);
  end if;
  insert into public.bill_items(bill_id,product_id,variant_id,fraction_id,item_name,quantity,unit_price,line_total,stock_quantity_delta)
  values(v_bill_id,v_product,v_variant,v_fraction,v_name,v_qty,v_price,v_qty*v_price,v_stock_qty);
 end loop;
 if upper(coalesce(p_payment_method,'CASH')) in ('CREDIT','เครดิต','ON_CREDIT') then
  insert into public.customer_balances(customer_id,balance) values(p_customer_id,v_total) on conflict(customer_id) do update set balance=public.customer_balances.balance+excluded.balance,updated_at=now();
 else
  insert into public.payments(bill_id,method,amount) values(v_bill_id,upper(coalesce(p_payment_method,'CASH')),v_total);
  if upper(coalesce(p_payment_method,'CASH')) in ('CASH','เงินสด') then insert into public.cash_ledger(shift_id,type,income,description,ref_id,payment_method,created_by) values(p_shift_id,'SALE',v_total,'รับเงินขายสินค้า',v_bill_id::text,'CASH',p_user_id); end if;
 end if;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(p_user_id,'CREATE_SALE','bills',v_bill_id::text,jsonb_build_object('bill_number',p_bill_number,'total',v_total,'items',jsonb_array_length(p_items)));
 return jsonb_build_object('bill_id',v_bill_id,'bill_number',p_bill_number,'subtotal',v_subtotal,'total',v_total,'stock_updated',true);
end $$;

create or replace function public.process_return(p_bill_id uuid,p_items jsonb,p_full_return boolean,p_return_ref text default null,p_shift_id uuid default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_return_id uuid; v_total numeric:=0; v_qty numeric; v_price numeric; v_variant uuid; v_fraction uuid; v_ratio numeric; v_stock numeric; v_line numeric; v_item record;
begin
 if p_return_ref is not null and exists(select 1 from public.returns where return_ref=p_return_ref) then select id,total into v_return_id,v_total from public.returns where return_ref=p_return_ref; return jsonb_build_object('return_id',v_return_id,'total',v_total,'duplicate',true); end if;
 perform 1 from public.bills where id=p_bill_id for update; if not found then raise exception 'ไม่พบบิลต้นทาง'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'ไม่มีรายการคืนสินค้า'; end if;
 for x in select value from jsonb_array_elements(p_items) loop
  v_variant:=nullif(x->>'variant_id','')::uuid; v_fraction:=nullif(x->>'fraction_id','')::uuid; v_qty:=coalesce((x->>'quantity')::numeric,0); v_price:=coalesce((x->>'unit_price')::numeric,0);
  if v_qty<=0 then raise exception 'จำนวนคืนต้องมากกว่า 0'; end if;
  if v_variant is not null then
   select coalesce(sum(bi.quantity),0) into v_stock from public.bill_items bi where bi.bill_id=p_bill_id and bi.variant_id=v_variant and bi.fraction_id is not distinct from v_fraction;
   select coalesce(sum(ri.quantity),0) into v_ratio from public.return_items ri join public.returns r on r.id=ri.return_id where r.bill_id=p_bill_id and ri.variant_id=v_variant and ri.fraction_id is not distinct from v_fraction;
   if v_qty>v_stock-v_ratio then raise exception 'จำนวนคืนเกินจำนวนที่ขาย'; end if;
  end if;
  v_total:=v_total+v_qty*v_price;
 end loop;
 insert into public.returns(bill_id,return_ref,shift_id,total,full_return,created_by) values(p_bill_id,p_return_ref,p_shift_id,v_total,p_full_return,public.pos_current_app_user_id()) returning id into v_return_id;
 for x in select value from jsonb_array_elements(p_items) loop
  v_variant:=nullif(x->>'variant_id','')::uuid; v_fraction:=nullif(x->>'fraction_id','')::uuid; v_qty:=(x->>'quantity')::numeric; v_price:=(x->>'unit_price')::numeric; v_stock:=v_qty;
  if v_variant is not null then
   if v_fraction is not null then select quantity_ratio into v_ratio from public.product_fractions where id=v_fraction; v_stock:=v_qty/coalesce(nullif(v_ratio,0),1); end if;
   update public.product_variants set stock_quantity=stock_quantity+v_stock where id=v_variant;
   insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id) values(v_variant,v_stock,'คืนสินค้า','RETURN',v_return_id);
  end if;
  insert into public.return_items(return_id,variant_id,fraction_id,quantity,unit_price,line_total,stock_quantity_delta) values(v_return_id,v_variant,v_fraction,v_qty,v_price,v_qty*v_price,v_stock);
 end loop;
 insert into public.cash_ledger(shift_id,type,expense,description,ref_id,payment_method) values(p_shift_id,'RETURN',v_total,'คืนเงินลูกค้า',v_return_id::text,'CASH');
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'PROCESS_RETURN','returns',v_return_id::text,jsonb_build_object('bill_id',p_bill_id,'total',v_total));
 return jsonb_build_object('return_id',v_return_id,'total',v_total,'stock_restored',true);
end $$;

create or replace function public.receive_customer_payment(p_customer_id uuid,p_amount numeric,p_shift_id uuid,p_op_ref text default null,p_payment_method text default 'CASH',p_reference text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_balance numeric;
begin
 if p_amount<=0 then raise exception 'ยอดรับชำระต้องมากกว่า 0'; end if;
 if p_op_ref is not null then select id into v_id from public.customer_payments where op_ref=p_op_ref; if v_id is not null then return jsonb_build_object('payment_id',v_id,'duplicate',true); end if; end if;
 perform 1 from public.customers where id=p_customer_id for update; if not found then raise exception 'ไม่พบลูกค้า'; end if;
 insert into public.customer_payments(customer_id,amount,shift_id,payment_method,reference,op_ref,received_by)
 values(p_customer_id,p_amount,p_shift_id,upper(p_payment_method),p_reference,p_op_ref,public.pos_current_app_user_id()) returning id into v_id;
 insert into public.customer_balances(customer_id,balance) values(p_customer_id,-p_amount) on conflict(customer_id) do update set balance=greatest(0,public.customer_balances.balance-p_amount),updated_at=now();
 select balance into v_balance from public.customer_balances where customer_id=p_customer_id;
 insert into public.cash_ledger(shift_id,type,income,description,ref_id,payment_method) values(p_shift_id,'CUSTOMER_PAYMENT',case when upper(p_payment_method) in ('CASH','เงินสด') then p_amount else 0 end,'รับชำระหนี้ลูกค้า',v_id::text,upper(p_payment_method));
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'CUSTOMER_PAYMENT','customer_payments',v_id::text,jsonb_build_object('customer_id',p_customer_id,'amount',p_amount));
 return jsonb_build_object('payment_id',v_id,'customer_id',p_customer_id,'amount',p_amount,'balance',v_balance);
end $$;

create or replace function public.receive_goods(p_client_ref text,p_supplier_id uuid,p_doc_ref text,p_terms integer,p_received_at timestamptz,p_items jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; v_po uuid; v_ap uuid; v_variant uuid; v_product uuid; v_qty numeric; v_cost numeric; v_total numeric:=0; v_name text;
begin
 if p_client_ref is not null then select id into v_po from public.purchase_orders where client_ref=p_client_ref; if v_po is not null then select id into v_ap from public.accounts_payable where purchase_order_id=v_po; return jsonb_build_object('po_id',v_po,'ap_id',v_ap,'duplicate',true); end if; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'ไม่มีรายการรับสินค้า'; end if;
 insert into public.purchase_orders(client_ref,supplier_id,doc_ref,terms,received_at,created_by) values(p_client_ref,p_supplier_id,p_doc_ref,coalesce(p_terms,30),coalesce(p_received_at,now()),public.pos_current_app_user_id()) returning id into v_po;
 for x in select value from jsonb_array_elements(p_items) loop
  v_product:=nullif(x->>'product_id','')::uuid; v_variant:=nullif(x->>'variant_id','')::uuid; v_qty:=coalesce((x->>'quantity')::numeric,0); v_cost:=coalesce((x->>'unit_cost')::numeric,0);
  if v_qty<=0 or v_cost<0 then raise exception 'จำนวนหรือทุนรับสินค้าไม่ถูกต้อง'; end if;
  if v_variant is null then raise exception 'รายการรับสินค้าต้องระบุ variant_id'; end if;
  update public.product_variants set stock_quantity=stock_quantity+v_qty,cost_price=v_cost where id=v_variant;
  if not found then raise exception 'ไม่พบรุ่นสินค้า %',v_variant; end if;
  insert into public.inventory_movements(variant_id,change_qty,reason,ref_type,ref_id) values(v_variant,v_qty,'รับสินค้าเข้าสต็อก','PURCHASE',v_po);
  insert into public.purchase_order_items(purchase_order_id,product_id,variant_id,quantity,unit_cost,line_total) values(v_po,v_product,v_variant,v_qty,v_cost,v_qty*v_cost);
  v_total:=v_total+v_qty*v_cost;
 end loop;
 update public.purchase_orders set total=v_total where id=v_po;
 insert into public.accounts_payable(supplier_id,purchase_order_id,doc_ref,amount,credit_terms,status) values(p_supplier_id,v_po,p_doc_ref,v_total,coalesce(p_terms,30),'OPEN') returning id into v_ap;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'RECEIVE_GOODS','purchase_orders',v_po::text,jsonb_build_object('total',v_total,'items',jsonb_array_length(p_items)));
 return jsonb_build_object('po_id',v_po,'ap_id',v_ap,'total',v_total);
end $$;

create or replace function public.close_shift(p_shift_id uuid,p_actual_cash numeric,p_close_note text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_opening numeric; v_income numeric; v_expense numeric; v_expected numeric; v_variance numeric;
begin
 select opening_cash into v_opening from public.shifts where id=p_shift_id and status='OPEN' for update;
 if not found then raise exception 'ไม่พบกะที่เปิดอยู่'; end if;
 select coalesce(sum(income),0),coalesce(sum(expense),0) into v_income,v_expense from public.cash_ledger where shift_id=p_shift_id;
 v_expected:=v_opening+v_income-v_expense; v_variance:=p_actual_cash-v_expected;
 if v_variance<>0 and nullif(trim(coalesce(p_close_note,'')),'') is null then raise exception 'ยอดเงินสดไม่ตรง ต้องระบุสาเหตุ'; end if;
 update public.shifts set status='CLOSED',closed_at=now(),closing_cash=p_actual_cash,expected_cash=v_expected,cash_variance=v_variance,close_note=p_close_note,closed_by=public.pos_current_app_user_id() where id=p_shift_id;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,details) values(public.pos_current_app_user_id(),'CLOSE_SHIFT','shifts',p_shift_id::text,jsonb_build_object('opening_cash',v_opening,'expected_cash',v_expected,'actual_cash',p_actual_cash,'variance',v_variance,'note',p_close_note));
 return jsonb_build_object('shift_id',p_shift_id,'expected_cash',v_expected,'actual_cash',p_actual_cash,'variance',v_variance,'status','CLOSED');
end $$;

create or replace function public.delete_entity(p_kind text,p_id uuid,p_note text default null) returns jsonb
language plpgsql security definer set search_path=public as $$
declare v_table text; v_count int;
begin
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

-- RLS: signed-in users may operate the single shop. Never grant anon table access.
do $$ declare t text; begin
 foreach t in array array['shop_settings','app_users','categories','products','product_categories','product_variants','product_fractions','customers','customer_balances','suppliers','shifts','bills','bill_items','payments','inventory_movements','cash_ledger','customer_payments','returns','return_items','purchase_orders','purchase_order_items','accounts_payable','income_expenses','audit_logs'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists shop_authenticated_all on public.%I',t);
  execute format('create policy shop_authenticated_all on public.%I for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null)',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop;
end $$;
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant execute on function public.pos_schema_version() to authenticated;
grant execute on function public.bootstrap_first_owner(text,text) to authenticated;
grant execute on function public.seed_variant_stock(jsonb) to authenticated;
grant execute on function public.seed_customer_debt(jsonb) to authenticated;
grant execute on function public.adjust_stock(uuid,text,numeric,text,text) to authenticated;
grant execute on function public.create_sale(text,uuid,uuid,uuid,numeric,numeric,text,jsonb,boolean,text,numeric) to authenticated;
grant execute on function public.process_return(uuid,jsonb,boolean,text,uuid) to authenticated;
grant execute on function public.receive_customer_payment(uuid,numeric,uuid,text,text,text) to authenticated;
grant execute on function public.receive_goods(text,uuid,text,integer,timestamptz,jsonb) to authenticated;
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
  for insert to authenticated with check (bucket_id in ('product-images','delivery-notes'));
drop policy if exists smartpos_storage_update_authenticated on storage.objects;
create policy smartpos_storage_update_authenticated on storage.objects
  for update to authenticated using (bucket_id in ('product-images','delivery-notes'))
  with check (bucket_id in ('product-images','delivery-notes'));
drop policy if exists smartpos_storage_delete_authenticated on storage.objects;
create policy smartpos_storage_delete_authenticated on storage.objects
  for delete to authenticated using (bucket_id in ('product-images','delivery-notes'));

-- Ensure the direct upserts used by index.html can read/write only after authentication.
comment on schema public is 'Smart POS single-shop schema aligned to index(20261013-181222).html; review RLS and business rules before production.';

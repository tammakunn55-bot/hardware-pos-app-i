-- SMART POS ROUND 14: READ-ONLY SCHEMA VERIFICATION
-- Run this after SMART-POS-SETUP.sql in Supabase SQL Editor.
-- These queries inspect schema only; they do not alter or delete shop data.

-- 1) Contract marker and installed RPCs
select public.pos_schema_version() as installed_contract;
select p.proname as function_name, pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as result_type
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
 'pos_schema_version','create_sale','process_return','receive_customer_payment','receive_goods',
 'adjust_stock','open_shift','record_cash_movement','get_shift_reconciliation','close_shift','get_profit_report'
)
order by p.proname, arguments;

-- 2) Required columns that the current HTML/RPC contract depends on
with expected(table_name,column_name) as (
 values
 ('app_users','auth_user_id'),('app_users','is_active'),
 ('product_variants','stock_quantity'),('product_variants','cost_price'),
 ('bills','bill_number'),('bills','shift_id'),('bills','payment_method'),('bills','total'),
 ('bill_items','cost_total_at_sale'),('return_items','cost_total_at_return'),
 ('returns','return_ref'),('returns','shift_id'),
 ('cash_ledger','operation_key'),('cash_ledger','shift_id'),('cash_ledger','income'),('cash_ledger','expense'),
 ('customer_payments','op_ref'),('customer_payments','shift_id'),
 ('shifts','opening_cash'),('shifts','status'),('shifts','expected_cash'),('shifts','cash_variance'),
 ('accounts_payable','purchase_order_id'),('purchase_orders','client_ref')
)
select e.table_name,e.column_name,
       case when c.column_name is null then 'MISSING' else 'OK' end as status
from expected e left join information_schema.columns c
  on c.table_schema='public' and c.table_name=e.table_name and c.column_name=e.column_name
order by status desc,e.table_name,e.column_name;

-- 3) RLS state on important business tables
select c.relname as table_name,c.relrowsecurity as rls_enabled,c.relforcerowsecurity as rls_forced
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r'
  and c.relname in ('app_users','products','product_variants','bills','bill_items','shifts','cash_ledger','customer_payments','returns','accounts_payable','audit_logs')
order by c.relname;

-- 4) Policies for important business tables
select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies
where schemaname='public' and tablename in ('app_users','products','product_variants','bills','bill_items','shifts','cash_ledger','customer_payments','returns','accounts_payable','audit_logs')
order by tablename,policyname;

-- 5) Check duplicate / missing idempotency keys on historical records
select 'returns_without_return_ref' as check_name,count(*) as affected_rows from public.returns where return_ref is null
union all
select 'customer_payments_without_op_ref',count(*) from public.customer_payments where op_ref is null
union all
select 'purchase_orders_without_client_ref',count(*) from public.purchase_orders where client_ref is null;

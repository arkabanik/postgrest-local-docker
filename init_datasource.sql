-- ============================================================================
-- abeg_invt  —  PostgreSQL schema + dummy data (converted from MariaDB dumps)
-- Target: PostgreSQL 15+
-- Business keys vendor_id, customer_id, order_id, product_master_sku are
-- unique on their own so every foreign key resolves in PostgreSQL.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS api;

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;

-- ---------------------------------------------------------------------------
-- ENUM TYPES
-- ---------------------------------------------------------------------------
CREATE TYPE api.currency_code_enum        AS ENUM ('INR');
CREATE TYPE api.vendor_status_enum        AS ENUM ('ACTIVE','INACTIVE');
CREATE TYPE api.customer_status_enum      AS ENUM ('ACTIVE','INACTIVE','BLOCKED');
CREATE TYPE api.customer_type_code_enum   AS ENUM ('RC','MC','EC');
CREATE TYPE api.customer_type_enum        AS ENUM ('Retail','Media','Ecomm');
CREATE TYPE api.batch_status_enum         AS ENUM ('PLACED','SHIPPED','RECEIVED','CONFIRMED');
CREATE TYPE api.product_status_enum       AS ENUM ('DRAFT','OFFLINE','PUBLISHED');
CREATE TYPE api.product_item_status_enum  AS ENUM ('AVAILABLE','RESERVED','SOLD','RETURNED','REJECTED');
CREATE TYPE api.product_media_type_enum   AS ENUM ('JPG','PNG','WEBP','MP4');
CREATE TYPE api.order_type_enum           AS ENUM ('STANDARD','RETURN','ADHOC');
CREATE TYPE api.order_channel_enum        AS ENUM ('WEBSITE','INSTAGRAM','WHATSAPP','FACEBOOK','RETAIL','STALL');
CREATE TYPE api.order_status_enum         AS ENUM ('PLACED','CONFIRMED','PACKED','DISPATCHED','OUT_FOR_DELIVERY','DELIVERED','FULFILLED','CANCELLED','RETURN_INITIATED','REPLACEMENT_INITIATED');
CREATE TYPE api.order_address_type_enum   AS ENUM ('SHIPPING','BILLING');
CREATE TYPE api.order_payment_type_enum   AS ENUM ('PREPAID','COD');
CREATE TYPE api.order_payment_method_enum AS ENUM ('DEBIT_CARD','CREDIT_CARD','UPI','COD','CASH');
CREATE TYPE api.order_payment_status_enum AS ENUM ('PAID','PENDING','FAILED','REFUNDED','OUTSTANDING');

-- ---------------------------------------------------------------------------
-- pickup_addresses  (not in the MariaDB dumps; minimal table so
-- order_delivery_details.pickup_address_id has a target)
-- ---------------------------------------------------------------------------
CREATE TABLE api.pickup_addresses (
pickup_address_id        integer GENERATED ALWAYS AS IDENTITY,
pickup_address_name      varchar(200) NOT NULL,
pickup_address_complete  varchar(500) NOT NULL,
pickup_address_pincode   varchar(10)  NOT NULL,
pickup_address_city      varchar(100) NOT NULL,
pickup_address_state     varchar(100) NOT NULL,
pickup_address_country   varchar(100) NOT NULL DEFAULT 'India',
pickup_address_phone     varchar(15)  DEFAULT NULL,
pickup_address_is_active boolean      NOT NULL DEFAULT TRUE,
_creation_date           timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date             timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_pickup_addresses PRIMARY KEY (pickup_address_id)
);
CREATE INDEX ix_pickup_addresses_expiry ON api.pickup_addresses (_expiry_date);

-- ---------------------------------------------------------------------------
-- vendors
-- ---------------------------------------------------------------------------
CREATE TABLE api.vendors (
_id            bigint GENERATED ALWAYS AS IDENTITY,
vendor_id      varchar(15)  NOT NULL,
vendor_name    varchar(200) NOT NULL,
vendor_code    varchar(10)  NOT NULL,
vendor_city    varchar(100) DEFAULT NULL,
vendor_state   varchar(100) DEFAULT NULL,
vendor_country varchar(100) NOT NULL DEFAULT 'India',
vendor_gstin   varchar(15)  DEFAULT NULL,
vendor_status  api.vendor_status_enum NOT NULL DEFAULT 'ACTIVE',
_creation_date timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date   timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_vendors PRIMARY KEY (_id),
CONSTRAINT uq_vendors_vendor_id UNIQUE (vendor_id),
CONSTRAINT uq_vendors_vendor_code UNIQUE (vendor_code, _expiry_date)
);
CREATE INDEX ix_vendors_expiry ON api.vendors (_expiry_date);

-- ---------------------------------------------------------------------------
-- vendor_pii
-- ---------------------------------------------------------------------------
CREATE TABLE api.vendor_pii (
_id                     bigint GENERATED ALWAYS AS IDENTITY,
vendor_id               varchar(15)  NOT NULL,
vendor_address          varchar(300) DEFAULT NULL,
vendor_pincode          varchar(10)  DEFAULT NULL,
vendor_contact_name     varchar(200) DEFAULT NULL,
vendor_contact_phone    varchar(15)  DEFAULT NULL,
vendor_alternate_number varchar(15)  DEFAULT NULL,
vendor_contact_email    public.citext       DEFAULT NULL,
_creation_date          timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date            timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_vendor_pii PRIMARY KEY (_id),
CONSTRAINT uq_vendor_pii_vendor_id UNIQUE (vendor_id, _expiry_date),
CONSTRAINT fk_vendor_pii_vendor FOREIGN KEY (vendor_id) REFERENCES api.vendors (vendor_id) ON UPDATE CASCADE,
CONSTRAINT ck_vendor_pii_email_len CHECK (char_length(vendor_contact_email) <= 255)
);
CREATE INDEX ix_vendor_pii_expiry ON api.vendor_pii (_expiry_date);

-- ---------------------------------------------------------------------------
-- customers
-- ---------------------------------------------------------------------------
CREATE TABLE api.customers (
_id                   bigint GENERATED ALWAYS AS IDENTITY,
customer_id           varchar(15)  NOT NULL,
customer_first_name   varchar(100) NOT NULL,
customer_last_name    varchar(100) DEFAULT NULL,
customer_status       api.customer_status_enum NOT NULL DEFAULT 'ACTIVE',
customer_type_code    api.customer_type_code_enum DEFAULT NULL,
customer_type         api.customer_type_enum DEFAULT NULL,
customer_joining_date date NOT NULL DEFAULT CURRENT_DATE,
_creation_date        timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date          timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_customers PRIMARY KEY (_id),
CONSTRAINT uq_customers_customer_id UNIQUE (customer_id),
CONSTRAINT ck_customers_type_match CHECK (
(customer_type_code IS NULL AND customer_type IS NULL)
OR (customer_type_code = 'RC' AND customer_type = 'Retail')
OR (customer_type_code = 'MC' AND customer_type = 'Media')
OR (customer_type_code = 'EC' AND customer_type = 'Ecomm'))
);
CREATE INDEX ix_customers_expiry ON api.customers (_expiry_date);

-- ---------------------------------------------------------------------------
-- customer_pii
-- ---------------------------------------------------------------------------
CREATE TABLE api.customer_pii (
_id                       bigint GENERATED ALWAYS AS IDENTITY,
customer_id               varchar(15) NOT NULL,
customer_phone_number     varchar(15) DEFAULT NULL,
customer_alt_phone_number varchar(15) DEFAULT NULL,
customer_email            public.citext      DEFAULT NULL,
customer_date_of_birth    date        DEFAULT NULL,
_creation_date            timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date              timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_customer_pii PRIMARY KEY (_id),
CONSTRAINT uq_customer_pii_customer_id UNIQUE (customer_id, _expiry_date),
CONSTRAINT uq_customer_pii_phone UNIQUE (customer_phone_number, _expiry_date),
CONSTRAINT uq_customer_pii_email UNIQUE (customer_email, _expiry_date),
CONSTRAINT fk_customer_pii_customer FOREIGN KEY (customer_id) REFERENCES api.customers (customer_id) ON UPDATE CASCADE,
CONSTRAINT ck_customer_pii_email_len CHECK (char_length(customer_email) <= 255)
);
CREATE INDEX ix_customer_pii_expiry ON api.customer_pii (_expiry_date);

-- ---------------------------------------------------------------------------
-- batches
-- ---------------------------------------------------------------------------
CREATE TABLE api.batches (
_id                 bigint GENERATED ALWAYS AS IDENTITY,
batch_id            varchar(15) NOT NULL,
vendor_id           varchar(15) NOT NULL,
batch_order_date    date DEFAULT NULL,
batch_received_date date DEFAULT NULL,
batch_status        api.batch_status_enum NOT NULL DEFAULT 'PLACED',
_creation_date      timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date        timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_batches PRIMARY KEY (_id),
CONSTRAINT uq_batches_batch_id UNIQUE (batch_id),
CONSTRAINT fk_batches_vendor FOREIGN KEY (vendor_id) REFERENCES api.vendors (vendor_id) ON UPDATE CASCADE
);
CREATE INDEX ix_batches_vendor ON api.batches (vendor_id);
CREATE INDEX ix_batches_expiry ON api.batches (_expiry_date);

-- ---------------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------------
CREATE TABLE api.products (
_id                              bigint GENERATED ALWAYS AS IDENTITY,
product_name                     varchar(200) DEFAULT NULL,
product_code                     varchar(20)  NOT NULL,
product_sku                      varchar(100) NOT NULL,
product_master_qr_code           varchar(255) DEFAULT NULL,
product_type                     varchar(100) DEFAULT NULL,
product_type_code                varchar(10)  DEFAULT NULL,
product_attribute_json           jsonb        DEFAULT NULL,
product_sell_price               numeric(12,2) NOT NULL DEFAULT 0.00,
product_sell_price_currency      api.currency_code_enum NOT NULL DEFAULT 'INR',
product_price_category_code      varchar(10)  DEFAULT NULL,
product_discount_code            varchar(50)  DEFAULT NULL,
product_discount_amount          numeric(12,2) NOT NULL DEFAULT 0.00,
product_discount_amount_currency api.currency_code_enum NOT NULL DEFAULT 'INR',
product_status                   api.product_status_enum NOT NULL DEFAULT 'DRAFT',
product_description              text         DEFAULT NULL,
product_hsn_code                 varchar(8)   DEFAULT NULL,
product_tax_rate                 numeric(5,2) DEFAULT NULL,
vendor_id                        varchar(15)  NOT NULL,
vendor_code                      varchar(10)  NOT NULL,
_creation_date                   timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date                     timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_products PRIMARY KEY (_id),
CONSTRAINT uq_products_sku UNIQUE (product_sku),
CONSTRAINT fk_products_vendor FOREIGN KEY (vendor_id) REFERENCES api.vendors (vendor_id) ON UPDATE CASCADE,
CONSTRAINT ck_products_sell_price CHECK (product_sell_price >= 0),
CONSTRAINT ck_products_discount CHECK (product_discount_amount >= 0 AND product_discount_amount <= product_sell_price),
CONSTRAINT ck_products_tax_rate CHECK (product_tax_rate IS NULL OR product_tax_rate BETWEEN 0 AND 100)
);
CREATE INDEX ix_products_product_code ON api.products (product_code);
CREATE INDEX ix_products_vendor ON api.products (vendor_id);
CREATE INDEX ix_products_status ON api.products (product_status);
CREATE INDEX ix_products_expiry ON api.products (_expiry_date);

-- ---------------------------------------------------------------------------
-- product_media   (_primary_sku dropped; one-primary rule is a partial index)
-- ---------------------------------------------------------------------------
CREATE TABLE api.product_media (
_id                      bigint GENERATED ALWAYS AS IDENTITY,
product_sku              varchar(100) NOT NULL,
product_media_path       varchar(255) NOT NULL DEFAULT '/assets/img/',
product_media_filename   varchar(255) NOT NULL,
product_media_type       api.product_media_type_enum NOT NULL,
product_media_sort_order integer NOT NULL DEFAULT 0,
product_media_is_primary boolean NOT NULL DEFAULT FALSE,
product_media_alt_text   varchar(255) DEFAULT NULL,
_creation_date           timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date             timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_product_media PRIMARY KEY (_id),
CONSTRAINT uq_product_media_file UNIQUE (product_sku, product_media_path, product_media_filename),
CONSTRAINT fk_product_media_product FOREIGN KEY (product_sku) REFERENCES api.products (product_sku) ON UPDATE CASCADE,
CONSTRAINT ck_product_media_sort_order CHECK (product_media_sort_order BETWEEN 0 AND 65535)
);
CREATE UNIQUE INDEX uq_product_media_one_primary ON api.product_media (product_sku) WHERE product_media_is_primary;
CREATE INDEX ix_product_media_order ON api.product_media (product_sku, product_media_sort_order);

-- ---------------------------------------------------------------------------
-- product_item
-- ---------------------------------------------------------------------------
CREATE TABLE api.product_item (
_id                        bigint GENERATED ALWAYS AS IDENTITY,
product_id                 varchar(100) NOT NULL,
product_sl_number          char(3)      NOT NULL,
product_sku                varchar(100) NOT NULL,
product_master_sku         varchar(100) NOT NULL,
product_buy_price          numeric(12,2) NOT NULL DEFAULT 0.00,
product_buy_currency       api.currency_code_enum NOT NULL DEFAULT 'INR',
product_item_status        api.product_item_status_enum NOT NULL DEFAULT 'AVAILABLE',
product_item_status_reason varchar(255) DEFAULT NULL,
comment                    text         DEFAULT NULL,
batch_id                   varchar(15)  NOT NULL,
_creation_date             timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date               timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_product_item PRIMARY KEY (_id),
CONSTRAINT uq_product_item_master_sku UNIQUE (product_master_sku),
CONSTRAINT uq_product_item_product_id UNIQUE (product_id, _expiry_date),
CONSTRAINT fk_product_item_batch FOREIGN KEY (batch_id) REFERENCES api.batches (batch_id) ON UPDATE CASCADE,
CONSTRAINT fk_product_item_product FOREIGN KEY (product_sku) REFERENCES api.products (product_sku) ON UPDATE CASCADE,
CONSTRAINT ck_product_item_buy_price CHECK (product_buy_price >= 0)
);
COMMENT ON COLUMN api.product_item.product_item_status_reason IS 'why product_item_status last changed; not a note about the piece';
CREATE INDEX ix_product_item_sku ON api.product_item (product_sku);
CREATE INDEX ix_product_item_batch ON api.product_item (batch_id);
CREATE INDEX ix_product_item_status ON api.product_item (product_item_status);
CREATE INDEX ix_product_item_expiry ON api.product_item (_expiry_date);

-- ---------------------------------------------------------------------------
-- orders
-- ---------------------------------------------------------------------------
CREATE TABLE api.orders (
_id                            bigint GENERATED ALWAYS AS IDENTITY,
order_id                       varchar(30) NOT NULL,
customer_id                    varchar(15) NOT NULL,
order_type                     api.order_type_enum NOT NULL DEFAULT 'STANDARD',
original_order_id              varchar(30) DEFAULT NULL,
order_channel                  api.order_channel_enum NOT NULL,
order_coupon_code              varchar(50) DEFAULT NULL,
order_coupon_discount          numeric(12,2) NOT NULL DEFAULT 0.00,
order_coupon_discount_currency api.currency_code_enum NOT NULL DEFAULT 'INR',
order_date_time                timestamptz(6) NOT NULL DEFAULT now(),
order_status                   api.order_status_enum NOT NULL DEFAULT 'PLACED',
contain_documents              boolean NOT NULL DEFAULT FALSE,
order_total_amount             numeric(12,2) DEFAULT NULL,
order_total_amount_currency    api.currency_code_enum NOT NULL DEFAULT 'INR',
_creation_date                 timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date                   timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_orders PRIMARY KEY (_id),
CONSTRAINT uq_orders_order_id UNIQUE (order_id),
CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES api.customers (customer_id) ON UPDATE CASCADE,
CONSTRAINT fk_orders_original_order FOREIGN KEY (original_order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE,
CONSTRAINT ck_orders_return_original CHECK ((order_type = 'RETURN') = (original_order_id IS NOT NULL)),
CONSTRAINT ck_orders_not_self CHECK (original_order_id IS NULL OR original_order_id <> order_id),
CONSTRAINT ck_orders_coupon_discount CHECK (order_coupon_discount >= 0),
CONSTRAINT ck_orders_total CHECK (order_total_amount IS NULL OR order_total_amount >= 0)
);
COMMENT ON COLUMN api.orders.original_order_id IS 'RETURN orders only: the order this one reverses';
CREATE INDEX ix_orders_customer ON api.orders (customer_id);
CREATE INDEX ix_orders_status ON api.orders (order_status);
CREATE INDEX ix_orders_date ON api.orders (order_date_time);
CREATE INDEX ix_orders_expiry ON api.orders (_expiry_date);
CREATE INDEX ix_orders_original ON api.orders (original_order_id);

-- ---------------------------------------------------------------------------
-- order_addresses
-- ---------------------------------------------------------------------------
CREATE TABLE api.order_addresses (
_id                    bigint GENERATED ALWAYS AS IDENTITY,
order_id               varchar(30)  NOT NULL,
order_address_type     api.order_address_type_enum NOT NULL,
order_address_complete varchar(500) NOT NULL,
order_address_landmark varchar(255) DEFAULT NULL,
order_address_pincode  varchar(10)  NOT NULL,
order_address_city     varchar(100) NOT NULL,
order_address_state    varchar(100) NOT NULL,
order_address_country  varchar(100) NOT NULL DEFAULT 'India',
_creation_date         timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date           timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_order_addresses PRIMARY KEY (_id),
CONSTRAINT uq_order_addresses_type UNIQUE (order_id, order_address_type, _expiry_date),
CONSTRAINT fk_order_addresses_order FOREIGN KEY (order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE
);
CREATE INDEX ix_order_addresses_pincode ON api.order_addresses (order_address_pincode);
CREATE INDEX ix_order_addresses_expiry ON api.order_addresses (_expiry_date);

-- ---------------------------------------------------------------------------
-- order_charges
-- ---------------------------------------------------------------------------
CREATE TABLE api.order_charges (
_id                             bigint GENERATED ALWAYS AS IDENTITY,
order_id                        varchar(30) NOT NULL,
order_delivery_charges          numeric(12,2) NOT NULL DEFAULT 0.00,
order_delivery_charges_currency api.currency_code_enum NOT NULL DEFAULT 'INR',
order_packing_charges           numeric(12,2) NOT NULL DEFAULT 0.00,
order_packing_charges_currency  api.currency_code_enum NOT NULL DEFAULT 'INR',
order_cod_charges               numeric(12,2) NOT NULL DEFAULT 0.00,
order_cod_charges_currency      api.currency_code_enum NOT NULL DEFAULT 'INR',
order_transaction_fee           numeric(12,2) NOT NULL DEFAULT 0.00,
order_transaction_fee_currency  api.currency_code_enum NOT NULL DEFAULT 'INR',
order_goodies_charges           numeric(12,2) NOT NULL DEFAULT 0.00,
order_goodies_charges_currency  api.currency_code_enum NOT NULL DEFAULT 'INR',
_creation_date                  timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date                    timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_order_charges PRIMARY KEY (_id),
CONSTRAINT uq_order_charges_order UNIQUE (order_id, _expiry_date),
CONSTRAINT fk_order_charges_order FOREIGN KEY (order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE,
CONSTRAINT ck_order_charges_non_negative CHECK (
order_delivery_charges >= 0 AND order_packing_charges >= 0 AND order_cod_charges >= 0
AND order_transaction_fee >= 0 AND order_goodies_charges >= 0)
);
CREATE INDEX ix_order_charges_expiry ON api.order_charges (_expiry_date);

-- ---------------------------------------------------------------------------
-- order_delivery_details
-- ---------------------------------------------------------------------------
CREATE TABLE api.order_delivery_details (
_id               bigint GENERATED ALWAYS AS IDENTITY,
order_id          varchar(30)  NOT NULL,
order_tag         varchar(50)  DEFAULT NULL,
pickup_address_id integer      DEFAULT NULL,
reseller_name     varchar(200) DEFAULT NULL,
send_notification boolean NOT NULL DEFAULT TRUE,
verified_order    boolean NOT NULL DEFAULT FALSE,
_creation_date    timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date      timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_order_delivery_details PRIMARY KEY (_id),
CONSTRAINT uq_odd_order UNIQUE (order_id, _expiry_date),
CONSTRAINT fk_odd_order FOREIGN KEY (order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE,
CONSTRAINT fk_odd_pickup FOREIGN KEY (pickup_address_id) REFERENCES api.pickup_addresses (pickup_address_id) ON UPDATE CASCADE
);
CREATE INDEX ix_odd_pickup ON api.order_delivery_details (pickup_address_id);
CREATE INDEX ix_odd_expiry ON api.order_delivery_details (_expiry_date);

-- ---------------------------------------------------------------------------
-- order_items   (order_item_net_price is generated: price - discount)
-- ---------------------------------------------------------------------------
CREATE TABLE api.order_items (
_id                          bigint GENERATED ALWAYS AS IDENTITY,
order_id                     varchar(30)  NOT NULL,
product_sku                  varchar(100) NOT NULL,
product_master_sku           varchar(100) DEFAULT NULL,
order_item_price             numeric(12,2) NOT NULL DEFAULT 0.00,
order_item_price_currency    api.currency_code_enum NOT NULL DEFAULT 'INR',
order_item_discount          numeric(12,2) NOT NULL DEFAULT 0.00,
order_item_discount_currency api.currency_code_enum NOT NULL DEFAULT 'INR',
order_item_net_price         numeric(12,2) GENERATED ALWAYS AS (order_item_price - order_item_discount) STORED,
_creation_date               timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date                 timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_order_items PRIMARY KEY (_id),
CONSTRAINT uq_order_items_line UNIQUE (order_id, product_master_sku, _expiry_date),
CONSTRAINT fk_order_items_item FOREIGN KEY (product_master_sku) REFERENCES api.product_item (product_master_sku) ON UPDATE CASCADE,
CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE,
CONSTRAINT fk_order_items_sku FOREIGN KEY (product_sku) REFERENCES api.products (product_sku) ON UPDATE CASCADE,
CONSTRAINT ck_order_items_amounts CHECK (order_item_price >= 0 AND order_item_discount >= 0 AND order_item_discount <= order_item_price)
);
CREATE INDEX ix_order_items_product ON api.order_items (product_master_sku);
CREATE INDEX ix_order_items_expiry ON api.order_items (_expiry_date);
CREATE INDEX ix_order_items_sku ON api.order_items (product_sku);

-- ---------------------------------------------------------------------------
-- order_payments
-- ---------------------------------------------------------------------------
CREATE TABLE api.order_payments (
_id                                   bigint GENERATED ALWAYS AS IDENTITY,
order_id                              varchar(30) NOT NULL,
order_payment_type                    api.order_payment_type_enum NOT NULL,
order_payment_method                  api.order_payment_method_enum NOT NULL,
order_payment_partial_cod             boolean NOT NULL DEFAULT FALSE,
order_payment_paid_amount             numeric(12,2) NOT NULL DEFAULT 0.00,
order_payment_paid_amount_currency    api.currency_code_enum NOT NULL DEFAULT 'INR',
order_payment_pending_amount          numeric(12,2) NOT NULL DEFAULT 0.00,
order_payment_pending_amount_currency api.currency_code_enum NOT NULL DEFAULT 'INR',
order_payment_status                  api.order_payment_status_enum NOT NULL DEFAULT 'OUTSTANDING',
_creation_date                        timestamptz(6) NOT NULL DEFAULT now(),
_expiry_date                          timestamptz(6) NOT NULL DEFAULT '9999-12-01 00:00:00+00',
CONSTRAINT pk_order_payments PRIMARY KEY (_id),
CONSTRAINT fk_order_payments_order FOREIGN KEY (order_id) REFERENCES api.orders (order_id) ON UPDATE CASCADE,
CONSTRAINT ck_order_payments_amounts CHECK (order_payment_paid_amount >= 0 AND order_payment_pending_amount >= 0),
CONSTRAINT ck_order_payments_cod_method CHECK (order_payment_method <> 'COD' OR order_payment_type = 'COD'),
CONSTRAINT ck_order_payments_partial_cod CHECK (NOT order_payment_partial_cod OR order_payment_type = 'COD')
);
CREATE INDEX ix_order_payments_order ON api.order_payments (order_id);
CREATE INDEX ix_order_payments_status ON api.order_payments (order_payment_status);
CREATE INDEX ix_order_payments_expiry ON api.order_payments (_expiry_date);




-- ==========================================================================

-- DUMMY DATA

-- ==========================================================================



INSERT INTO api.pickup_addresses (pickup_address_name, pickup_address_complete, pickup_address_pincode, pickup_address_city, pickup_address_state, pickup_address_phone, pickup_address_is_active) VALUES
('Kolkata Warehouse', '14B, Rashbehari Avenue, 2nd Floor', '700029', 'Kolkata', 'West Bengal', '+919830011122', TRUE),
('Salt Lake Studio', 'CK-52, Sector II, Salt Lake', '700091', 'Kolkata', 'West Bengal', '+919830033344', TRUE);

INSERT INTO api.vendors (vendor_id, vendor_name, vendor_code, vendor_city, vendor_state, vendor_country, vendor_gstin, vendor_status) VALUES
('VND0001', 'Jaipur Kundan House', 'JKH', 'Jaipur', 'Rajasthan', 'India', '08AAPAB2447E1Z7', 'ACTIVE'),
('VND0002', 'Moradabad Brass Works', 'MBW', 'Moradabad', 'Uttar Pradesh', 'India', '09AAHBS9454H1Z6', 'ACTIVE'),
('VND0003', 'Kolkata Terracotta Craft', 'KTC', 'Kolkata', 'West Bengal', 'India', '19AAPCN8131G1ZE', 'ACTIVE'),
('VND0004', 'Hyderabad Pearl Point', 'HPP', 'Hyderabad', 'Telangana', 'India', '36AAPDP2787S1Z9', 'ACTIVE'),
('VND0005', 'Cuttack Silver Filigree', 'CSF', 'Cuttack', 'Odisha', 'India', '21AACEK9846A1ZC', 'ACTIVE'),
('VND0006', 'Delhi Oxidised Arts', 'DOA', 'New Delhi', 'Delhi', 'India', '07AAHFR7346T1ZB', 'ACTIVE'),
('VND0007', 'Mumbai Bead Studio', 'MBS', 'Mumbai', 'Maharashtra', 'India', '27AAFGZ8235X1ZC', 'ACTIVE'),
('VND0008', 'Bishnupur Dokra Collective', 'BDC', 'Bishnupur', 'West Bengal', 'India', '19AAPHU9306L1Z5', 'ACTIVE'),
('VND0009', 'Chennai Temple Jewels', 'CTJ', 'Chennai', 'Tamil Nadu', 'India', '33AAFIW8891J1Z1', 'ACTIVE'),
('VND0010', 'Surat Stone Traders', 'SST', 'Surat', 'Gujarat', 'India', '24AABJW9729K1ZH', 'INACTIVE');

INSERT INTO api.vendor_pii (vendor_id, vendor_address, vendor_pincode, vendor_contact_name, vendor_contact_phone, vendor_alternate_number, vendor_contact_email) VALUES
('VND0001', 'Shop 1, Artisan Colony, Jaipur', '302003', 'Ramesh Agarwal', '+918640013422', '+918925038019', 'ramesh@jkhcrafts.in'),
('VND0002', 'Shop 10, Craft Lane, Moradabad', '244001', 'Imran Qureshi', '+919861261942', NULL, 'imran@mbwcrafts.in'),
('VND0003', 'Shop 30, Craft Lane, Kolkata', '700012', 'Subrata Pal', '+916307890235', NULL, 'subrata@ktccrafts.in'),
('VND0004', 'Shop 30, Artisan Colony, Hyderabad', '500002', 'Farah Siddiqui', '+916601579031', '+919340784595', 'farah@hppcrafts.in'),
('VND0005', 'Shop 57, Old Market Road, Cuttack', '753001', 'Bikash Mohanty', '+916894475750', NULL, 'bikash@csfcrafts.in'),
('VND0006', 'Shop 14, Craft Lane, New Delhi', '110006', 'Neha Kapoor', '+917510547678', NULL, 'neha@doacrafts.in'),
('VND0007', 'Shop 53, Old Market Road, Mumbai', '400002', 'Rohit Shah', '+917939968562', '+918825194330', 'rohit@mbscrafts.in'),
('VND0008', 'Shop 16, Main Bazaar, Bishnupur', '722122', 'Gopal Karmakar', '+916155744257', NULL, 'gopal@bdccrafts.in'),
('VND0009', 'Shop 54, Station Road, Chennai', '600001', 'Lakshmi Narayanan', '+917746573267', NULL, 'lakshmi@ctjcrafts.in'),
('VND0010', 'Shop 90, Craft Lane, Surat', '395003', 'Hitesh Patel', '+918715250545', '+918419483231', 'hitesh@sstcrafts.in');

INSERT INTO api.customers (customer_id, customer_first_name, customer_last_name, customer_status, customer_type_code, customer_type, customer_joining_date) VALUES
('CUS00001', 'Ananya', 'Khan', 'ACTIVE', 'RC', 'Retail', '2026-01-18'),
('CUS00002', 'Priya', 'Mukherjee', 'ACTIVE', 'EC', 'Ecomm', '2025-08-01'),
('CUS00003', 'Riya', 'Mehta', 'ACTIVE', 'MC', 'Media', '2026-05-03'),
('CUS00004', 'Sneha', 'Sharma', 'ACTIVE', 'EC', 'Ecomm', '2026-01-15'),
('CUS00005', 'Ishita', 'Gupta', 'ACTIVE', 'MC', 'Media', '2025-10-10'),
('CUS00006', 'Debolina', 'Mehta', 'ACTIVE', 'RC', 'Retail', '2025-09-02'),
('CUS00007', 'Meera', 'Nair', 'ACTIVE', 'RC', 'Retail', '2025-07-01'),
('CUS00008', 'Kavya', 'Roy', 'ACTIVE', 'RC', 'Retail', '2025-10-22'),
('CUS00009', 'Shreya', 'Nair', 'ACTIVE', 'EC', 'Ecomm', '2025-09-10'),
('CUS00010', 'Tanvi', 'Gupta', 'ACTIVE', 'EC', 'Ecomm', '2025-10-12'),
('CUS00011', 'Aditi', 'Sharma', 'ACTIVE', 'EC', 'Ecomm', '2025-12-12'),
('CUS00012', 'Pooja', 'Mehta', 'ACTIVE', 'EC', 'Ecomm', '2026-01-02'),
('CUS00013', 'Rupsa', 'Sen', 'ACTIVE', 'MC', 'Media', '2025-12-31'),
('CUS00014', 'Nandini', 'Verma', 'ACTIVE', 'EC', 'Ecomm', '2026-05-18'),
('CUS00015', 'Srijita', 'Saha', 'ACTIVE', 'EC', 'Ecomm', '2026-04-16'),
('CUS00016', 'Arpita', 'Das', 'ACTIVE', 'EC', 'Ecomm', '2025-09-08'),
('CUS00017', 'Moumita', 'Sharma', 'ACTIVE', 'EC', 'Ecomm', '2026-05-26'),
('CUS00018', 'Payel', 'Roy', 'ACTIVE', 'MC', 'Media', '2025-10-17'),
('CUS00019', 'Divya', 'Mehta', 'ACTIVE', 'EC', 'Ecomm', '2026-02-08'),
('CUS00020', 'Sanjana', 'Verma', 'ACTIVE', 'EC', 'Ecomm', '2025-08-27'),
('CUS00021', 'Rahul', 'Saha', 'ACTIVE', 'EC', 'Ecomm', '2025-06-16'),
('CUS00022', 'Arjun', 'Roy', 'ACTIVE', 'EC', 'Ecomm', '2025-09-13'),
('CUS00023', 'Soumya', 'Dutta', 'ACTIVE', 'EC', 'Ecomm', '2025-07-03'),
('CUS00024', 'Vikram', 'Dutta', 'ACTIVE', 'EC', 'Ecomm', '2025-08-22'),
('CUS00025', 'Amit', 'Chatterjee', 'ACTIVE', 'RC', 'Retail', '2025-12-05'),
('CUS00026', 'Karan', NULL, 'ACTIVE', 'EC', 'Ecomm', '2025-09-14'),
('CUS00027', 'Farhan', 'Sharma', 'ACTIVE', 'EC', 'Ecomm', '2026-03-12'),
('CUS00028', 'Nikhil', 'Nair', 'BLOCKED', 'MC', 'Media', '2026-03-19'),
('CUS00029', 'Sayan', 'Reddy', 'INACTIVE', 'EC', 'Ecomm', '2025-12-25'),
('CUS00030', 'Rohan', 'Verma', 'ACTIVE', NULL, NULL, '2025-07-24');

INSERT INTO api.customer_pii (customer_id, customer_phone_number, customer_alt_phone_number, customer_email, customer_date_of_birth) VALUES
('CUS00001', '+917355230323', '+917937845647', 'ananya.khan93@yahoo.co.in', NULL),
('CUS00002', '+919905458710', NULL, 'priya.mukherjee17@outlook.com', '1989-08-14'),
('CUS00003', '+917070333965', NULL, 'riya.mehta60@outlook.com', '1978-11-18'),
('CUS00004', '+919881656316', NULL, 'sneha.sharma37@gmail.com', '1989-12-20'),
('CUS00005', '+916020498275', '+918495169324', 'ishita.gupta33@outlook.com', '1980-07-24'),
('CUS00006', '+919426229015', NULL, 'debolina.mehta37@yahoo.co.in', '1986-11-24'),
('CUS00007', '+918056456591', NULL, 'meera.nair4@yahoo.co.in', NULL),
('CUS00008', '+916421667259', NULL, 'kavya.roy62@yahoo.co.in', '1994-10-24'),
('CUS00009', '+916843383960', '+917985695901', 'shreya.nair5@gmail.com', '2004-01-24'),
('CUS00010', '+916223563526', NULL, 'tanvi.gupta20@gmail.com', '1996-08-04'),
('CUS00011', '+919599583079', NULL, 'aditi.sharma83@outlook.com', '1982-03-15'),
('CUS00012', '+916611560690', NULL, 'pooja.mehta10@outlook.com', '1992-08-20'),
('CUS00013', '+917361651445', '+916137368736', 'rupsa.sen38@yahoo.co.in', NULL),
('CUS00014', '+918068987723', NULL, 'nandini.verma53@gmail.com', '1992-05-02'),
('CUS00015', '+917928218389', NULL, 'srijita.saha48@yahoo.co.in', '1996-06-27'),
('CUS00016', '+917489894044', NULL, 'arpita.das98@outlook.com', '1983-08-09'),
('CUS00017', '+918562636444', '+919453226565', 'moumita.sharma76@yahoo.co.in', '1989-08-12'),
('CUS00018', '+919511880332', NULL, 'payel.roy7@yahoo.co.in', '1982-03-23'),
('CUS00019', '+916744597093', NULL, 'divya.mehta17@yahoo.co.in', NULL),
('CUS00020', '+919464501049', NULL, 'sanjana.verma21@gmail.com', '2003-06-14'),
('CUS00021', '+917082041809', '+918720579146', 'rahul.saha46@gmail.com', '1989-04-01'),
('CUS00022', '+917673759285', NULL, 'arjun.roy43@outlook.com', '2001-05-09'),
('CUS00023', '+916085130885', NULL, 'soumya.dutta82@yahoo.co.in', '1992-07-01'),
('CUS00024', '+917155932767', NULL, 'vikram.dutta76@yahoo.co.in', '1980-03-28'),
('CUS00025', '+917179164808', '+918161524954', 'amit.chatterjee45@yahoo.co.in', NULL),
('CUS00026', '+916321604952', NULL, 'karan.mehta16@yahoo.co.in', '1993-05-13'),
('CUS00027', '+918870702837', NULL, NULL, '1999-08-15'),
('CUS00028', '+916984743762', NULL, 'nikhil.nair32@outlook.com', '1986-10-18'),
('CUS00029', '+917160584733', '+917157931108', 'sayan.reddy95@gmail.com', '1984-12-25'),
('CUS00030', '+918321830188', NULL, 'rohan.verma24@yahoo.co.in', '1976-12-16');

INSERT INTO api.batches (batch_id, vendor_id, batch_order_date, batch_received_date, batch_status) VALUES
('BAT-2026-001', 'VND0001', '2026-04-04', '2026-04-16', 'CONFIRMED'),
('BAT-2026-002', 'VND0002', '2026-04-17', '2026-04-28', 'CONFIRMED'),
('BAT-2026-003', 'VND0003', '2026-04-24', '2026-05-03', 'CONFIRMED'),
('BAT-2026-004', 'VND0004', '2026-05-09', '2026-05-17', 'CONFIRMED'),
('BAT-2026-005', 'VND0005', '2026-05-20', '2026-05-31', 'CONFIRMED'),
('BAT-2026-006', 'VND0006', '2026-05-26', '2026-06-02', 'CONFIRMED'),
('BAT-2026-007', 'VND0007', '2026-06-08', '2026-06-18', 'CONFIRMED'),
('BAT-2026-008', 'VND0008', '2026-06-20', '2026-06-28', 'CONFIRMED'),
('BAT-2026-009', 'VND0001', '2026-10-28', NULL, 'SHIPPED');

INSERT INTO api.products (product_name, product_code, product_sku, product_master_qr_code, product_type, product_type_code, product_attribute_json, product_sell_price, product_price_category_code, product_discount_code, product_discount_amount, product_status, product_description, product_hsn_code, product_tax_rate, vendor_id, vendor_code) VALUES
('Kundan Collar Necklace - Pink', 'NCK0001', 'JKH-NCK-0001', 'https://abeg.in/p/JKH-NCK-0001', 'Necklace', 'NCK', '{"material": "Gold-plated brass", "colour": "Pink", "weight_g": 29, "occasion": "Daily wear", "stone": "Kundan stones", "length_cm": 35}', 2249.00, 'P4', 'FLAT10', 225.00, 'PUBLISHED', 'Handcrafted kundan necklace in pink, made by artisans in Jaipur.', '7117', 3.00, 'VND0001', 'JKH'),
('Hammered Brass Maang Tikka - Red', 'MTK0001', 'MBW-MTK-0001', 'https://abeg.in/p/MBW-MTK-0001', 'Maang Tikka', 'MTK', '{"material": "Brass", "colour": "Red", "weight_g": 68, "occasion": "Daily wear"}', 549.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted hammered brass maang tikka in red, made by artisans in Moradabad.', '7117', 3.00, 'VND0002', 'MBW'),
('Terracotta Payal Anklet - Multicolour', 'ANK0001', 'KTC-ANK-0001', 'https://abeg.in/p/KTC-ANK-0001', 'Anklet', 'ANK', '{"material": "Terracotta clay", "colour": "Multicolour", "weight_g": 66, "occasion": "Bridal"}', 699.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted terracotta anklet in multicolour, made by artisans in Kolkata.', '6913', 12.00, 'VND0003', 'KTC'),
('Pearl Adjustable Ring - White', 'RNG0001', 'HPP-RNG-0001', 'https://abeg.in/p/HPP-RNG-0001', 'Ring', 'RNG', '{"material": "Gold-plated alloy", "colour": "White", "weight_g": 57, "occasion": "Daily wear", "stone": "Freshwater pearls", "adjustable": true}', 499.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted pearl ring in white, made by artisans in Hyderabad.', '7117', 3.00, 'VND0004', 'HPP'),
('Silver Filigree Kada - Pink', 'BNG0001', 'CSF-BNG-0001', 'https://abeg.in/p/CSF-BNG-0001', 'Bangles', 'BNG', '{"material": "Sterling silver", "colour": "Pink", "weight_g": 83, "occasion": "Daily wear", "size": "2.8"}', 1149.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted silver filigree bangles in pink, made by artisans in Cuttack.', '7113', 3.00, 'VND0005', 'CSF'),
('Oxidised Drop Earrings - Silver', 'EAR0001', 'DOA-EAR-0001', 'https://abeg.in/p/DOA-EAR-0001', 'Earrings', 'EAR', '{"material": "Oxidised German silver", "colour": "Silver", "weight_g": 81, "occasion": "Bridal", "stone": "Mirror work"}', 1099.00, 'P3', 'FLAT10', 110.00, 'PUBLISHED', 'Handcrafted oxidised earrings in silver, made by artisans in New Delhi.', '7117', 3.00, 'VND0006', 'DOA'),
('Beaded Pendant Necklace - White', 'NCK0002', 'MBS-NCK-0002', 'https://abeg.in/p/MBS-NCK-0002', 'Necklace', 'NCK', '{"material": "Glass beads", "colour": "White", "weight_g": 93, "occasion": "Bridal", "stone": "Seed beads", "length_cm": 45}', 1349.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted beaded necklace in white, made by artisans in Mumbai.', '7117', 3.00, 'VND0007', 'MBS'),
('Dokra Maang Tikka - White', 'MTK0002', 'BDC-MTK-0002', 'https://abeg.in/p/BDC-MTK-0002', 'Maang Tikka', 'MTK', '{"material": "Bell metal", "colour": "White", "weight_g": 58, "occasion": "Bridal"}', 349.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted dokra maang tikka in white, made by artisans in Bishnupur.', '7117', 3.00, 'VND0008', 'BDC'),
('Kundan Borla Tikka - Multicolour', 'MTK0003', 'JKH-MTK-0003', 'https://abeg.in/p/JKH-MTK-0003', 'Maang Tikka', 'MTK', '{"material": "Gold-plated brass", "colour": "Multicolour", "weight_g": 20, "occasion": "Bridal", "stone": "Kundan stones"}', 699.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted kundan maang tikka in multicolour, made by artisans in Jaipur.', '7117', 3.00, 'VND0001', 'JKH'),
('Hammered Brass Payal Anklet - Black', 'ANK0002', 'MBW-ANK-0002', 'https://abeg.in/p/MBW-ANK-0002', 'Anklet', 'ANK', '{"material": "Brass", "colour": "Black", "weight_g": 28, "occasion": "Festive"}', 749.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted hammered brass anklet in black, made by artisans in Moradabad.', '7117', 3.00, 'VND0002', 'MBW'),
('Terracotta Adjustable Ring - White', 'RNG0002', 'KTC-RNG-0002', 'https://abeg.in/p/KTC-RNG-0002', 'Ring', 'RNG', '{"material": "Terracotta clay", "colour": "White", "weight_g": 94, "occasion": "Bridal", "adjustable": true}', 399.00, 'P1', 'FLAT10', 40.00, 'PUBLISHED', 'Handcrafted terracotta ring in white, made by artisans in Kolkata.', '6913', 12.00, 'VND0003', 'KTC'),
('Pearl Cuff Bangle - White', 'BNG0002', 'HPP-BNG-0002', 'https://abeg.in/p/HPP-BNG-0002', 'Bangles', 'BNG', '{"material": "Gold-plated alloy", "colour": "White", "weight_g": 26, "occasion": "Party", "stone": "Freshwater pearls", "size": "2.8"}', 599.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted pearl bangles in white, made by artisans in Hyderabad.', '7117', 3.00, 'VND0004', 'HPP'),
('Silver Filigree Drop Earrings - Silver', 'EAR0002', 'CSF-EAR-0002', 'https://abeg.in/p/CSF-EAR-0002', 'Earrings', 'EAR', '{"material": "Sterling silver", "colour": "Silver", "weight_g": 60, "occasion": "Daily wear"}', 399.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted silver filigree earrings in silver, made by artisans in Cuttack.', '7113', 3.00, 'VND0005', 'CSF'),
('Oxidised Pendant Necklace - Gold', 'NCK0003', 'DOA-NCK-0003', 'https://abeg.in/p/DOA-NCK-0003', 'Necklace', 'NCK', '{"material": "Oxidised German silver", "colour": "Gold", "weight_g": 18, "occasion": "Daily wear", "stone": "Mirror work", "length_cm": 40}', 2499.00, 'P4', NULL, 0.00, 'PUBLISHED', 'Handcrafted oxidised necklace in gold, made by artisans in New Delhi.', '7117', 3.00, 'VND0006', 'DOA'),
('Beaded Borla Tikka - Green', 'MTK0004', 'MBS-MTK-0004', 'https://abeg.in/p/MBS-MTK-0004', 'Maang Tikka', 'MTK', '{"material": "Glass beads", "colour": "Green", "weight_g": 92, "occasion": "Bridal", "stone": "Seed beads"}', 399.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted beaded maang tikka in green, made by artisans in Mumbai.', '7117', 3.00, 'VND0007', 'MBS'),
('Dokra Ghungroo Anklet - Silver', 'ANK0003', 'BDC-ANK-0003', 'https://abeg.in/p/BDC-ANK-0003', 'Anklet', 'ANK', '{"material": "Bell metal", "colour": "Silver", "weight_g": 60, "occasion": "Festive"}', 799.00, 'P2', 'FLAT10', 80.00, 'PUBLISHED', 'Handcrafted dokra anklet in silver, made by artisans in Bishnupur.', '7117', 3.00, 'VND0008', 'BDC'),
('Kundan Payal Anklet - White', 'ANK0004', 'JKH-ANK-0004', 'https://abeg.in/p/JKH-ANK-0004', 'Anklet', 'ANK', '{"material": "Gold-plated brass", "colour": "White", "weight_g": 71, "occasion": "Party", "stone": "Kundan stones"}', 399.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted kundan anklet in white, made by artisans in Jaipur.', '7117', 3.00, 'VND0001', 'JKH'),
('Hammered Brass Adjustable Ring - Silver', 'RNG0003', 'MBW-RNG-0003', 'https://abeg.in/p/MBW-RNG-0003', 'Ring', 'RNG', '{"material": "Brass", "colour": "Silver", "weight_g": 94, "occasion": "Bridal", "adjustable": true}', 749.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted hammered brass ring in silver, made by artisans in Moradabad.', '7117', 3.00, 'VND0002', 'MBW'),
('Terracotta Bangle Set - Silver', 'BNG0003', 'KTC-BNG-0003', 'https://abeg.in/p/KTC-BNG-0003', 'Bangles', 'BNG', '{"material": "Terracotta clay", "colour": "Silver", "weight_g": 78, "occasion": "Bridal", "size": "2.6"}', 999.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted terracotta bangles in silver, made by artisans in Kolkata.', '6913', 12.00, 'VND0003', 'KTC'),
('Pearl Chandbali Earrings - Gold', 'EAR0003', 'HPP-EAR-0003', 'https://abeg.in/p/HPP-EAR-0003', 'Earrings', 'EAR', '{"material": "Gold-plated alloy", "colour": "Gold", "weight_g": 51, "occasion": "Bridal", "stone": "Freshwater pearls"}', 1249.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted pearl earrings in gold, made by artisans in Hyderabad.', '7117', 3.00, 'VND0004', 'HPP'),
('Silver Filigree Pendant Necklace - Pink', 'NCK0004', 'CSF-NCK-0004', 'https://abeg.in/p/CSF-NCK-0004', 'Necklace', 'NCK', '{"material": "Sterling silver", "colour": "Pink", "weight_g": 43, "occasion": "Party", "length_cm": 60}', 1049.00, 'P3', 'FLAT10', 105.00, 'PUBLISHED', 'Handcrafted silver filigree necklace in pink, made by artisans in Cuttack.', '7113', 3.00, 'VND0005', 'CSF'),
('Oxidised Maang Tikka - Pink', 'MTK0005', 'DOA-MTK-0005', 'https://abeg.in/p/DOA-MTK-0005', 'Maang Tikka', 'MTK', '{"material": "Oxidised German silver", "colour": "Pink", "weight_g": 66, "occasion": "Bridal", "stone": "Mirror work"}', 799.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted oxidised maang tikka in pink, made by artisans in New Delhi.', '7117', 3.00, 'VND0006', 'DOA'),
('Beaded Payal Anklet - Maroon', 'ANK0005', 'MBS-ANK-0005', 'https://abeg.in/p/MBS-ANK-0005', 'Anklet', 'ANK', '{"material": "Glass beads", "colour": "Maroon", "weight_g": 74, "occasion": "Bridal", "stone": "Seed beads"}', 849.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted beaded anklet in maroon, made by artisans in Mumbai.', '7117', 3.00, 'VND0007', 'MBS'),
('Dokra Adjustable Ring - Red', 'RNG0004', 'BDC-RNG-0004', 'https://abeg.in/p/BDC-RNG-0004', 'Ring', 'RNG', '{"material": "Bell metal", "colour": "Red", "weight_g": 47, "occasion": "Party", "adjustable": true}', 399.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted dokra ring in red, made by artisans in Bishnupur.', '7117', 3.00, 'VND0008', 'BDC'),
('Kundan Adjustable Ring - White', 'RNG0005', 'JKH-RNG-0005', 'https://abeg.in/p/JKH-RNG-0005', 'Ring', 'RNG', '{"material": "Gold-plated brass", "colour": "White", "weight_g": 28, "occasion": "Festive", "stone": "Kundan stones", "adjustable": true}', 249.00, 'P1', NULL, 0.00, 'PUBLISHED', 'Handcrafted kundan ring in white, made by artisans in Jaipur.', '7117', 3.00, 'VND0001', 'JKH'),
('Hammered Brass Bangle Set - Gold', 'BNG0004', 'MBW-BNG-0004', 'https://abeg.in/p/MBW-BNG-0004', 'Bangles', 'BNG', '{"material": "Brass", "colour": "Gold", "weight_g": 53, "occasion": "Party", "size": "2.8"}', 1099.00, 'P3', 'FLAT10', 110.00, 'PUBLISHED', 'Handcrafted hammered brass bangles in gold, made by artisans in Moradabad.', '7117', 3.00, 'VND0002', 'MBW'),
('Terracotta Jhumka Earrings - Pink', 'EAR0004', 'KTC-EAR-0004', 'https://abeg.in/p/KTC-EAR-0004', 'Earrings', 'EAR', '{"material": "Terracotta clay", "colour": "Pink", "weight_g": 92, "occasion": "Party"}', 1299.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted terracotta earrings in pink, made by artisans in Kolkata.', '6913', 12.00, 'VND0003', 'KTC'),
('Pearl Collar Necklace - White', 'NCK0005', 'HPP-NCK-0005', 'https://abeg.in/p/HPP-NCK-0005', 'Necklace', 'NCK', '{"material": "Gold-plated alloy", "colour": "White", "weight_g": 20, "occasion": "Festive", "stone": "Freshwater pearls", "length_cm": 60}', 1699.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted pearl necklace in white, made by artisans in Hyderabad.', '7117', 3.00, 'VND0004', 'HPP'),
('Silver Filigree Maang Tikka - Black', 'MTK0006', 'CSF-MTK-0006', 'https://abeg.in/p/CSF-MTK-0006', 'Maang Tikka', 'MTK', '{"material": "Sterling silver", "colour": "Black", "weight_g": 58, "occasion": "Bridal"}', 949.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted silver filigree maang tikka in black, made by artisans in Cuttack.', '7113', 3.00, 'VND0005', 'CSF'),
('Oxidised Ghungroo Anklet - Blue', 'ANK0006', 'DOA-ANK-0006', 'https://abeg.in/p/DOA-ANK-0006', 'Anklet', 'ANK', '{"material": "Oxidised German silver", "colour": "Blue", "weight_g": 61, "occasion": "Bridal", "stone": "Mirror work"}', 799.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted oxidised anklet in blue, made by artisans in New Delhi.', '7117', 3.00, 'VND0006', 'DOA'),
('Beaded Adjustable Ring - Blue', 'RNG0006', 'MBS-RNG-0006', 'https://abeg.in/p/MBS-RNG-0006', 'Ring', 'RNG', '{"material": "Glass beads", "colour": "Blue", "weight_g": 64, "occasion": "Daily wear", "stone": "Seed beads", "adjustable": true}', 699.00, 'P2', 'FLAT10', 70.00, 'PUBLISHED', 'Handcrafted beaded ring in blue, made by artisans in Mumbai.', '7117', 3.00, 'VND0007', 'MBS'),
('Dokra Cuff Bangle - White', 'BNG0005', 'BDC-BNG-0005', 'https://abeg.in/p/BDC-BNG-0005', 'Bangles', 'BNG', '{"material": "Bell metal", "colour": "White", "weight_g": 38, "occasion": "Party", "size": "2.8"}', 549.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted dokra bangles in white, made by artisans in Bishnupur.', '7117', 3.00, 'VND0008', 'BDC'),
('Kundan Cuff Bangle - Gold', 'BNG0006', 'JKH-BNG-0006', 'https://abeg.in/p/JKH-BNG-0006', 'Bangles', 'BNG', '{"material": "Gold-plated brass", "colour": "Gold", "weight_g": 42, "occasion": "Festive", "stone": "Kundan stones", "size": "2.6"}', 549.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted kundan bangles in gold, made by artisans in Jaipur.', '7117', 3.00, 'VND0001', 'JKH'),
('Hammered Brass Jhumka Earrings - Blue', 'EAR0005', 'MBW-EAR-0005', 'https://abeg.in/p/MBW-EAR-0005', 'Earrings', 'EAR', '{"material": "Brass", "colour": "Blue", "weight_g": 16, "occasion": "Festive"}', 549.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted hammered brass earrings in blue, made by artisans in Moradabad.', '7117', 3.00, 'VND0002', 'MBW'),
('Terracotta Pendant Necklace - Multicolour', 'NCK0006', 'KTC-NCK-0006', 'https://abeg.in/p/KTC-NCK-0006', 'Necklace', 'NCK', '{"material": "Terracotta clay", "colour": "Multicolour", "weight_g": 11, "occasion": "Daily wear", "length_cm": 35}', 1999.00, 'P3', NULL, 0.00, 'PUBLISHED', 'Handcrafted terracotta necklace in multicolour, made by artisans in Kolkata.', '6913', 12.00, 'VND0003', 'KTC'),
('Pearl Borla Tikka - Maroon', 'MTK0007', 'HPP-MTK-0007', 'https://abeg.in/p/HPP-MTK-0007', 'Maang Tikka', 'MTK', '{"material": "Gold-plated alloy", "colour": "Maroon", "weight_g": 42, "occasion": "Party", "stone": "Freshwater pearls"}', 849.00, 'P2', 'FLAT10', 85.00, 'PUBLISHED', 'Handcrafted pearl maang tikka in maroon, made by artisans in Hyderabad.', '7117', 3.00, 'VND0004', 'HPP'),
('Silver Filigree Ghungroo Anklet - White', 'ANK0007', 'CSF-ANK-0007', 'https://abeg.in/p/CSF-ANK-0007', 'Anklet', 'ANK', '{"material": "Sterling silver", "colour": "White", "weight_g": 49, "occasion": "Bridal"}', 599.00, 'P2', NULL, 0.00, 'PUBLISHED', 'Handcrafted silver filigree anklet in white, made by artisans in Cuttack.', '7113', 3.00, 'VND0005', 'CSF'),
('Oxidised Cocktail Ring - Multicolour', 'RNG0007', 'DOA-RNG-0007', 'https://abeg.in/p/DOA-RNG-0007', 'Ring', 'RNG', '{"material": "Oxidised German silver", "colour": "Multicolour", "weight_g": 18, "occasion": "Party", "stone": "Mirror work", "adjustable": true}', 449.00, 'P1', NULL, 0.00, 'DRAFT', 'Handcrafted oxidised ring in multicolour, made by artisans in New Delhi.', '7117', 3.00, 'VND0006', 'DOA'),
('Beaded Kada - Multicolour', 'BNG0007', 'MBS-BNG-0007', 'https://abeg.in/p/MBS-BNG-0007', 'Bangles', 'BNG', '{"material": "Glass beads", "colour": "Multicolour", "weight_g": 40, "occasion": "Daily wear", "stone": "Seed beads", "size": "2.6"}', 899.00, 'P2', NULL, 0.00, 'DRAFT', 'Handcrafted beaded bangles in multicolour, made by artisans in Mumbai.', '7117', 3.00, 'VND0007', 'MBS'),
('Dokra Jhumka Earrings - Pink', 'EAR0006', 'BDC-EAR-0006', 'https://abeg.in/p/BDC-EAR-0006', 'Earrings', 'EAR', '{"material": "Bell metal", "colour": "Pink", "weight_g": 56, "occasion": "Daily wear"}', 999.00, 'P2', NULL, 0.00, 'OFFLINE', 'Handcrafted dokra earrings in pink, made by artisans in Bishnupur.', '7117', 3.00, 'VND0008', 'BDC');

INSERT INTO api.product_media (product_sku, product_media_path, product_media_filename, product_media_type, product_media_sort_order, product_media_is_primary, product_media_alt_text) VALUES
('JKH-NCK-0001', '/assets/img/', 'jkh-nck-0001-1.webp', 'WEBP', 0, TRUE, 'Kundan Collar Necklace in pink, view 1'),
('JKH-NCK-0001', '/assets/img/', 'jkh-nck-0001-2.webp', 'WEBP', 1, FALSE, 'Kundan Collar Necklace in pink, view 2'),
('JKH-NCK-0001', '/assets/img/', 'jkh-nck-0001-3.mp4', 'MP4', 2, FALSE, 'Kundan Collar Necklace in pink, view 3'),
('MBW-MTK-0001', '/assets/img/', 'mbw-mtk-0001-1.webp', 'WEBP', 0, TRUE, 'Hammered Brass Maang Tikka in red, view 1'),
('MBW-MTK-0001', '/assets/img/', 'mbw-mtk-0001-2.jpg', 'JPG', 1, FALSE, 'Hammered Brass Maang Tikka in red, view 2'),
('MBW-MTK-0001', '/assets/img/', 'mbw-mtk-0001-3.jpg', 'JPG', 2, FALSE, 'Hammered Brass Maang Tikka in red, view 3'),
('KTC-ANK-0001', '/assets/img/', 'ktc-ank-0001-1.webp', 'WEBP', 0, TRUE, 'Terracotta Payal Anklet in multicolour, view 1'),
('KTC-ANK-0001', '/assets/img/', 'ktc-ank-0001-2.webp', 'WEBP', 1, FALSE, 'Terracotta Payal Anklet in multicolour, view 2'),
('HPP-RNG-0001', '/assets/img/', 'hpp-rng-0001-1.webp', 'WEBP', 0, TRUE, 'Pearl Adjustable Ring in white, view 1'),
('HPP-RNG-0001', '/assets/img/', 'hpp-rng-0001-2.jpg', 'JPG', 1, FALSE, 'Pearl Adjustable Ring in white, view 2'),
('CSF-BNG-0001', '/assets/img/', 'csf-bng-0001-1.webp', 'WEBP', 0, TRUE, 'Silver Filigree Kada in pink, view 1'),
('DOA-EAR-0001', '/assets/img/', 'doa-ear-0001-1.webp', 'WEBP', 0, TRUE, 'Oxidised Drop Earrings in silver, view 1'),
('DOA-EAR-0001', '/assets/img/', 'doa-ear-0001-2.webp', 'WEBP', 1, FALSE, 'Oxidised Drop Earrings in silver, view 2'),
('MBS-NCK-0002', '/assets/img/', 'mbs-nck-0002-1.webp', 'WEBP', 0, TRUE, 'Beaded Pendant Necklace in white, view 1'),
('BDC-MTK-0002', '/assets/img/', 'bdc-mtk-0002-1.webp', 'WEBP', 0, TRUE, 'Dokra Maang Tikka in white, view 1'),
('BDC-MTK-0002', '/assets/img/', 'bdc-mtk-0002-2.jpg', 'JPG', 1, FALSE, 'Dokra Maang Tikka in white, view 2'),
('BDC-MTK-0002', '/assets/img/', 'bdc-mtk-0002-3.jpg', 'JPG', 2, FALSE, 'Dokra Maang Tikka in white, view 3'),
('JKH-MTK-0003', '/assets/img/', 'jkh-mtk-0003-1.webp', 'WEBP', 0, TRUE, 'Kundan Borla Tikka in multicolour, view 1'),
('JKH-MTK-0003', '/assets/img/', 'jkh-mtk-0003-2.jpg', 'JPG', 1, FALSE, 'Kundan Borla Tikka in multicolour, view 2'),
('MBW-ANK-0002', '/assets/img/', 'mbw-ank-0002-1.webp', 'WEBP', 0, TRUE, 'Hammered Brass Payal Anklet in black, view 1'),
('MBW-ANK-0002', '/assets/img/', 'mbw-ank-0002-2.webp', 'WEBP', 1, FALSE, 'Hammered Brass Payal Anklet in black, view 2'),
('KTC-RNG-0002', '/assets/img/', 'ktc-rng-0002-1.webp', 'WEBP', 0, TRUE, 'Terracotta Adjustable Ring in white, view 1'),
('KTC-RNG-0002', '/assets/img/', 'ktc-rng-0002-2.webp', 'WEBP', 1, FALSE, 'Terracotta Adjustable Ring in white, view 2'),
('KTC-RNG-0002', '/assets/img/', 'ktc-rng-0002-3.jpg', 'JPG', 2, FALSE, 'Terracotta Adjustable Ring in white, view 3'),
('HPP-BNG-0002', '/assets/img/', 'hpp-bng-0002-1.webp', 'WEBP', 0, TRUE, 'Pearl Cuff Bangle in white, view 1'),
('CSF-EAR-0002', '/assets/img/', 'csf-ear-0002-1.webp', 'WEBP', 0, TRUE, 'Silver Filigree Drop Earrings in silver, view 1'),
('CSF-EAR-0002', '/assets/img/', 'csf-ear-0002-2.webp', 'WEBP', 1, FALSE, 'Silver Filigree Drop Earrings in silver, view 2'),
('CSF-EAR-0002', '/assets/img/', 'csf-ear-0002-3.mp4', 'MP4', 2, FALSE, 'Silver Filigree Drop Earrings in silver, view 3'),
('DOA-NCK-0003', '/assets/img/', 'doa-nck-0003-1.webp', 'WEBP', 0, TRUE, 'Oxidised Pendant Necklace in gold, view 1'),
('MBS-MTK-0004', '/assets/img/', 'mbs-mtk-0004-1.webp', 'WEBP', 0, TRUE, 'Beaded Borla Tikka in green, view 1'),
('MBS-MTK-0004', '/assets/img/', 'mbs-mtk-0004-2.webp', 'WEBP', 1, FALSE, 'Beaded Borla Tikka in green, view 2'),
('MBS-MTK-0004', '/assets/img/', 'mbs-mtk-0004-3.webp', 'WEBP', 2, FALSE, 'Beaded Borla Tikka in green, view 3'),
('BDC-ANK-0003', '/assets/img/', 'bdc-ank-0003-1.webp', 'WEBP', 0, TRUE, 'Dokra Ghungroo Anklet in silver, view 1'),
('BDC-ANK-0003', '/assets/img/', 'bdc-ank-0003-2.webp', 'WEBP', 1, FALSE, 'Dokra Ghungroo Anklet in silver, view 2'),
('BDC-ANK-0003', '/assets/img/', 'bdc-ank-0003-3.webp', 'WEBP', 2, FALSE, 'Dokra Ghungroo Anklet in silver, view 3'),
('JKH-ANK-0004', '/assets/img/', 'jkh-ank-0004-1.webp', 'WEBP', 0, TRUE, 'Kundan Payal Anklet in white, view 1'),
('MBW-RNG-0003', '/assets/img/', 'mbw-rng-0003-1.webp', 'WEBP', 0, TRUE, 'Hammered Brass Adjustable Ring in silver, view 1'),
('KTC-BNG-0003', '/assets/img/', 'ktc-bng-0003-1.webp', 'WEBP', 0, TRUE, 'Terracotta Bangle Set in silver, view 1'),
('HPP-EAR-0003', '/assets/img/', 'hpp-ear-0003-1.webp', 'WEBP', 0, TRUE, 'Pearl Chandbali Earrings in gold, view 1'),
('HPP-EAR-0003', '/assets/img/', 'hpp-ear-0003-2.jpg', 'JPG', 1, FALSE, 'Pearl Chandbali Earrings in gold, view 2'),
('HPP-EAR-0003', '/assets/img/', 'hpp-ear-0003-3.webp', 'WEBP', 2, FALSE, 'Pearl Chandbali Earrings in gold, view 3'),
('CSF-NCK-0004', '/assets/img/', 'csf-nck-0004-1.webp', 'WEBP', 0, TRUE, 'Silver Filigree Pendant Necklace in pink, view 1'),
('CSF-NCK-0004', '/assets/img/', 'csf-nck-0004-2.webp', 'WEBP', 1, FALSE, 'Silver Filigree Pendant Necklace in pink, view 2'),
('CSF-NCK-0004', '/assets/img/', 'csf-nck-0004-3.mp4', 'MP4', 2, FALSE, 'Silver Filigree Pendant Necklace in pink, view 3'),
('DOA-MTK-0005', '/assets/img/', 'doa-mtk-0005-1.webp', 'WEBP', 0, TRUE, 'Oxidised Maang Tikka in pink, view 1'),
('MBS-ANK-0005', '/assets/img/', 'mbs-ank-0005-1.webp', 'WEBP', 0, TRUE, 'Beaded Payal Anklet in maroon, view 1'),
('MBS-ANK-0005', '/assets/img/', 'mbs-ank-0005-2.jpg', 'JPG', 1, FALSE, 'Beaded Payal Anklet in maroon, view 2'),
('BDC-RNG-0004', '/assets/img/', 'bdc-rng-0004-1.webp', 'WEBP', 0, TRUE, 'Dokra Adjustable Ring in red, view 1'),
('BDC-RNG-0004', '/assets/img/', 'bdc-rng-0004-2.webp', 'WEBP', 1, FALSE, 'Dokra Adjustable Ring in red, view 2'),
('BDC-RNG-0004', '/assets/img/', 'bdc-rng-0004-3.jpg', 'JPG', 2, FALSE, 'Dokra Adjustable Ring in red, view 3'),
('JKH-RNG-0005', '/assets/img/', 'jkh-rng-0005-1.webp', 'WEBP', 0, TRUE, 'Kundan Adjustable Ring in white, view 1'),
('JKH-RNG-0005', '/assets/img/', 'jkh-rng-0005-2.webp', 'WEBP', 1, FALSE, 'Kundan Adjustable Ring in white, view 2'),
('JKH-RNG-0005', '/assets/img/', 'jkh-rng-0005-3.mp4', 'MP4', 2, FALSE, 'Kundan Adjustable Ring in white, view 3'),
('MBW-BNG-0004', '/assets/img/', 'mbw-bng-0004-1.webp', 'WEBP', 0, TRUE, 'Hammered Brass Bangle Set in gold, view 1'),
('MBW-BNG-0004', '/assets/img/', 'mbw-bng-0004-2.jpg', 'JPG', 1, FALSE, 'Hammered Brass Bangle Set in gold, view 2'),
('MBW-BNG-0004', '/assets/img/', 'mbw-bng-0004-3.jpg', 'JPG', 2, FALSE, 'Hammered Brass Bangle Set in gold, view 3'),
('KTC-EAR-0004', '/assets/img/', 'ktc-ear-0004-1.webp', 'WEBP', 0, TRUE, 'Terracotta Jhumka Earrings in pink, view 1'),
('HPP-NCK-0005', '/assets/img/', 'hpp-nck-0005-1.webp', 'WEBP', 0, TRUE, 'Pearl Collar Necklace in white, view 1'),
('HPP-NCK-0005', '/assets/img/', 'hpp-nck-0005-2.webp', 'WEBP', 1, FALSE, 'Pearl Collar Necklace in white, view 2'),
('HPP-NCK-0005', '/assets/img/', 'hpp-nck-0005-3.jpg', 'JPG', 2, FALSE, 'Pearl Collar Necklace in white, view 3'),
('CSF-MTK-0006', '/assets/img/', 'csf-mtk-0006-1.webp', 'WEBP', 0, TRUE, 'Silver Filigree Maang Tikka in black, view 1'),
('DOA-ANK-0006', '/assets/img/', 'doa-ank-0006-1.webp', 'WEBP', 0, TRUE, 'Oxidised Ghungroo Anklet in blue, view 1'),
('MBS-RNG-0006', '/assets/img/', 'mbs-rng-0006-1.webp', 'WEBP', 0, TRUE, 'Beaded Adjustable Ring in blue, view 1'),
('BDC-BNG-0005', '/assets/img/', 'bdc-bng-0005-1.webp', 'WEBP', 0, TRUE, 'Dokra Cuff Bangle in white, view 1'),
('BDC-BNG-0005', '/assets/img/', 'bdc-bng-0005-2.jpg', 'JPG', 1, FALSE, 'Dokra Cuff Bangle in white, view 2'),
('BDC-BNG-0005', '/assets/img/', 'bdc-bng-0005-3.webp', 'WEBP', 2, FALSE, 'Dokra Cuff Bangle in white, view 3'),
('JKH-BNG-0006', '/assets/img/', 'jkh-bng-0006-1.webp', 'WEBP', 0, TRUE, 'Kundan Cuff Bangle in gold, view 1'),
('JKH-BNG-0006', '/assets/img/', 'jkh-bng-0006-2.jpg', 'JPG', 1, FALSE, 'Kundan Cuff Bangle in gold, view 2'),
('JKH-BNG-0006', '/assets/img/', 'jkh-bng-0006-3.mp4', 'MP4', 2, FALSE, 'Kundan Cuff Bangle in gold, view 3'),
('MBW-EAR-0005', '/assets/img/', 'mbw-ear-0005-1.webp', 'WEBP', 0, TRUE, 'Hammered Brass Jhumka Earrings in blue, view 1'),
('KTC-NCK-0006', '/assets/img/', 'ktc-nck-0006-1.webp', 'WEBP', 0, TRUE, 'Terracotta Pendant Necklace in multicolour, view 1'),
('HPP-MTK-0007', '/assets/img/', 'hpp-mtk-0007-1.webp', 'WEBP', 0, TRUE, 'Pearl Borla Tikka in maroon, view 1'),
('HPP-MTK-0007', '/assets/img/', 'hpp-mtk-0007-2.webp', 'WEBP', 1, FALSE, 'Pearl Borla Tikka in maroon, view 2'),
('CSF-ANK-0007', '/assets/img/', 'csf-ank-0007-1.webp', 'WEBP', 0, TRUE, 'Silver Filigree Ghungroo Anklet in white, view 1'),
('CSF-ANK-0007', '/assets/img/', 'csf-ank-0007-2.webp', 'WEBP', 1, FALSE, 'Silver Filigree Ghungroo Anklet in white, view 2'),
('DOA-RNG-0007', '/assets/img/', 'doa-rng-0007-1.webp', 'WEBP', 0, TRUE, 'Oxidised Cocktail Ring in multicolour, view 1'),
('MBS-BNG-0007', '/assets/img/', 'mbs-bng-0007-1.webp', 'WEBP', 0, TRUE, 'Beaded Kada in multicolour, view 1'),
('BDC-EAR-0006', '/assets/img/', 'bdc-ear-0006-1.webp', 'WEBP', 0, TRUE, 'Dokra Jhumka Earrings in pink, view 1'),
('BDC-EAR-0006', '/assets/img/', 'bdc-ear-0006-2.webp', 'WEBP', 1, FALSE, 'Dokra Jhumka Earrings in pink, view 2'),
('BDC-EAR-0006', '/assets/img/', 'bdc-ear-0006-3.jpg', 'JPG', 2, FALSE, 'Dokra Jhumka Earrings in pink, view 3');

INSERT INTO api.product_item (product_id, product_sl_number, product_sku, product_master_sku, product_buy_price, product_item_status, product_item_status_reason, comment, batch_id) VALUES
('JKHNCK0001001', '001', 'JKH-NCK-0001', 'JKH-NCK-0001-001', 972.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHNCK0001002', '002', 'JKH-NCK-0001', 'JKH-NCK-0001-002', 938.00, 'SOLD', 'Sold on order ORD-260705-0002', NULL, 'BAT-2026-001'),
('MBWMTK0001001', '001', 'MBW-MTK-0001', 'MBW-MTK-0001-001', 236.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('MBWMTK0001002', '002', 'MBW-MTK-0001', 'MBW-MTK-0001-002', 242.00, 'SOLD', 'Sold on order ORD-260820-0016', NULL, 'BAT-2026-002'),
('MBWMTK0001003', '003', 'MBW-MTK-0001', 'MBW-MTK-0001-003', 247.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('MBWMTK0001004', '004', 'MBW-MTK-0001', 'MBW-MTK-0001-004', 247.00, 'REJECTED', 'Failed QC on receipt', 'Two stones missing from the setting', 'BAT-2026-002'),
('KTCANK0001001', '001', 'KTC-ANK-0001', 'KTC-ANK-0001-001', 337.00, 'SOLD', 'Sold on order ORD-261006-0031', NULL, 'BAT-2026-003'),
('KTCANK0001002', '002', 'KTC-ANK-0001', 'KTC-ANK-0001-002', 356.00, 'SOLD', 'Sold on order ORD-260926-0028', NULL, 'BAT-2026-003'),
('HPPRNG0001001', '001', 'HPP-RNG-0001', 'HPP-RNG-0001-001', 258.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('HPPRNG0001002', '002', 'HPP-RNG-0001', 'HPP-RNG-0001-002', 197.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('CSFBNG0001001', '001', 'CSF-BNG-0001', 'CSF-BNG-0001-001', 465.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('CSFBNG0001002', '002', 'CSF-BNG-0001', 'CSF-BNG-0001-002', 556.00, 'SOLD', 'Sold on order ORD-260705-0002', NULL, 'BAT-2026-005'),
('CSFBNG0001003', '003', 'CSF-BNG-0001', 'CSF-BNG-0001-003', 572.00, 'RETURNED', 'Returned on order ORD-260721-0039 (received back)', NULL, 'BAT-2026-005'),
('CSFBNG0001004', '004', 'CSF-BNG-0001', 'CSF-BNG-0001-004', 516.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('DOAEAR0001001', '001', 'DOA-EAR-0001', 'DOA-EAR-0001-001', 533.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('DOAEAR0001002', '002', 'DOA-EAR-0001', 'DOA-EAR-0001-002', 501.00, 'SOLD', 'Sold on order ORD-260730-0010', NULL, 'BAT-2026-006'),
('DOAEAR0001003', '003', 'DOA-EAR-0001', 'DOA-EAR-0001-003', 477.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('MBSNCK0002001', '001', 'MBS-NCK-0002', 'MBS-NCK-0002-001', 583.00, 'AVAILABLE', NULL, 'Slight tarnish on clasp; polish before dispatch', 'BAT-2026-007'),
('MBSNCK0002002', '002', 'MBS-NCK-0002', 'MBS-NCK-0002-002', 516.00, 'SOLD', 'Sold on order ORD-260831-0020', NULL, 'BAT-2026-007'),
('MBSNCK0002003', '003', 'MBS-NCK-0002', 'MBS-NCK-0002-003', 554.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('MBSNCK0002004', '004', 'MBS-NCK-0002', 'MBS-NCK-0002-004', 521.00, 'SOLD', 'Sold on order ORD-261018-0035', NULL, 'BAT-2026-007'),
('MBSNCK0002005', '005', 'MBS-NCK-0002', 'MBS-NCK-0002-005', 692.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('BDCMTK0002001', '001', 'BDC-MTK-0002', 'BDC-MTK-0002-001', 167.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCMTK0002002', '002', 'BDC-MTK-0002', 'BDC-MTK-0002-002', 149.00, 'SOLD', 'Sold on order ORD-260820-0016', NULL, 'BAT-2026-008'),
('BDCMTK0002003', '003', 'BDC-MTK-0002', 'BDC-MTK-0002-003', 141.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCMTK0002004', '004', 'BDC-MTK-0002', 'BDC-MTK-0002-004', 159.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('JKHMTK0003001', '001', 'JKH-MTK-0003', 'JKH-MTK-0003-001', 321.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHMTK0003002', '002', 'JKH-MTK-0003', 'JKH-MTK-0003-002', 291.00, 'SOLD', 'Sold on order ORD-260805-0012', NULL, 'BAT-2026-001'),
('JKHMTK0003003', '003', 'JKH-MTK-0003', 'JKH-MTK-0003-003', 344.00, 'SOLD', 'Sold on order ORD-261022-0036', NULL, 'BAT-2026-001'),
('MBWANK0002001', '001', 'MBW-ANK-0002', 'MBW-ANK-0002-001', 303.00, 'SOLD', 'Sold on order ORD-261014-0034', NULL, 'BAT-2026-002'),
('MBWANK0002002', '002', 'MBW-ANK-0002', 'MBW-ANK-0002-002', 358.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('KTCRNG0002001', '001', 'KTC-RNG-0002', 'KTC-RNG-0002-001', 155.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCRNG0002002', '002', 'KTC-RNG-0002', 'KTC-RNG-0002-002', 205.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCRNG0002003', '003', 'KTC-RNG-0002', 'KTC-RNG-0002-003', 195.00, 'SOLD', 'Sold on order ORD-260707-0003', NULL, 'BAT-2026-003'),
('KTCRNG0002004', '004', 'KTC-RNG-0002', 'KTC-RNG-0002-004', 182.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCRNG0002005', '005', 'KTC-RNG-0002', 'KTC-RNG-0002-005', 206.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('HPPBNG0002001', '001', 'HPP-BNG-0002', 'HPP-BNG-0002-001', 292.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('HPPBNG0002002', '002', 'HPP-BNG-0002', 'HPP-BNG-0002-002', 237.00, 'AVAILABLE', 'Released: order ORD-260721-0007 cancelled', NULL, 'BAT-2026-004'),
('CSFEAR0002001', '001', 'CSF-EAR-0002', 'CSF-EAR-0002-001', 154.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('CSFEAR0002002', '002', 'CSF-EAR-0002', 'CSF-EAR-0002-002', 177.00, 'SOLD', 'Sold on order ORD-261018-0035', NULL, 'BAT-2026-005'),
('DOANCK0003001', '001', 'DOA-NCK-0003', 'DOA-NCK-0003-001', 1071.00, 'SOLD', 'Sold on order ORD-260829-0019', NULL, 'BAT-2026-006'),
('DOANCK0003002', '002', 'DOA-NCK-0003', 'DOA-NCK-0003-002', 1047.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('DOANCK0003003', '003', 'DOA-NCK-0003', 'DOA-NCK-0003-003', 1221.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('MBSMTK0004001', '001', 'MBS-MTK-0004', 'MBS-MTK-0004-001', 177.00, 'RESERVED', 'Reserved for order ORD-261029-0038', NULL, 'BAT-2026-007'),
('MBSMTK0004002', '002', 'MBS-MTK-0004', 'MBS-MTK-0004-002', 180.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('MBSMTK0004003', '003', 'MBS-MTK-0004', 'MBS-MTK-0004-003', 175.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('MBSMTK0004004', '004', 'MBS-MTK-0004', 'MBS-MTK-0004-004', 207.00, 'SOLD', 'Sold on order ORD-260823-0017', NULL, 'BAT-2026-007'),
('BDCANK0003001', '001', 'BDC-ANK-0003', 'BDC-ANK-0003-001', 330.00, 'SOLD', 'Sold on order ORD-260712-0004', NULL, 'BAT-2026-008'),
('BDCANK0003002', '002', 'BDC-ANK-0003', 'BDC-ANK-0003-002', 379.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCANK0003003', '003', 'BDC-ANK-0003', 'BDC-ANK-0003-003', 413.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCANK0003004', '004', 'BDC-ANK-0003', 'BDC-ANK-0003-004', 342.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCANK0003005', '005', 'BDC-ANK-0003', 'BDC-ANK-0003-005', 350.00, 'RETURNED', 'Returned on order ORD-260724-0040 (pickup pending)', NULL, 'BAT-2026-008'),
('JKHANK0004001', '001', 'JKH-ANK-0004', 'JKH-ANK-0004-001', 182.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHANK0004002', '002', 'JKH-ANK-0004', 'JKH-ANK-0004-002', 198.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHANK0004003', '003', 'JKH-ANK-0004', 'JKH-ANK-0004-003', 175.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHANK0004004', '004', 'JKH-ANK-0004', 'JKH-ANK-0004-004', 198.00, 'SOLD', 'Sold on order ORD-260707-0003', NULL, 'BAT-2026-001'),
('JKHANK0004005', '005', 'JKH-ANK-0004', 'JKH-ANK-0004-005', 152.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('MBWRNG0003001', '001', 'MBW-RNG-0003', 'MBW-RNG-0003-001', 298.00, 'SOLD', 'Sold on order ORD-261002-0030', NULL, 'BAT-2026-002'),
('MBWRNG0003002', '002', 'MBW-RNG-0003', 'MBW-RNG-0003-002', 349.00, 'AVAILABLE', 'Released: order ORD-260908-0022 cancelled', NULL, 'BAT-2026-002'),
('MBWRNG0003003', '003', 'MBW-RNG-0003', 'MBW-RNG-0003-003', 294.00, 'SOLD', 'Sold on order ORD-261006-0031', NULL, 'BAT-2026-002'),
('MBWRNG0003004', '004', 'MBW-RNG-0003', 'MBW-RNG-0003-004', 381.00, 'SOLD', 'Sold on order ORD-260703-0001', NULL, 'BAT-2026-002'),
('MBWRNG0003005', '005', 'MBW-RNG-0003', 'MBW-RNG-0003-005', 348.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('KTCBNG0003001', '001', 'KTC-BNG-0003', 'KTC-BNG-0003-001', 481.00, 'SOLD', 'Sold on order ORD-260725-0008', NULL, 'BAT-2026-003'),
('KTCBNG0003002', '002', 'KTC-BNG-0003', 'KTC-BNG-0003-002', 418.00, 'SOLD', 'Sold on order ORD-260921-0026', NULL, 'BAT-2026-003'),
('KTCBNG0003003', '003', 'KTC-BNG-0003', 'KTC-BNG-0003-003', 402.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCBNG0003004', '004', 'KTC-BNG-0003', 'KTC-BNG-0003-004', 494.00, 'SOLD', 'Sold on order ORD-260824-0018', NULL, 'BAT-2026-003'),
('HPPEAR0003001', '001', 'HPP-EAR-0003', 'HPP-EAR-0003-001', 494.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('HPPEAR0003002', '002', 'HPP-EAR-0003', 'HPP-EAR-0003-002', 607.00, 'SOLD', 'Sold on order ORD-260909-0023', NULL, 'BAT-2026-004'),
('HPPEAR0003003', '003', 'HPP-EAR-0003', 'HPP-EAR-0003-003', 497.00, 'AVAILABLE', 'Released: order ORD-260908-0022 cancelled', NULL, 'BAT-2026-004'),
('HPPEAR0003004', '004', 'HPP-EAR-0003', 'HPP-EAR-0003-004', 536.00, 'SOLD', 'Sold on order ORD-260814-0015', NULL, 'BAT-2026-004'),
('HPPEAR0003005', '005', 'HPP-EAR-0003', 'HPP-EAR-0003-005', 534.00, 'SOLD', 'Sold on order ORD-261010-0032', NULL, 'BAT-2026-004'),
('CSFNCK0004001', '001', 'CSF-NCK-0004', 'CSF-NCK-0004-001', 517.00, 'SOLD', 'Sold on order ORD-260728-0009', NULL, 'BAT-2026-005'),
('CSFNCK0004002', '002', 'CSF-NCK-0004', 'CSF-NCK-0004-002', 472.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('CSFNCK0004003', '003', 'CSF-NCK-0004', 'CSF-NCK-0004-003', 524.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('DOAMTK0005001', '001', 'DOA-MTK-0005', 'DOA-MTK-0005-001', 352.00, 'SOLD', 'Sold on order ORD-260924-0027', NULL, 'BAT-2026-006'),
('DOAMTK0005002', '002', 'DOA-MTK-0005', 'DOA-MTK-0005-002', 391.00, 'SOLD', 'Sold on order ORD-260803-0011', NULL, 'BAT-2026-006'),
('DOAMTK0005003', '003', 'DOA-MTK-0005', 'DOA-MTK-0005-003', 305.00, 'SOLD', 'Sold on order ORD-260909-0023', NULL, 'BAT-2026-006'),
('DOAMTK0005004', '004', 'DOA-MTK-0005', 'DOA-MTK-0005-004', 327.00, 'SOLD', 'Sold on order ORD-261013-0033', NULL, 'BAT-2026-006'),
('MBSANK0005001', '001', 'MBS-ANK-0005', 'MBS-ANK-0005-001', 415.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('MBSANK0005002', '002', 'MBS-ANK-0005', 'MBS-ANK-0005-002', 380.00, 'SOLD', 'Sold on order ORD-260718-0006', NULL, 'BAT-2026-007'),
('MBSANK0005003', '003', 'MBS-ANK-0005', 'MBS-ANK-0005-003', 407.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('BDCRNG0004001', '001', 'BDC-RNG-0004', 'BDC-RNG-0004-001', 188.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCRNG0004002', '002', 'BDC-RNG-0004', 'BDC-RNG-0004-002', 181.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('JKHRNG0005001', '001', 'JKH-RNG-0005', 'JKH-RNG-0005-001', 127.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHRNG0005002', '002', 'JKH-RNG-0005', 'JKH-RNG-0005-002', 121.00, 'SOLD', 'Sold on order ORD-260905-0021', NULL, 'BAT-2026-001'),
('JKHRNG0005003', '003', 'JKH-RNG-0005', 'JKH-RNG-0005-003', 104.00, 'SOLD', 'Sold on order ORD-260810-0013', NULL, 'BAT-2026-001'),
('JKHRNG0005004', '004', 'JKH-RNG-0005', 'JKH-RNG-0005-004', 118.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHRNG0005005', '005', 'JKH-RNG-0005', 'JKH-RNG-0005-005', 115.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('MBWBNG0004001', '001', 'MBW-BNG-0004', 'MBW-BNG-0004-001', 528.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('MBWBNG0004002', '002', 'MBW-BNG-0004', 'MBW-BNG-0004-002', 561.00, 'SOLD', 'Sold on order ORD-260916-0025', NULL, 'BAT-2026-002'),
('KTCEAR0004001', '001', 'KTC-EAR-0004', 'KTC-EAR-0004-001', 586.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCEAR0004002', '002', 'KTC-EAR-0004', 'KTC-EAR-0004-002', 520.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCEAR0004003', '003', 'KTC-EAR-0004', 'KTC-EAR-0004-003', 635.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('HPPNCK0005001', '001', 'HPP-NCK-0005', 'HPP-NCK-0005-001', 882.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('HPPNCK0005002', '002', 'HPP-NCK-0005', 'HPP-NCK-0005-002', 713.00, 'SOLD', 'Sold on order ORD-260707-0003', NULL, 'BAT-2026-004'),
('HPPNCK0005003', '003', 'HPP-NCK-0005', 'HPP-NCK-0005-003', 811.00, 'SOLD', 'Sold on order ORD-260705-0002', NULL, 'BAT-2026-004'),
('CSFMTK0006001', '001', 'CSF-MTK-0006', 'CSF-MTK-0006-001', 379.00, 'SOLD', 'Sold on order ORD-260812-0014', NULL, 'BAT-2026-005'),
('CSFMTK0006002', '002', 'CSF-MTK-0006', 'CSF-MTK-0006-002', 448.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('DOAANK0006001', '001', 'DOA-ANK-0006', 'DOA-ANK-0006-001', 384.00, 'SOLD', 'Sold on order ORD-261018-0035', NULL, 'BAT-2026-006'),
('DOAANK0006002', '002', 'DOA-ANK-0006', 'DOA-ANK-0006-002', 411.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('DOAANK0006003', '003', 'DOA-ANK-0006', 'DOA-ANK-0006-003', 372.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('MBSRNG0006001', '001', 'MBS-RNG-0006', 'MBS-RNG-0006-001', 349.00, 'AVAILABLE', 'Released: order ORD-260721-0007 cancelled', NULL, 'BAT-2026-007'),
('MBSRNG0006002', '002', 'MBS-RNG-0006', 'MBS-RNG-0006-002', 297.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('MBSRNG0006003', '003', 'MBS-RNG-0006', 'MBS-RNG-0006-003', 322.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('BDCBNG0005001', '001', 'BDC-BNG-0005', 'BDC-BNG-0005-001', 251.00, 'SOLD', 'Sold on order ORD-260929-0029', NULL, 'BAT-2026-008'),
('BDCBNG0005002', '002', 'BDC-BNG-0005', 'BDC-BNG-0005-002', 221.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCBNG0005003', '003', 'BDC-BNG-0005', 'BDC-BNG-0005-003', 234.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCBNG0005004', '004', 'BDC-BNG-0005', 'BDC-BNG-0005-004', 269.00, 'SOLD', 'Sold on order ORD-260812-0014', NULL, 'BAT-2026-008'),
('JKHBNG0006001', '001', 'JKH-BNG-0006', 'JKH-BNG-0006-001', 255.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHBNG0006002', '002', 'JKH-BNG-0006', 'JKH-BNG-0006-002', 214.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-001'),
('JKHBNG0006003', '003', 'JKH-BNG-0006', 'JKH-BNG-0006-003', 276.00, 'SOLD', 'Sold on order ORD-261025-0037', NULL, 'BAT-2026-001'),
('MBWEAR0005001', '001', 'MBW-EAR-0005', 'MBW-EAR-0005-001', 282.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('MBWEAR0005002', '002', 'MBW-EAR-0005', 'MBW-EAR-0005-002', 233.00, 'SOLD', 'Sold on order ORD-260831-0020', NULL, 'BAT-2026-002'),
('MBWEAR0005003', '003', 'MBW-EAR-0005', 'MBW-EAR-0005-003', 210.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-002'),
('KTCNCK0006001', '001', 'KTC-NCK-0006', 'KTC-NCK-0006-001', 900.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCNCK0006002', '002', 'KTC-NCK-0006', 'KTC-NCK-0006-002', 762.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('KTCNCK0006003', '003', 'KTC-NCK-0006', 'KTC-NCK-0006-003', 1011.00, 'SOLD', 'Sold on order ORD-260929-0029', NULL, 'BAT-2026-003'),
('KTCNCK0006004', '004', 'KTC-NCK-0006', 'KTC-NCK-0006-004', 831.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-003'),
('HPPMTK0007001', '001', 'HPP-MTK-0007', 'HPP-MTK-0007-001', 383.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('HPPMTK0007002', '002', 'HPP-MTK-0007', 'HPP-MTK-0007-002', 374.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-004'),
('CSFANK0007001', '001', 'CSF-ANK-0007', 'CSF-ANK-0007-001', 246.00, 'SOLD', 'Sold on order ORD-260703-0001', NULL, 'BAT-2026-005'),
('CSFANK0007002', '002', 'CSF-ANK-0007', 'CSF-ANK-0007-002', 271.00, 'SOLD', 'Sold on order ORD-260912-0024', NULL, 'BAT-2026-005'),
('CSFANK0007003', '003', 'CSF-ANK-0007', 'CSF-ANK-0007-003', 285.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-005'),
('DOARNG0007001', '001', 'DOA-RNG-0007', 'DOA-RNG-0007-001', 224.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-006'),
('MBSBNG0007001', '001', 'MBS-BNG-0007', 'MBS-BNG-0007-001', 434.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-007'),
('BDCEAR0006001', '001', 'BDC-EAR-0006', 'BDC-EAR-0006-001', 512.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008'),
('BDCEAR0006002', '002', 'BDC-EAR-0006', 'BDC-EAR-0006-002', 493.00, 'AVAILABLE', NULL, NULL, 'BAT-2026-008');

INSERT INTO api.orders (order_id, customer_id, order_type, original_order_id, order_channel, order_coupon_code, order_coupon_discount, order_date_time, order_status, contain_documents, order_total_amount) VALUES
('ORD-260703-0001', 'CUS00017', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-07-03 18:38:00+05:30', 'FULFILLED', TRUE, 1418.00),
('ORD-260705-0002', 'CUS00025', 'STANDARD', NULL, 'STALL', NULL, 0.00, '2026-07-05 14:13:00+05:30', 'FULFILLED', FALSE, 4872.00),
('ORD-260707-0003', 'CUS00019', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-07-07 20:35:00+05:30', 'DELIVERED', FALSE, 2527.00),
('ORD-260712-0004', 'CUS00016', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-07-12 18:27:00+05:30', 'FULFILLED', FALSE, 1955.36),
('ORD-260715-0005', 'CUS00025', 'STANDARD', NULL, 'FACEBOOK', NULL, 0.00, '2026-07-15 19:50:00+05:30', 'RETURN_INITIATED', FALSE, 839.00),
('ORD-260718-0006', 'CUS00023', 'STANDARD', NULL, 'STALL', NULL, 0.00, '2026-07-18 20:35:00+05:30', 'FULFILLED', FALSE, 849.00),
('ORD-260721-0007', 'CUS00023', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-07-21 16:05:00+05:30', 'CANCELLED', FALSE, 1308.00),
('ORD-260721-0039', 'CUS00016', 'RETURN', 'ORD-260712-0004', 'INSTAGRAM', NULL, 0.00, '2026-07-21 21:27:00+05:30', 'DELIVERED', FALSE, 1149.00),
('ORD-260724-0040', 'CUS00025', 'RETURN', 'ORD-260715-0005', 'FACEBOOK', NULL, 0.00, '2026-07-24 22:50:00+05:30', 'PLACED', FALSE, 719.00),
('ORD-260725-0008', 'CUS00022', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-07-25 17:49:00+05:30', 'FULFILLED', FALSE, 1099.00),
('ORD-260728-0009', 'CUS00020', 'STANDARD', NULL, 'WHATSAPP', NULL, 0.00, '2026-07-28 17:54:00+05:30', 'DELIVERED', FALSE, 1024.00),
('ORD-260730-0010', 'CUS00004', 'STANDARD', NULL, 'WEBSITE', 'WELCOME100', 100.00, '2026-07-30 14:10:00+05:30', 'DELIVERED', TRUE, 1009.00),
('ORD-260803-0011', 'CUS00002', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-08-03 11:39:00+05:30', 'DELIVERED', FALSE, 949.00),
('ORD-260805-0012', 'CUS00023', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-08-05 21:13:00+05:30', 'FULFILLED', FALSE, 849.00),
('ORD-260810-0013', 'CUS00011', 'STANDARD', NULL, 'FACEBOOK', NULL, 0.00, '2026-08-10 16:13:00+05:30', 'FULFILLED', FALSE, 329.00),
('ORD-260812-0014', 'CUS00021', 'STANDARD', NULL, 'INSTAGRAM', 'DIWALI10', 150.00, '2026-08-12 19:31:00+05:30', 'DELIVERED', FALSE, 1494.96),
('ORD-260814-0015', 'CUS00010', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-08-14 21:57:00+05:30', 'DELIVERED', FALSE, 1419.00),
('ORD-260820-0016', 'CUS00003', 'STANDARD', NULL, 'FACEBOOK', NULL, 0.00, '2026-08-20 21:39:00+05:30', 'FULFILLED', FALSE, 935.96),
('ORD-260823-0017', 'CUS00020', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-08-23 20:07:00+05:30', 'DELIVERED', FALSE, 519.00),
('ORD-260824-0018', 'CUS00022', 'STANDARD', NULL, 'INSTAGRAM', 'WELCOME100', 100.00, '2026-08-24 10:22:00+05:30', 'FULFILLED', FALSE, 1059.00),
('ORD-260829-0019', 'CUS00004', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-08-29 19:10:00+05:30', 'FULFILLED', TRUE, 2569.00),
('ORD-260831-0020', 'CUS00017', 'STANDARD', NULL, 'STALL', NULL, 0.00, '2026-08-31 12:47:00+05:30', 'FULFILLED', FALSE, 1898.00),
('ORD-260905-0021', 'CUS00017', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-09-05 18:53:00+05:30', 'DELIVERED', FALSE, 379.00),
('ORD-260908-0022', 'CUS00030', 'STANDARD', NULL, 'INSTAGRAM', 'PUJO15', 300.00, '2026-09-08 20:07:00+05:30', 'CANCELLED', FALSE, 1768.00),
('ORD-260909-0023', 'CUS00014', 'STANDARD', NULL, 'RETAIL', NULL, 0.00, '2026-09-09 21:47:00+05:30', 'FULFILLED', FALSE, 2048.00),
('ORD-260912-0024', 'CUS00019', 'STANDARD', NULL, 'WHATSAPP', NULL, 0.00, '2026-09-12 20:15:00+05:30', 'FULFILLED', FALSE, 699.00),
('ORD-260916-0025', 'CUS00020', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-09-16 18:51:00+05:30', 'FULFILLED', FALSE, 1149.00),
('ORD-260921-0026', 'CUS00022', 'STANDARD', NULL, 'WEBSITE', 'DIWALI10', 100.00, '2026-09-21 11:38:00+05:30', 'FULFILLED', FALSE, 1019.00),
('ORD-260924-0027', 'CUS00025', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-09-24 13:27:00+05:30', 'FULFILLED', FALSE, 919.00),
('ORD-260926-0028', 'CUS00001', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-09-26 14:46:00+05:30', 'FULFILLED', TRUE, 849.00),
('ORD-260929-0029', 'CUS00030', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-09-29 16:53:00+05:30', 'DELIVERED', FALSE, 2568.00),
('ORD-261002-0030', 'CUS00012', 'STANDARD', NULL, 'STALL', NULL, 0.00, '2026-10-02 14:50:00+05:30', 'FULFILLED', FALSE, 749.00),
('ORD-261006-0031', 'CUS00023', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-10-06 10:16:00+05:30', 'FULFILLED', FALSE, 1518.00),
('ORD-261010-0032', 'CUS00025', 'STANDARD', NULL, 'WEBSITE', NULL, 0.00, '2026-10-10 13:43:00+05:30', 'DELIVERED', FALSE, 1359.00),
('ORD-261013-0033', 'CUS00017', 'STANDARD', NULL, 'RETAIL', NULL, 0.00, '2026-10-13 16:42:00+05:30', 'FULFILLED', FALSE, 799.00),
('ORD-261014-0034', 'CUS00008', 'STANDARD', NULL, 'INSTAGRAM', 'DIWALI10', 75.00, '2026-10-14 19:43:00+05:30', 'DELIVERED', FALSE, 794.00),
('ORD-261018-0035', 'CUS00025', 'STANDARD', NULL, 'WHATSAPP', NULL, 0.00, '2026-10-18 16:03:00+05:30', 'OUT_FOR_DELIVERY', FALSE, 2617.00),
('ORD-261022-0036', 'CUS00015', 'STANDARD', NULL, 'INSTAGRAM', NULL, 0.00, '2026-10-22 16:05:00+05:30', 'DELIVERED', FALSE, 769.00),
('ORD-261025-0037', 'CUS00009', 'STANDARD', NULL, 'FACEBOOK', NULL, 0.00, '2026-10-25 14:34:00+05:30', 'DELIVERED', TRUE, 579.98),
('ORD-261029-0038', 'CUS00010', 'STANDARD', NULL, 'INSTAGRAM', 'WELCOME100', 100.00, '2026-10-29 20:34:00+05:30', 'PACKED', FALSE, 419.00);

INSERT INTO api.order_addresses (order_id, order_address_type, order_address_complete, order_address_landmark, order_address_pincode, order_address_city, order_address_state, order_address_country) VALUES
('ORD-260703-0001', 'SHIPPING', 'Flat 4C, 180 Jubilee Hills Road No. 36', NULL, '600031', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-260703-0001', 'BILLING', 'Flat 4C, 180 Jubilee Hills Road No. 36', NULL, '600031', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-260707-0003', 'SHIPPING', 'Flat 9B, 52 Hill Cart Road', NULL, '781007', 'Guwahati', 'Assam', 'India'),
('ORD-260712-0004', 'SHIPPING', 'Flat 6C, 174 Lake Road', NULL, '500035', 'Hyderabad', 'Telangana', 'India'),
('ORD-260712-0004', 'BILLING', 'Flat 6C, 174 Lake Road', NULL, '500035', 'Hyderabad', 'Telangana', 'India'),
('ORD-260715-0005', 'SHIPPING', 'Flat 1D, 191 Hill Cart Road', 'Behind Post Office', '411041', 'Pune', 'Maharashtra', 'India'),
('ORD-260721-0007', 'SHIPPING', 'Flat 11D, 76 Jubilee Hills Road No. 36', 'Near City Centre Mall', '751086', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-260721-0007', 'BILLING', 'Flat 11D, 76 Jubilee Hills Road No. 36', 'Near City Centre Mall', '751086', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-260725-0008', 'SHIPPING', 'Flat 9A, 154 Jubilee Hills Road No. 36', NULL, '400036', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260728-0009', 'SHIPPING', 'Flat 10B, 26 Lajpat Nagar II', NULL, '110072', 'New Delhi', 'Delhi', 'India'),
('ORD-260730-0010', 'SHIPPING', 'Flat 3D, 73 Park Street', 'Near City Centre Mall', '400045', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260730-0010', 'BILLING', 'Flat 3D, 73 Park Street', 'Near City Centre Mall', '400045', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260803-0011', 'SHIPPING', 'Flat 10A, 187 MG Road', NULL, '751070', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-260805-0012', 'SHIPPING', 'Flat 12A, 52 MG Road', 'Near Metro Station', '751086', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-260810-0013', 'SHIPPING', 'Flat 3C, 37 Linking Road', 'Near Metro Station', '500014', 'Hyderabad', 'Telangana', 'India'),
('ORD-260810-0013', 'BILLING', 'Flat 3C, 37 Linking Road', 'Near Metro Station', '500014', 'Hyderabad', 'Telangana', 'India'),
('ORD-260812-0014', 'SHIPPING', 'Flat 7C, 27 Lake Road', NULL, '734077', 'Siliguri', 'West Bengal', 'India'),
('ORD-260814-0015', 'SHIPPING', 'Flat 1B, 56 Gariahat Road', 'Near City Centre Mall', '500034', 'Hyderabad', 'Telangana', 'India'),
('ORD-260820-0016', 'SHIPPING', 'Flat 2D, 158 Park Street', NULL, '600097', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-260820-0016', 'BILLING', 'Flat 2D, 158 Park Street', NULL, '600097', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-260823-0017', 'SHIPPING', 'Flat 9B, 11 Lajpat Nagar II', 'Opp. State Bank', '110052', 'New Delhi', 'Delhi', 'India'),
('ORD-260824-0018', 'SHIPPING', 'Flat 2A, 88 Anna Salai', 'Near Metro Station', '400091', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260829-0019', 'SHIPPING', 'Flat 3A, 47 Southern Avenue', 'Opp. State Bank', '400079', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260829-0019', 'BILLING', 'Flat 3A, 47 Southern Avenue', 'Opp. State Bank', '400079', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260905-0021', 'SHIPPING', 'Flat 11D, 199 Southern Avenue', NULL, '600047', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-260908-0022', 'SHIPPING', 'Flat 11B, 13 Anna Salai', 'Near Metro Station', '560004', 'Bengaluru', 'Karnataka', 'India'),
('ORD-260908-0022', 'BILLING', 'Flat 11B, 13 Anna Salai', 'Near Metro Station', '560004', 'Bengaluru', 'Karnataka', 'India'),
('ORD-260912-0024', 'SHIPPING', 'Flat 7B, 190 Park Street', 'Opp. State Bank', '781095', 'Guwahati', 'Assam', 'India'),
('ORD-260916-0025', 'SHIPPING', 'Flat 6A, 175 Anna Salai', NULL, '110044', 'New Delhi', 'Delhi', 'India'),
('ORD-260916-0025', 'BILLING', 'Flat 6A, 175 Anna Salai', NULL, '110044', 'New Delhi', 'Delhi', 'India'),
('ORD-260921-0026', 'SHIPPING', 'Flat 7C, 105 Anna Salai', 'Behind Post Office', '400079', 'Mumbai', 'Maharashtra', 'India'),
('ORD-260924-0027', 'SHIPPING', 'Flat 10D, 59 Southern Avenue', NULL, '411038', 'Pune', 'Maharashtra', 'India'),
('ORD-260926-0028', 'SHIPPING', 'Flat 8C, 46 Jubilee Hills Road No. 36', 'Opp. State Bank', '411062', 'Pune', 'Maharashtra', 'India'),
('ORD-260926-0028', 'BILLING', 'Flat 8C, 46 Jubilee Hills Road No. 36', 'Opp. State Bank', '411062', 'Pune', 'Maharashtra', 'India'),
('ORD-260929-0029', 'SHIPPING', 'Flat 1B, 25 Park Street', NULL, '560029', 'Bengaluru', 'Karnataka', 'India'),
('ORD-261006-0031', 'SHIPPING', 'Flat 8C, 90 Linking Road', 'Opp. State Bank', '751062', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-261006-0031', 'BILLING', 'Flat 8C, 90 Linking Road', 'Opp. State Bank', '751062', 'Bhubaneswar', 'Odisha', 'India'),
('ORD-261010-0032', 'SHIPPING', 'Flat 9C, 52 MG Road', NULL, '411057', 'Pune', 'Maharashtra', 'India'),
('ORD-261014-0034', 'SHIPPING', 'Flat 8D, 6 Janpath', NULL, '700039', 'Kolkata', 'West Bengal', 'India'),
('ORD-261014-0034', 'BILLING', 'Flat 8D, 6 Janpath', NULL, '700039', 'Kolkata', 'West Bengal', 'India'),
('ORD-261018-0035', 'SHIPPING', 'Flat 1B, 96 Hill Cart Road', 'Behind Post Office', '411071', 'Pune', 'Maharashtra', 'India'),
('ORD-261022-0036', 'SHIPPING', 'Flat 9B, 132 Linking Road', NULL, '600011', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-261025-0037', 'SHIPPING', 'Flat 1C, 155 Gariahat Road', NULL, '600036', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-261025-0037', 'BILLING', 'Flat 1C, 155 Gariahat Road', NULL, '600036', 'Chennai', 'Tamil Nadu', 'India'),
('ORD-261029-0038', 'SHIPPING', 'Flat 7B, 96 GS Road', NULL, '500015', 'Hyderabad', 'Telangana', 'India'),
('ORD-260721-0039', 'SHIPPING', 'Flat 6C, 174 Lake Road', NULL, '500035', 'Hyderabad', 'Telangana', 'India'),
('ORD-260724-0040', 'SHIPPING', 'Flat 1D, 191 Hill Cart Road', 'Behind Post Office', '411041', 'Pune', 'Maharashtra', 'India');

INSERT INTO api.order_charges (order_id, order_delivery_charges, order_packing_charges, order_cod_charges, order_transaction_fee, order_goodies_charges) VALUES
('ORD-260703-0001', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260707-0003', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260712-0004', 0.00, 20.00, 0.00, 37.36, 30.00),
('ORD-260715-0005', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260721-0007', 60.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260725-0008', 80.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260728-0009', 60.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260730-0010', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260803-0011', 100.00, 20.00, 0.00, 0.00, 30.00),
('ORD-260805-0012', 80.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260810-0013', 60.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260812-0014', 100.00, 20.00, 0.00, 26.96, 0.00),
('ORD-260814-0015', 100.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260820-0016', 0.00, 20.00, 0.00, 17.96, 0.00),
('ORD-260823-0017', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260824-0018', 60.00, 20.00, 50.00, 0.00, 30.00),
('ORD-260829-0019', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260905-0021', 60.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260908-0022', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260912-0024', 80.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260916-0025', 60.00, 20.00, 50.00, 0.00, 30.00),
('ORD-260921-0026', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260924-0027', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260926-0028', 80.00, 20.00, 50.00, 0.00, 0.00),
('ORD-260929-0029', 0.00, 20.00, 0.00, 0.00, 0.00),
('ORD-261006-0031', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-261010-0032', 60.00, 20.00, 0.00, 0.00, 30.00),
('ORD-261014-0034', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-261018-0035', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-261022-0036', 0.00, 20.00, 50.00, 0.00, 0.00),
('ORD-261025-0037', 0.00, 20.00, 0.00, 10.98, 0.00),
('ORD-261029-0038', 100.00, 20.00, 0.00, 0.00, 0.00),
('ORD-260721-0039', 0.00, 0.00, 0.00, 0.00, 0.00),
('ORD-260724-0040', 0.00, 0.00, 0.00, 0.00, 0.00);

INSERT INTO api.order_delivery_details (order_id, order_tag, pickup_address_id, reseller_name, send_notification, verified_order) VALUES
('ORD-260703-0001', 'PRIORITY', 2, NULL, FALSE, TRUE),
('ORD-260707-0003', NULL, 1, NULL, TRUE, TRUE),
('ORD-260712-0004', 'PRIORITY', 2, NULL, TRUE, TRUE),
('ORD-260715-0005', NULL, 1, NULL, TRUE, TRUE),
('ORD-260721-0007', NULL, 2, NULL, TRUE, FALSE),
('ORD-260725-0008', 'GIFT', 1, NULL, TRUE, TRUE),
('ORD-260728-0009', 'FRAGILE', 1, NULL, FALSE, TRUE),
('ORD-260730-0010', NULL, 2, NULL, TRUE, TRUE),
('ORD-260803-0011', NULL, 1, NULL, TRUE, TRUE),
('ORD-260805-0012', NULL, 1, NULL, TRUE, TRUE),
('ORD-260810-0013', 'PRIORITY', 2, NULL, TRUE, TRUE),
('ORD-260812-0014', 'FRAGILE', 1, NULL, TRUE, TRUE),
('ORD-260814-0015', 'PRIORITY', 1, NULL, TRUE, TRUE),
('ORD-260820-0016', 'FRAGILE', 2, 'Kolkata Craft Collective', TRUE, TRUE),
('ORD-260823-0017', 'FRAGILE', 1, NULL, FALSE, TRUE),
('ORD-260824-0018', 'GIFT', 1, NULL, TRUE, TRUE),
('ORD-260829-0019', 'GIFT', 2, NULL, TRUE, TRUE),
('ORD-260905-0021', 'FRAGILE', 1, NULL, TRUE, TRUE),
('ORD-260908-0022', 'GIFT', 2, NULL, TRUE, FALSE),
('ORD-260912-0024', 'PRIORITY', 1, NULL, TRUE, TRUE),
('ORD-260916-0025', NULL, 2, NULL, FALSE, TRUE),
('ORD-260921-0026', 'GIFT', 1, 'Kolkata Craft Collective', TRUE, TRUE),
('ORD-260924-0027', 'GIFT', 1, NULL, TRUE, TRUE),
('ORD-260926-0028', 'FRAGILE', 2, NULL, TRUE, TRUE),
('ORD-260929-0029', 'PRIORITY', 1, NULL, TRUE, TRUE),
('ORD-261006-0031', 'GIFT', 2, NULL, TRUE, TRUE),
('ORD-261010-0032', 'GIFT', 1, NULL, TRUE, TRUE),
('ORD-261014-0034', 'FRAGILE', 2, NULL, TRUE, TRUE),
('ORD-261018-0035', 'FRAGILE', 1, NULL, TRUE, TRUE),
('ORD-261022-0036', NULL, 1, 'Kolkata Craft Collective', TRUE, TRUE),
('ORD-261025-0037', 'GIFT', 2, NULL, TRUE, TRUE),
('ORD-261029-0038', NULL, 1, NULL, TRUE, FALSE),
('ORD-260721-0039', 'RETURN_PICKUP', 1, NULL, TRUE, TRUE),
('ORD-260724-0040', 'RETURN_PICKUP', 1, NULL, TRUE, FALSE);

INSERT INTO api.order_items (order_id, product_sku, product_master_sku, order_item_price, order_item_discount) VALUES
('ORD-260703-0001', 'CSF-ANK-0007', 'CSF-ANK-0007-001', 599.00, 0.00),
('ORD-260703-0001', 'MBW-RNG-0003', 'MBW-RNG-0003-004', 749.00, 0.00),
('ORD-260705-0002', 'HPP-NCK-0005', 'HPP-NCK-0005-003', 1699.00, 0.00),
('ORD-260705-0002', 'JKH-NCK-0001', 'JKH-NCK-0001-002', 2249.00, 225.00),
('ORD-260705-0002', 'CSF-BNG-0001', 'CSF-BNG-0001-002', 1149.00, 0.00),
('ORD-260707-0003', 'HPP-NCK-0005', 'HPP-NCK-0005-002', 1699.00, 0.00),
('ORD-260707-0003', 'KTC-RNG-0002', 'KTC-RNG-0002-003', 399.00, 40.00),
('ORD-260707-0003', 'JKH-ANK-0004', 'JKH-ANK-0004-004', 399.00, 0.00),
('ORD-260712-0004', 'CSF-BNG-0001', 'CSF-BNG-0001-003', 1149.00, 0.00),
('ORD-260712-0004', 'BDC-ANK-0003', 'BDC-ANK-0003-001', 799.00, 80.00),
('ORD-260715-0005', 'BDC-ANK-0003', 'BDC-ANK-0003-005', 799.00, 80.00),
('ORD-260718-0006', 'MBS-ANK-0005', 'MBS-ANK-0005-002', 849.00, 0.00),
('ORD-260721-0007', 'MBS-RNG-0006', 'MBS-RNG-0006-001', 699.00, 70.00),
('ORD-260721-0007', 'HPP-BNG-0002', 'HPP-BNG-0002-002', 599.00, 0.00),
('ORD-260725-0008', 'KTC-BNG-0003', 'KTC-BNG-0003-001', 999.00, 0.00),
('ORD-260728-0009', 'CSF-NCK-0004', 'CSF-NCK-0004-001', 1049.00, 105.00),
('ORD-260730-0010', 'DOA-EAR-0001', 'DOA-EAR-0001-002', 1099.00, 110.00),
('ORD-260803-0011', 'DOA-MTK-0005', 'DOA-MTK-0005-002', 799.00, 0.00),
('ORD-260805-0012', 'JKH-MTK-0003', 'JKH-MTK-0003-002', 699.00, 0.00),
('ORD-260810-0013', 'JKH-RNG-0005', 'JKH-RNG-0005-003', 249.00, 0.00),
('ORD-260812-0014', 'BDC-BNG-0005', 'BDC-BNG-0005-004', 549.00, 0.00),
('ORD-260812-0014', 'CSF-MTK-0006', 'CSF-MTK-0006-001', 949.00, 0.00),
('ORD-260814-0015', 'HPP-EAR-0003', 'HPP-EAR-0003-004', 1249.00, 0.00),
('ORD-260820-0016', 'BDC-MTK-0002', 'BDC-MTK-0002-002', 349.00, 0.00),
('ORD-260820-0016', 'MBW-MTK-0001', 'MBW-MTK-0001-002', 549.00, 0.00),
('ORD-260823-0017', 'MBS-MTK-0004', 'MBS-MTK-0004-004', 399.00, 0.00),
('ORD-260824-0018', 'KTC-BNG-0003', 'KTC-BNG-0003-004', 999.00, 0.00),
('ORD-260829-0019', 'DOA-NCK-0003', 'DOA-NCK-0003-001', 2499.00, 0.00),
('ORD-260831-0020', 'MBS-NCK-0002', 'MBS-NCK-0002-002', 1349.00, 0.00),
('ORD-260831-0020', 'MBW-EAR-0005', 'MBW-EAR-0005-002', 549.00, 0.00),
('ORD-260905-0021', 'JKH-RNG-0005', 'JKH-RNG-0005-002', 249.00, 0.00),
('ORD-260908-0022', 'HPP-EAR-0003', 'HPP-EAR-0003-003', 1249.00, 0.00),
('ORD-260908-0022', 'MBW-RNG-0003', 'MBW-RNG-0003-002', 749.00, 0.00),
('ORD-260909-0023', 'HPP-EAR-0003', 'HPP-EAR-0003-002', 1249.00, 0.00),
('ORD-260909-0023', 'DOA-MTK-0005', 'DOA-MTK-0005-003', 799.00, 0.00),
('ORD-260912-0024', 'CSF-ANK-0007', 'CSF-ANK-0007-002', 599.00, 0.00),
('ORD-260916-0025', 'MBW-BNG-0004', 'MBW-BNG-0004-002', 1099.00, 110.00),
('ORD-260921-0026', 'KTC-BNG-0003', 'KTC-BNG-0003-002', 999.00, 0.00),
('ORD-260924-0027', 'DOA-MTK-0005', 'DOA-MTK-0005-001', 799.00, 0.00),
('ORD-260926-0028', 'KTC-ANK-0001', 'KTC-ANK-0001-002', 699.00, 0.00),
('ORD-260929-0029', 'BDC-BNG-0005', 'BDC-BNG-0005-001', 549.00, 0.00),
('ORD-260929-0029', 'KTC-NCK-0006', 'KTC-NCK-0006-003', 1999.00, 0.00),
('ORD-261002-0030', 'MBW-RNG-0003', 'MBW-RNG-0003-001', 749.00, 0.00),
('ORD-261006-0031', 'MBW-RNG-0003', 'MBW-RNG-0003-003', 749.00, 0.00),
('ORD-261006-0031', 'KTC-ANK-0001', 'KTC-ANK-0001-001', 699.00, 0.00),
('ORD-261010-0032', 'HPP-EAR-0003', 'HPP-EAR-0003-005', 1249.00, 0.00),
('ORD-261013-0033', 'DOA-MTK-0005', 'DOA-MTK-0005-004', 799.00, 0.00),
('ORD-261014-0034', 'MBW-ANK-0002', 'MBW-ANK-0002-001', 749.00, 0.00),
('ORD-261018-0035', 'MBS-NCK-0002', 'MBS-NCK-0002-004', 1349.00, 0.00),
('ORD-261018-0035', 'CSF-EAR-0002', 'CSF-EAR-0002-002', 399.00, 0.00),
('ORD-261018-0035', 'DOA-ANK-0006', 'DOA-ANK-0006-001', 799.00, 0.00),
('ORD-261022-0036', 'JKH-MTK-0003', 'JKH-MTK-0003-003', 699.00, 0.00),
('ORD-261025-0037', 'JKH-BNG-0006', 'JKH-BNG-0006-003', 549.00, 0.00),
('ORD-261029-0038', 'MBS-MTK-0004', 'MBS-MTK-0004-001', 399.00, 0.00),
('ORD-260721-0039', 'CSF-BNG-0001', 'CSF-BNG-0001-003', 1149.00, 0.00),
('ORD-260724-0040', 'BDC-ANK-0003', 'BDC-ANK-0003-005', 799.00, 80.00);

INSERT INTO api.order_payments (order_id, order_payment_type, order_payment_method, order_payment_partial_cod, order_payment_paid_amount, order_payment_pending_amount, order_payment_status) VALUES
('ORD-260703-0001', 'COD', 'COD', FALSE, 1418.00, 0.00, 'PAID'),
('ORD-260705-0002', 'PREPAID', 'CASH', FALSE, 4872.00, 0.00, 'PAID'),
('ORD-260707-0003', 'COD', 'COD', TRUE, 2527.00, 0.00, 'PAID'),
('ORD-260712-0004', 'PREPAID', 'CREDIT_CARD', FALSE, 1955.36, 0.00, 'PAID'),
('ORD-260715-0005', 'PREPAID', 'UPI', FALSE, 839.00, 0.00, 'PAID'),
('ORD-260718-0006', 'PREPAID', 'UPI', FALSE, 849.00, 0.00, 'PAID'),
('ORD-260721-0007', 'PREPAID', 'DEBIT_CARD', FALSE, 1308.00, 0.00, 'REFUNDED'),
('ORD-260725-0008', 'PREPAID', 'DEBIT_CARD', FALSE, 1099.00, 0.00, 'PAID'),
('ORD-260728-0009', 'PREPAID', 'UPI', FALSE, 1024.00, 0.00, 'PAID'),
('ORD-260730-0010', 'PREPAID', 'UPI', FALSE, 1009.00, 0.00, 'PAID'),
('ORD-260803-0011', 'PREPAID', 'DEBIT_CARD', FALSE, 949.00, 0.00, 'PAID'),
('ORD-260805-0012', 'COD', 'COD', FALSE, 849.00, 0.00, 'PAID'),
('ORD-260810-0013', 'PREPAID', 'UPI', FALSE, 329.00, 0.00, 'PAID'),
('ORD-260812-0014', 'PREPAID', 'CREDIT_CARD', FALSE, 1494.96, 0.00, 'PAID'),
('ORD-260814-0015', 'COD', 'COD', FALSE, 1419.00, 0.00, 'PAID'),
('ORD-260820-0016', 'PREPAID', 'CREDIT_CARD', FALSE, 935.96, 0.00, 'PAID'),
('ORD-260823-0017', 'PREPAID', 'DEBIT_CARD', FALSE, 519.00, 0.00, 'PAID'),
('ORD-260824-0018', 'COD', 'COD', TRUE, 1059.00, 0.00, 'PAID'),
('ORD-260829-0019', 'COD', 'COD', FALSE, 2569.00, 0.00, 'PAID'),
('ORD-260831-0020', 'PREPAID', 'CASH', FALSE, 1898.00, 0.00, 'PAID'),
('ORD-260905-0021', 'COD', 'COD', FALSE, 379.00, 0.00, 'PAID'),
('ORD-260908-0022', 'COD', 'COD', FALSE, 0.00, 0.00, 'FAILED'),
('ORD-260909-0023', 'PREPAID', 'CASH', FALSE, 2048.00, 0.00, 'PAID'),
('ORD-260912-0024', 'PREPAID', 'UPI', FALSE, 699.00, 0.00, 'PAID'),
('ORD-260916-0025', 'COD', 'COD', FALSE, 1149.00, 0.00, 'PAID'),
('ORD-260921-0026', 'PREPAID', 'UPI', FALSE, 1019.00, 0.00, 'PAID'),
('ORD-260924-0027', 'PREPAID', 'UPI', FALSE, 919.00, 0.00, 'PAID'),
('ORD-260926-0028', 'COD', 'COD', TRUE, 849.00, 0.00, 'PAID'),
('ORD-260929-0029', 'PREPAID', 'UPI', FALSE, 2568.00, 0.00, 'PAID'),
('ORD-261002-0030', 'PREPAID', 'UPI', FALSE, 749.00, 0.00, 'PAID'),
('ORD-261006-0031', 'COD', 'COD', FALSE, 1518.00, 0.00, 'PAID'),
('ORD-261010-0032', 'PREPAID', 'DEBIT_CARD', FALSE, 1359.00, 0.00, 'PAID'),
('ORD-261013-0033', 'PREPAID', 'UPI', FALSE, 799.00, 0.00, 'PAID'),
('ORD-261014-0034', 'PREPAID', 'DEBIT_CARD', FALSE, 794.00, 0.00, 'PAID'),
('ORD-261018-0035', 'COD', 'COD', FALSE, 0.00, 2617.00, 'OUTSTANDING'),
('ORD-261022-0036', 'COD', 'COD', FALSE, 769.00, 0.00, 'PAID'),
('ORD-261025-0037', 'PREPAID', 'CREDIT_CARD', FALSE, 579.98, 0.00, 'PAID'),
('ORD-261029-0038', 'PREPAID', 'DEBIT_CARD', FALSE, 419.00, 0.00, 'PAID'),
('ORD-260721-0039', 'PREPAID', 'UPI', FALSE, 1149.00, 0.00, 'REFUNDED'),
('ORD-260724-0040', 'PREPAID', 'UPI', FALSE, 0.00, 719.00, 'PENDING');


-- Create an anonymous web role for unauthenticated requests
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA api TO web_anon;

-- pickup_addresses (identity column is pickup_address_id)
GRANT SELECT, INSERT, UPDATE, DELETE ON api.pickup_addresses TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.pickup_addresses_pickup_address_id_seq TO web_anon;

-- vendors
GRANT SELECT, INSERT, UPDATE, DELETE ON api.vendors TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.vendors__id_seq TO web_anon;

-- vendor_pii
GRANT SELECT, INSERT, UPDATE, DELETE ON api.vendor_pii TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.vendor_pii__id_seq TO web_anon;

-- customers
GRANT SELECT, INSERT, UPDATE, DELETE ON api.customers TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.customers__id_seq TO web_anon;

-- customer_pii
GRANT SELECT, INSERT, UPDATE, DELETE ON api.customer_pii TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.customer_pii__id_seq TO web_anon;

-- batches
GRANT SELECT, INSERT, UPDATE, DELETE ON api.batches TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.batches__id_seq TO web_anon;

-- products
GRANT SELECT, INSERT, UPDATE, DELETE ON api.products TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.products__id_seq TO web_anon;

-- product_media
GRANT SELECT, INSERT, UPDATE, DELETE ON api.product_media TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.product_media__id_seq TO web_anon;

-- product_item
GRANT SELECT, INSERT, UPDATE, DELETE ON api.product_item TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.product_item__id_seq TO web_anon;

-- orders
GRANT SELECT, INSERT, UPDATE, DELETE ON api.orders TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.orders__id_seq TO web_anon;

-- order_addresses
GRANT SELECT, INSERT, UPDATE, DELETE ON api.order_addresses TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.order_addresses__id_seq TO web_anon;

-- order_charges
GRANT SELECT, INSERT, UPDATE, DELETE ON api.order_charges TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.order_charges__id_seq TO web_anon;

-- order_delivery_details
GRANT SELECT, INSERT, UPDATE, DELETE ON api.order_delivery_details TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.order_delivery_details__id_seq TO web_anon;

-- order_items
GRANT SELECT, INSERT, UPDATE, DELETE ON api.order_items TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.order_items__id_seq TO web_anon;

-- order_payments
GRANT SELECT, INSERT, UPDATE, DELETE ON api.order_payments TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.order_payments__id_seq TO web_anon;

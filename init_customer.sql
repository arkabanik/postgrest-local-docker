-- Create a dedicated schema for the API endpoints
CREATE SCHEMA api;

-- Create a customer table inside the schema
CREATE TABLE api.customers (
    id SERIAL NOT NULL,
    customer_id varchar(15) NOT NULL,
    customer_first_name varchar(100) NOT NULL,
    customer_last_name varchar(100) DEFAULT NULL,
    customer_status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    customer_type_code varchar(2) DEFAULT NULL,
    customer_type varchar(20) DEFAULT NULL,
    customer_joining_date date NOT NULL DEFAULT now(),
    creation_date timestamp(6) NOT NULL DEFAULT now(),
    expiry_date timestamp(6) NOT NULL DEFAULT '9999-12-01 00:00:00.000000'
);

-- Insert data into customer
INSERT INTO api.customers (id, customer_id, customer_first_name, customer_last_name, customer_status, customer_type_code, customer_type, customer_joining_date, creation_date, expiry_date) VALUES
    (1, 'EC8777015523', 'Bikash', 'Saha', 'ACTIVE', 'EC', 'Ecomm', '2026-09-05', '2026-09-08 15:21:15.000000', '2026-09-28 18:30:54.221518'),
    (5, 'EC2138513204', 'Arka', NULL, 'ACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-16 14:45:24.000000', '2026-09-20 12:07:16.000000'),
    (6, 'EC3259054552', 'Sruti', NULL, 'ACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-16 23:00:48.000000', '9999-12-01 00:00:00.000000'),
    (47, 'EC2138513204', 'Arka', 'Banik', 'ACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-20 12:07:16.000000', '2026-09-20 12:07:27.000000'),
    (48, 'EC2138513204', 'Arka', 'Banik', 'INACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-20 12:07:27.000000', '2026-09-20 12:07:42.000000'),
    (49, 'EC2138513204', 'Arka', NULL, 'ACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-20 12:07:42.000000', '2026-09-28 20:47:46.399148'),
    (123, 'MC9716046407', 'Goutham', NULL, 'ACTIVE', 'MC', 'Media', '2026-09-22', '2026-09-22 11:27:47.581500', '2026-09-29 00:53:09.222355'),
    (124, 'RC1349331443', 'Stall_Purva', 'banik', 'ACTIVE', 'RC', 'Retail', '2026-09-22', '2026-09-22 15:24:59.182626', '9999-12-01 00:00:00.000000'),
    (125, 'RC8543619756', 'Stall', 'DSR', 'ACTIVE', 'RC', 'Retail', '2026-09-22', '2026-09-22 18:16:10.086682', '9999-12-01 00:00:00.000000'),
    (170, 'EC8777015523', 'Bikash', 'Saha', 'INACTIVE', 'EC', 'Ecomm', '2026-09-05', '2026-09-28 18:30:54.221518', '2026-09-28 18:31:06.072912'),
    (171, 'EC8777015523', 'Bikash', 'Saha', 'ACTIVE', 'EC', 'Ecomm', '2026-09-05', '2026-09-28 18:31:06.072912', '2026-09-29 01:02:37.017477'),
    (172, 'EC2138513204', 'Arka', NULL, 'INACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-28 20:47:46.399148', '2026-09-28 20:47:48.613644'),
    (173, 'EC2138513204', 'Arka', NULL, 'ACTIVE', 'EC', 'Ecomm', '2026-09-16', '2026-09-28 20:47:48.613644', '9999-12-01 00:00:00.000000'),
    (174, 'MC9716046407', 'Goutham', NULL, 'BLOCKED', 'MC', 'Media', '2026-09-22', '2026-09-29 00:53:09.222355', '2026-09-29 00:53:16.451411'),
    (175, 'MC9716046407', 'Goutham', NULL, 'ACTIVE', 'MC', 'Media', '2026-09-22', '2026-09-29 00:53:16.451411', '9999-12-01 00:00:00.000000'),
    (176, 'EC8777015523', 'Bikash', 'Saha', 'BLOCKED', 'EC', 'Ecomm', '2026-09-05', '2026-09-29 01:02:37.017477', '2026-09-29 01:02:47.667665'),
    (177, 'EC8777015523', 'Bikash', 'Saha', 'ACTIVE', 'EC', 'Ecomm', '2026-09-05', '2026-09-29 01:02:47.667665', '9999-12-01 00:00:00.000000'),
    (178, 'MC3163861887', 'Ankita', NULL, 'ACTIVE', 'MC', 'Media', '2026-09-29', '2026-09-29 18:28:02.424066', '9999-12-01 00:00:00.000000'),
    (251, 'MC1033159120', 'Sreyosee', NULL, 'ACTIVE', 'MC', 'Media', '2026-10-08', '2026-10-08 21:38:34.570219', '9999-12-01 00:00:00.000000'),
    (252, 'RC3275798408', 'Flea Durga Petals', NULL, 'ACTIVE', 'RC', 'Retail', '2026-10-08', '2026-10-08 21:53:49.012841', '9999-12-01 00:00:00.000000');

-- Create an anonymous web role for unauthenticated requests
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON api.customers TO web_anon;
GRANT USAGE, SELECT ON SEQUENCE api.customers_id_seq TO web_anon;


--
-- RedShift Schema
--

DROP TABLE IF EXISTS product_dim;

CREATE TABLE product_dim
(
  product_id          INTEGER  primary key sortkey,
  name                VARCHAR(22),
  supplier_id         INTEGER,
  category_id         INTEGER,
  quantity_per_unit   INTEGER,
  unit_price          DECIMAL(10,0),
  category_name       VARCHAR(50),
  description         VARCHAR(100),
  image_url           VARCHAR(100)
)
diststyle ALL;


DROP TABLE IF EXISTS supplier_dim;

CREATE TABLE supplier_dim
(
  supplier_id   INTEGER primary key sortkey,
  name          VARCHAR(25),
  address       VARCHAR(25),
  city          VARCHAR(10),
  state         VARCHAR(12),
  country       VARCHAR(12),
  phone         VARCHAR(15)
)
diststyle ALL;

DROP TABLE IF EXISTS customer_dim;

CREATE TABLE customer_dim
(
  cust_id      INTEGER  primary key sortkey,
  name         VARCHAR(25),
  mktsegment   VARCHAR(50),
  site_id      INTEGER,
  address      VARCHAR(25),
  city         VARCHAR(10),
  state        VARCHAR(12),
  country      VARCHAR(12),
  phone        VARCHAR(15)
)
diststyle ALL;

DROP TABLE IF EXISTS sales_order_fact;

CREATE TABLE sales_order_fact
(
  order_id         INTEGER encode delta32k,
  site_id          INTEGER encode delta32k,
  order_date       TIMESTAMP encode lzo,
  date_key         VARCHAR(10) encode lzo sortkey,
  ship_mode        VARCHAR(10) encode bytedict,
  line_id          INTEGER encode delta32k,
  line_number      INTEGER encode lzo,
  quantity         INTEGER encode delta32k,
  product_id       INTEGER encode bytedict distkey,
  unit_price       DECIMAL(10,2) encode bytedict,
  discount         DECIMAL(10,2) encode bytedict,
  supply_cost      DECIMAL(10,2) encode bytedict,
  tax              DECIMAL(10,2) encode bytedict,
  extended_price   DECIMAL(10,2) encode lzo,
  profit           DECIMAL(10,2) encode lzo
);

DROP TABLE IF EXISTS date_dim;

CREATE TABLE date_dim
(
  date_key            VARCHAR(10) NOT NULL primary key sortkey,
  year                INTEGER NOT NULL,
  month               INTEGER NOT NULL,
  day                 INTEGER NOT NULL,
  monthname           VARCHAR(16) NOT NULL,
  weekday             VARCHAR(16) NOT NULL,
  dayofyear           INTEGER NOT NULL,
  weeknumber          INTEGER NOT NULL,
  dayofweek           INTEGER NOT NULL
  
)
diststyle ALL;


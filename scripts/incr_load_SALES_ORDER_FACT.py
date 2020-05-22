## Glue boilerplate code

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import boto3, json
from awsglue.context import GlueContext, DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
print (args['JOB_NAME']+" START...")
if 'sc' not in vars(): sc = SparkContext()
glueContext = GlueContext(SparkContext.getOrCreate())
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

## Glue boilerplate code

db_name='mysql_dms_salesdb'

tbl_name='incr_sales_order'
datasource0 = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = tbl_name, transformation_ctx = "datasource0")
print ("Rows read from table: %s : %s"%(tbl_name,str(datasource0.count())))
datasource0.printSchema()

tbl_name='incr_sales_order_detail'
datasource1 = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = tbl_name, transformation_ctx = "datasource1")
print ("Rows read from table: %s : %s"%(tbl_name,str(datasource1.count())))
datasource1.printSchema()

datasource2=datasource0.join( ["ORDER_ID"],["ORDER_ID"], datasource1, transformation_ctx = "join")
print (" Rows after Join transform: "+str(datasource2.count()))
datasource2.printSchema()

datasource2.toDF().createOrReplaceTempView("tbl0")
df1 = spark.sql("Select a.*, bround(a.QUANTITY*a.UNIT_PRICE,2) as EXTENDED_PRICE, \
bround(QUANTITY*(UNIT_PRICE-SUPPLY_COST) ,2) as PROFIT, \
DATE_FORMAT(ORDER_DATE,'yyyyMMdd') as DATE_KEY \
from (Select * from tbl0) a")
df1.show(5)
datasource3=DynamicFrame.fromDF(df1, glueContext,'datasource3')

applymapping_dynf = ApplyMapping.apply(frame = datasource3, mappings = [("DISCOUNT", "decimal(10,2)", "discount", "decimal(10,2)"), ("UNIT_PRICE", "decimal(10,2)", "unit_price", "decimal(10,2)"), ("TAX", "decimal(10,2)", "tax", "decimal(10,2)"), ("SUPPLY_COST", "decimal(10,2)", "supply_cost", "decimal(10,2)"), ("PRODUCT_ID", "int", "product_id", "int"), ("QUANTITY", "int", "quantity", "int"), ("LINE_ID", "int", "line_id", "int"), ("LINE_NUMBER", "int", "line_number", "int"), ("ORDER_DATE", "date", "order_date", "date"), ("SHIP_MODE", "string", "ship_mode", "string"), ("SITE_ID", "double", "site_id", "int"), ("PROFIT", "decimal(10,2)", "profit", "decimal(10,2)"),("EXTENDED_PRICE", "decimal(10,2)", "extended_price", "decimal(10,2)"),("DATE_KEY", "string", "date_key", "string"),("ORDER_ID", "int", "order_id", "int")], transformation_ctx = "applymapping1")
applymapping_dynf.toDF().show(5)

datasink3 = glueContext.write_dynamic_frame.from_catalog(frame = applymapping_dynf, database = "redshift_sales_analytics", table_name = "sales_analytics_dw_public_sales_order_fact", redshift_tmp_dir = args["TempDir"], transformation_ctx = "datasink3")
datasink3.toDF().show(5)
print ("Rows inserted into Amazon Redshift table: sales_analytics_dw_public_sales_order_fact : "+str(datasink3.count()))

job.commit()
print (args['JOB_NAME']+" END...")

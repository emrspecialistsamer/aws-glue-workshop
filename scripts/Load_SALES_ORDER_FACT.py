##
## Glue Job : TKO_SALES_ORDER_FACT.py
##


## Glue boilerplate code

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import boto3, json

args = getResolvedOptions(sys.argv, ['JOB_NAME','S3_BUCKET'])
print (args['JOB_NAME']+" START...")
if 'sc' not in vars(): sc = SparkContext()
glueContext = GlueContext(SparkContext.getOrCreate())
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

## Glue boilerplate code

s3bucketname=args['S3_BUCKET']
db_name='salesdb'

tables=['sales_order','sales_order_detail']
join_keys=['order_id']
target_prefix='sales_order_fact'

table1=tables[1]
table2=tables[0]
output_dir=f"s3://%s/data/sales_analytics/sales_order_fact/"%s3bucketname
print (output_dir)

# Read the Source Tables
table1_dyf = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = table1)
table2_dyf = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = table2)

table1_dyf.toDF().createOrReplaceTempView(tables[0]+"_v")
table2_dyf.toDF().createOrReplaceTempView(tables[1]+"_v")

# Write the denormalized SALES_ORDER_FACT table
df=spark.sql("SELECT a.*, b.site_id, b.order_date,b.ship_mode \
FROM sales_order_detail_v b, sales_order_v a \
WHERE a.order_id=b.order_id")
df.printSchema()
print(df.count())
df.coalesce(1).write.mode("OVERWRITE").parquet(output_dir)

## Glue boilerplate code
job.commit

##
## Glue Job : TKO_Load_Product_Dim.py
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

table1='product_category'
table2='product'
output_dir=f"s3://%s/data/sales_analytics/supplier_dim/"%s3bucketname
print (output_dir)

# Read the Source Tables
table1_dyf = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = table1)
table2_dyf = glueContext.create_dynamic_frame.from_catalog(database = db_name, table_name = table2)

#Join the Source Tables
product_dim_dyf = Join.apply(table1_dyf,table2_dyf,
                       'category_id', 'category_id').drop_fields(['category_id'])

# Write the denormalized CUSTOMER_DIM table in Parquet
glueContext.write_dynamic_frame.from_options(frame = product_dim_dyf, connection_type = "s3", connection_options = {"path": output_dir}, format = "parquet")


## Glue boilerplate code
job.commit

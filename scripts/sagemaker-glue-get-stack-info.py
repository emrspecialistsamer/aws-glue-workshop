###
### sagemaker-glue-get-stack-info.py
###
import boto3,json, sys

stack={}

# parse arugments
print (sys.argv)
print (f'stack prefix :%s'%sys.argv[1])
stack_prefix=sys.argv[1]

# Get S3 Bucket
s3 = boto3.client('s3')
response = s3.list_buckets()
bucket_name = [k['Name'] for k in response['Buckets'] if stack_prefix in k['Name']][0]
stack['S3Bucket']=bucket_name
print ('S3Bucket : %s'%(bucket_name))

# Get Aurora endpoint info
rds = boto3.client('rds')
response = rds.describe_db_instances()
databases = response['DBInstances']
## Added Filter
database = [k for k in databases if k['DBInstanceIdentifier'].startswith(stack_prefix)][0]['Endpoint']
stack['AuroraEndPoint'] = database
print ('AuroraEndPoint : %s'%(database))

# Get Redshift endpoint info
redshift = boto3.client('redshift')
response = redshift.describe_clusters()
databases = response['Clusters']
database = [k for k in databases if k['ClusterIdentifier'].startswith(stack_prefix)][0]['Endpoint']
stack['RedshiftEndPoint'] = database
print ('RedshiftEndPoint : %s'%(database))

print (json.dumps(stack))
with open('stack-info.json', 'w') as f:
    json.dump(stack, f)

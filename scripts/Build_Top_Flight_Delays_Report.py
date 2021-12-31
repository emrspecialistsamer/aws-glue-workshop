##
##Build_Top_Flight_Delays_Report.py
##
import boto3,time, sys

defaultdb="default"

def get_argument_value(p):
    return sys.argv[sys.argv.index(p)+1]

bucket=get_argument_value("--S3_BUCKET")

default_output=f's3://{bucket}/athena-sql/data/output/'
default_write_location=f's3://{bucket}/athena-sql/data/'
default_script_location= f's3://{bucket}/scripts/'
default_script_logs_location = f's3://{bucket}/athena-sql/logs/'
sql_script_file='athena-sql-script.sql'

def executeQuery(query, database=defaultdb, s3_output=default_output, poll=10):
    log_output ("Executing Query : \n")
    start = time.time()
    log_output (query+"\n")
    athena = boto3.client('athena')
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={
            'Database': database
            },
        ResultConfiguration={
            'OutputLocation': s3_output,
            }
        )

    log_output('Execution ID: ' + response['QueryExecutionId'])
    queryExecutionId=response['QueryExecutionId']
    state='QUEUED'
    while( state=='RUNNING' or state=='QUEUED'):
        response = athena.get_query_execution(QueryExecutionId=queryExecutionId)
        state=response['QueryExecution']['Status']['State']
        log_output (state)
        if  state=='RUNNING' or state=='QUEUED':
            time.sleep(poll)
        elif (state=='FAILED'):
             log_output (response['QueryExecution']['Status']['StateChangeReason'])

    done = time.time()
    log_output ("Elapsed Time (in seconds) : %f \n"%(done - start))
    return response

def log_output(s):
    log_output_string.append(s)

def read_from_athena(sql):
    response=executeQuery(sql)
    return pd.read_csv(response['QueryExecution']['ResultConfiguration']['OutputLocation'])

s3_location= default_script_location+sql_script_file
bucket_name,script_location=s3_location.split('/',2)[2].split('/',1)
print (bucket_name)
print (script_location)

s3 = boto3.client('s3')

fileobj = s3.get_object(Bucket=bucket_name,Key=script_location)
contents = fileobj['Body'].read().decode('utf-8')

log_output_string=[]
for sql in str(contents).split(";")[:-1]:
    response=executeQuery(sql)

print ("\n".join(log_output_string))

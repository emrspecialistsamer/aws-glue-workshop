##
## glue-sagemaker-lifecycle.sh
##
#!/bin/bash
set -ex
stackPrefix=$1
shift
if ! [ -e /home/ec2-user/glue_ready ]; then

    mkdir -p /home/ec2-user/glue
    cd /home/ec2-user/glue

    #GLUE_ENDPOINT and ASSETS must be set by the consumer of this script
    REGION=$(aws configure get region)

    # Write dev endpoint in a file which will be used by daemon scripts
    glue_endpoint_file="/home/ec2-user/glue/glue_endpoint.txt"

    if [ -f $glue_endpoint_file ] ; then
        rm $glue_endpoint_file
    fi
    echo "https://glue.$REGION.amazonaws.com" >> $glue_endpoint_file

    ASSETS=s3://aws-glue-jes-prod-$REGION-assets/sagemaker/assets/

    aws s3 cp ${ASSETS} . --recursive

    bash "/home/ec2-user/glue/Miniconda2-4.5.12-Linux-x86_64.sh" -b -u -p "/home/ec2-user/glue/miniconda"

    source "/home/ec2-user/glue/miniconda/bin/activate"

    tar -xf autossh-1.4e.tgz
    cd autossh-1.4e
    ./configure
    make
    sudo make install
    sudo cp /home/ec2-user/glue/autossh.conf /etc/init/

    mkdir -p /home/ec2-user/.sparkmagic
    cp /home/ec2-user/glue/config.json /home/ec2-user/.sparkmagic/config.json

    mkdir -p /home/ec2-user/SageMaker/Glue\ Examples
    mv /home/ec2-user/glue/notebook-samples/* /home/ec2-user/SageMaker/Glue\ Examples/

    # Run daemons as cron jobs and use flock make sure that daemons are started only iff stopped
    (crontab -l; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-v2-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-v2-dev-endpoint-daemon.sh") | crontab -

    (crontab -l; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-reconnect-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-reconnect-dev-endpoint-daemon.sh") | crontab -

    source "/home/ec2-user/glue/miniconda/bin/deactivate"

    rm -rf "/home/ec2-user/glue/Miniconda2-4.5.12-Linux-x86_64.sh"

    sudo touch /home/ec2-user/glue_ready
fi

# Download and save stack-info python script
aws s3 cp s3://emr-workshops-us-west-2/glue_immersion_day/scripts/sagemaker-glue-get-stack-info.py /home/ec2-user/scripts/
chmod +x /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py
python /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py $stackPrefix

# Copy sample notebooks
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/notebooks/ /home/ec2-user/SageMaker

s3_bucket=`cat stack-info.json | jq -r .S3Bucket`
echo "s3_bucket : $s3_bucket"

## Copy the data
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/data/ s3://$s3_bucket/data/

## Copy the scripts
aws s3 cp --recursive s3://emr-workshops-us-west-2/glue_immersion_day/scripts/ s3://$s3_bucket/scripts/

## Install Jupyter extensions
pip install jupyter_contrib_nbextensions
jupyter contrib nbextension install --user
jupyter nbextension enable execute_time/ExecuteTime

## Install mysql package in conda python3 env
source activate python3
sudo yum install -y mysql-devel
sudo yum -y install mysql
pip install mysql
pip install tqdm
pip install psycopg2
source deactivate

# Load the data into Aurora
aws s3 cp s3://emr-workshops-us-west-2/glue_immersion_day/scripts/salesdb.sql /home/ec2-user/scripts/salesdb.sql
aurora_endpoint=`cat stack-info.json | jq -r .AuroraEndPoint.Address`
echo "aurora_endpoint : $aurora_endpoint"
mysql -f -u master -h $aurora_endpoint  --password="S3cretPwd99" < /home/ec2-user/scripts/salesdb.sql

## get Redshift endpoint
redshift_endpoint=`cat stack-info.json | jq -r .RedshiftEndPoint.Address`
echo "redshift_endpoint : $redshift_endpoint"

iam_role=$stackPrefix+'-GlueServiceRole'

## Replace tokens in Notebook
## Module1
sed -i "s/###s3_bucket###/$s3_bucket/" /home/ec2-user/SageMaker/Module1/1_Building_a_DataLake_using_AWS_Glue.ipynb
sed -i "s/###iam_role###/$iam_role/" /home/ec2-user/SageMaker/Module1/1_Building_a_DataLake_using_AWS_Glue.ipynb

## Module2
sed -i "s/###mysql_host###/$aurora_endpoint/" /home/ec2-user/SageMaker/Module2/1_Verify_Source_and_Target_Databases_and_the_Ingestion_Pipeline.ipynb
sed -i "s/###redshift_host###/$redshift_endpoint/" /home/ec2-user/SageMaker/Module2/1_Verify_Source_and_Target_Databases_and_the_Ingestion_Pipeline.ipynb
sed -i "s/###redshift_host###/$redshift_endpoint/" /home/ec2-user/SageMaker/Module2/redshift_utils.py
sed -i "s/###s3_bucket###/$s3_bucket/" /home/ec2-user/SageMaker/Module2/2_Execute_Incremental_Processing_Job_with_AWS_Glue.ipynb
sed -i "s/###iam_role###/$iam_role/" /home/ec2-user/SageMaker/Module2/2_Execute_Incremental_Processing_Job_with_AWS_Glue.ipynb

## Module3
sed -i "s/###s3_bucket###/$s3_bucket/" /home/ec2-user/SageMaker/Module3/1_Using_AWS_Glue_Python_Shell_Jobs.ipynb
sed -i "s/###iam_role###/$iam_role/" /home/ec2-user/SageMaker/Module3/1_Using_AWS_Glue_Python_Shell_Jobs.ipynb

## Rename the Modules
mv /home/ec2-user/SageMaker/Module1 /home/ec2-user/SageMaker/"Module 1 : Building a DataLake using AWS Glue"
mv /home/ec2-user/SageMaker/Module2 /home/ec2-user/SageMaker/"Module 2 : Incremental data processing from OLTP Database to DataWarehouse"
mv /home/ec2-user/SageMaker/Module3 /home/ec2-user/SageMaker/"Module 3 : Using AWS Glue Python Shell Jobs"

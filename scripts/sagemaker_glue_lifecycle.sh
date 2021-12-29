##
## glue-sagemaker-lifecycle.sh
##
#!/bin/bash
set -ex

# cloud formation stack prefix is used as a unique resource id
stackPrefix=$1

# s3 source path (notebooks and scripts)
source_s3_path="$2"
shift 2

# s3 data path
data_s3_path='s3://emr-workshops-us-west-2/glue_immersion_day'

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

    echo "ensure SageMaker notebook has permission to access regional endpoint"
    aws glue get-dev-endpoint --endpoint-name ${stackPrefix}-Glue-Dev-Endpoint --region ${REGION}

    set +e
    echo "Run daemons as cron jobs and use flock to make sure that daemons are started only if stopped"
    (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-v2-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-v2-dev-endpoint-daemon.sh") | crontab -
    (crontab -l 2>/dev/null; echo "* * * * * /usr/bin/flock -n /tmp/lifecycle-config-reconnect-dev-endpoint-daemon.lock /usr/bin/sudo /bin/sh /home/ec2-user/glue/lifecycle-config-reconnect-dev-endpoint-daemon.sh") | crontab -
    crontab -l

    echo "Wait for Glue dev endpoint connection to be reachable ..."
    LIVY_SERVER="http://localhost:8998"
    timeout=$((5*60))
    while (true); do
        echo "Connecting to Glue Dev Endpoint: $LIVY_SERVER"
        curl -s $LIVY_SERVER
        if [ $? -eq 0 ]; then 
            echo "$LIVY_SERVER is reachable"
            break; 
        fi
        sleep 20
        ((timeout -= 20))
        if [[ $timeout -lt 0 ]]; then
            echo "WARNING: $LIVY_SERVER is unreachable"
            break;
        fi
    done
    set -e

    source "/home/ec2-user/glue/miniconda/bin/deactivate"

    rm -rf "/home/ec2-user/glue/Miniconda2-4.5.12-Linux-x86_64.sh"

    sudo touch /home/ec2-user/glue_ready
fi

# Download and save stack-info python script
aws s3 cp ${source_s3_path}/scripts/sagemaker-glue-get-stack-info.py /home/ec2-user/scripts/
chmod +x /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py
python /home/ec2-user/scripts/sagemaker-glue-get-stack-info.py ${stackPrefix}

# Copy sample notebooks
aws s3 cp --recursive ${source_s3_path}/notebooks/ /home/ec2-user/SageMaker

# Data bucket
s3_bucket=`cat stack-info.json | jq -r .S3Bucket`
echo "s3_bucket : $s3_bucket"

## Copy the data

aws s3 cp --recursive ${data_s3_path}/data/ s3://$s3_bucket/data/

## Copy the scripts
aws s3 cp --recursive ${source_s3_path}/scripts/ s3://$s3_bucket/scripts/

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
aws s3 cp ${data_s3_path}/scripts/salesdb.sql /home/ec2-user/scripts/salesdb.sql
aurora_endpoint=`cat stack-info.json | jq -r .AuroraEndPoint.Address`
echo "aurora_endpoint : $aurora_endpoint"
mysql -f -u master -h $aurora_endpoint  --password="S3cretPwd99" < /home/ec2-user/scripts/salesdb.sql

## get Redshift endpoint
redshift_endpoint=`cat stack-info.json | jq -r .RedshiftEndPoint.Address`
echo "redshift_endpoint : $redshift_endpoint"

iam_role="${stackPrefix}-GlueServiceRole"

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
mod1='Module 1 : Building a DataLake using AWS Glue'
mod2='Module 2 : Incremental data processing from OLTP Database to DataWarehouse'
mod3='Module 3 : Using AWS Glue Python Shell Jobs'
cd /home/ec2-user/SageMaker
rm -rf "$mod1" "$mod2" "$mod3"
mv /home/ec2-user/SageMaker/Module1 "$mod1"
mv /home/ec2-user/SageMaker/Module2 "$mod2"
mv /home/ec2-user/SageMaker/Module3 "$mod3"



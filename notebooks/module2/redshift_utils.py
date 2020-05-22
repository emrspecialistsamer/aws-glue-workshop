import psycopg2

rs_host='###redshift_host###'
rs_dbname='sales_analytics_dw'
rs_user = 'awsuser'
rs_password = 'S3cretPwd99'
rs_port = 5439

def execute_redshift_query(sql):
    con=psycopg2.connect(dbname=rs_dbname, host=rs_host, port=rs_port, user=rs_user, password=rs_password)
    cursor = con.cursor()
    cursor.execute(sql)
    rows = cursor.fetchall()
    result=[]
    for row in rows:
        result.append(row)
    cursor.close()
    con.close()
    return result

#execute_redshift_query("Select count(*) from sales_order_fact")

import json, os
from moto import mock_aws
import boto3
os.environ['TABLE_NAME'] = 'test-user-access'
os.environ['ROLE_TEMPLATE'] = '{userid}-role'
@mock_aws
def test_detach_flow_pytest():
    ddb = boto3.client('dynamodb', region_name='us-east-2')
    ddb.create_table(
        TableName='test-user-access',
        KeySchema=[{'AttributeName':'userid','KeyType':'HASH'}],
        AttributeDefinitions=[{'AttributeName':'userid','AttributeType':'S'}],
        BillingMode='PAY_PER_REQUEST',
    )
    boto3.resource('dynamodb', region_name='us-east-2').Table('test-user-access').put_item(Item={
        'userid':'u1',
        'required_policies':['arn:aws:iam::123:policy/test-policy1'],
        'role_name':'test-userid1-role'
    })
    iam = boto3.client('iam', region_name='us-east-2')
    iam.create_role(RoleName='test-userid1-role',
                    AssumeRolePolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}))
    p1 = iam.create_policy(PolicyName='test-policy1', PolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListAllMyBuckets"],"Resource":"*"}]}))
    p2 = iam.create_policy(PolicyName='test-policy2', PolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListBucket"],"Resource":"*"}]}))
    iam.attach_role_policy(RoleName='test-userid1-role', PolicyArn=p1['Policy']['Arn'])
    iam.attach_role_policy(RoleName='test-userid1-role', PolicyArn=p2['Policy']['Arn'])
    from lambda.main import lambda_handler
    resp = lambda_handler({"queryStringParameters":{"userid":"u1","dry_run":"false"}}, None)
    body = json.loads(resp['body'])
    assert resp['statusCode'] == 200
    assert p2['Policy']['Arn'] in body['detached_now']
    assert p1['Policy']['Arn'] in body['kept']

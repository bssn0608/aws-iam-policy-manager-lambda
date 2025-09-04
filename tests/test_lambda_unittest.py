import unittest, os
from moto import mock_aws
import boto3
class TestLambdaUnittest(unittest.TestCase):
    @mock_aws
    def test_missing_user(self):
        os.environ['TABLE_NAME'] = 'test-user-access'
        ddb = boto3.client('dynamodb', region_name='us-east-2')
        ddb.create_table(
            TableName='test-user-access',
            KeySchema=[{'AttributeName':'userid','KeyType':'HASH'}],
            AttributeDefinitions=[{'AttributeName':'userid','AttributeType':'S'}],
            BillingMode='PAY_PER_REQUEST',
        )
        from lambda.main import lambda_handler
        resp = lambda_handler({"queryStringParameters":{"userid":"nope"}}, None)
        self.assertEqual(resp['statusCode'], 404)
if __name__ == '__main__':
    unittest.main()

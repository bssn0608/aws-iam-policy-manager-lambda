from moto import mock_aws
import boto3

def test_moto_smoke():
    with mock_aws():
        boto3.client("iam", region_name="us-east-2")
        boto3.client("dynamodb", region_name="us-east-2")
        assert True

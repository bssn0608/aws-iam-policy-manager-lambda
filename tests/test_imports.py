import importlib
def test_can_import_lambda_handler():
    mod = importlib.import_module("lambda_func.main")
    assert hasattr(mod, "lambda_handler")
    assert callable(mod.lambda_handler)

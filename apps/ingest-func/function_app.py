import azure.functions as func
app = func.FunctionApp()

@app.route(route='health', auth_level=func.AuthLevel.ANONYMOUS)
def health(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse('ok')

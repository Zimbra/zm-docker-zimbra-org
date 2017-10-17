#! /usr/bin/python

from subprocess import check_output, CalledProcessError
from flask import Flask
from flask_api import status

app = Flask(__name__)

@app.route("/")
def healthcheck():
    try:
        output = check_output(["su", "-c", "/opt/zimbra/bin/zmcontrol status", "zimbra"])
        return output, status.HTTP_200_OK, {'Content-Type': 'text/plain; charset=utf-8'}
    except CalledProcessError as e:
        return e.output, status.HTTP_500_INTERNAL_SERVER_ERROR, {'Content-Type': 'text/plain; charset=utf-8'}

if __name__ == "__main__":
    app.run(host= '0.0.0.0')

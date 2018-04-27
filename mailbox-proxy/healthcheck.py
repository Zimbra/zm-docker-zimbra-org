#! /usr/bin/python

from subprocess import check_output, CalledProcessError
from flask import Flask
from flask_api import status
import os

app = Flask(__name__)

@app.route("/")
def healthcheck():
    if os.path.exists('/var/tmp/haproxy.pid'):
        pid = open("/var/tmp/haproxy.pid").read()
        return pid, status.HTTP_200_OK, {'Content-Type': 'text/plain; charset=utf-8'}
    else:
        return 'HAProxy is NOT running', status.HTTP_500_INTERNAL_SERVER_ERROR, {'Content-Type': 'text/plain; charset=utf-8'}

if __name__ == "__main__":
    app.run(host= '0.0.0.0')

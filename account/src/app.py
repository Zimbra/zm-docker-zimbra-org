from __future__ import with_statement
from flask import Flask, request, send_from_directory, redirect
from flask_cors import CORS
from fabric.api import *
from fabric.contrib.console import confirm

app = Flask(__name__)
CORS(app)

@app.route("/", methods=["GET"])
def index():
    return send_from_directory("static", "index.html")

@app.route("/success", methods=["GET"])
def success():
    return send_from_directory("static", "success.html")

@app.route("/register", methods=["POST"])
def register():
    firstName = request.form["firstName"]
    lastName = request.form["lastName"]
    displayName = " ".join([ name for name in [ firstName, lastName ] if name is not None ])

    userName = request.form["userName"]
    email = userName.replace("@bc.lonni.me", "") + "@bc.lonni.me"

    password = "abc123"

    recoveryEmail = request.form["recoveryEmail"]

    createUserCommand = 'zmprov ca {} {} displayName "{}"'.format(email, password, displayName)
    print ('zmprov ca {} {} displayName "{}"'.format(email, password, displayName))

    # run the command remotly through ssh via a fabric's high -level library
    with settings(host_string="zmc-mailbox", port=23 ,user="zimbra", password="zimbra", warn_only=True):
        result = run(createUserCommand)

    if result.failed:
        return "", 500
    else:
        return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
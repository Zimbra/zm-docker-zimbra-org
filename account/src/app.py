from __future__ import with_statement
from flask import Flask, request, jsonify
from fabric.api import *
from fabric.contrib.console import confirm

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    accountInfo = request.get_json(force=True)
    user = accountInfo['user']
    password = accountInfo['password']
    email = accountInfo['email']

    if user:
        createUserCommand = "zmprov ca {} {} displayName {}".format(email, password, user)
    else:
        createUserCommand = "zmprov ca {} {}".format(email, password)

    # run the command remotly through ssh via a fabric's high -level library
    with settings(host_string="zmc-mailbox", port=23 ,user="zimbra", password="zimbra", warn_only=True):
        result = run(createUserCommand)
    
    if result.failed:
        return "Something was wrong :( " + result
    else:
        return "Your account was created successfuly " + result


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)
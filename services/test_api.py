"""
services.test_api
~~~~~~~~~~~~~~~~~

This module defines a simple REST API to be used for testing Docker
and Kubernetes.
"""

import socket

from flask import Flask, jsonify, make_response, request

app = Flask(__name__)


@app.route('/test_api', methods=['GET'])
def service_health_check():
    """Service health-check endpoint.
    Returns a simple message string to confirm that the service is
    operational.

    :return: A message.
    :rtype: str
    """
    remote_ip_addr = request.remote_addr
    local_ip_addr = socket.gethostbyname(socket.gethostname())
    message = f'Hello {remote_ip_addr}, you\'ve reached {local_ip_addr}'
    return make_response(jsonify({'message': message}))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

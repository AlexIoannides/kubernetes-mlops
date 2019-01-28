"""
api.py
~~~~~~

This module defines a simple REST API for an imaginary Machine Learning
(ML) model. It will be used for testing Docker and Kubernetes.
"""

from flask import abort, Flask, jsonify, make_response, request

app = Flask(__name__)


@app.route('/score', methods=['POST'])
def score():
    """Score data using an imaginary machine learning model.

    This API expects a JSON payload that includes the following fields:
        X - an array of input features,

    And will return a JSON payload with the following fields:
        score - an array of predicionts.
    """
    try:
        features = request.json['X']
        return make_response(jsonify({'score': features}))
    except KeyError:
        raise RuntimeError('"X" cannot be be found in JSON payload.')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

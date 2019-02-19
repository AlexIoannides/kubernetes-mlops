"""
api.py
~~~~~~

This module defines a simple REST API for an imaginary Machine Learning
(ML) model. It will be used for testing Docker and Kubernetes.

This can be tested locally on the command line, using `python api.py`
to start the service and then in another terminal window using,

```
curl http://localhost:5000/score \
--request POST \
--header "Content-Type: application/json" \
--data '{"X": [1, 2]}'
```

To test the API.
"""

from typing import Iterable

from flask import Flask, jsonify, make_response, request, Response

app = Flask(__name__)


@app.route('/score', methods=['POST'])
def score() -> Response:
    """Score data using an imaginary machine learning model.

    This API endpoint expects a JSON payload with a field called `X`
    containing an iterable sequence of features to send to the model.
    This data is parsed into Python dict and made available via
    `request.json`

    If `X` cannot be found in the parsed JSON data, then an exception
    will be raised. Otherwise, it will return a JSON payload with the
    `score` field containing the model's prediction.
    """

    try:
        features = request.json['X']
        prediction = model_predict(features)
        return make_response(jsonify({'score': prediction}))
    except KeyError:
        raise RuntimeError('"X" cannot be be found in JSON payload.')


def model_predict(x: Iterable[float]) -> Iterable[float]:
    """Dummy prediction function."""
    return x


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

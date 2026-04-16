import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

class KalmanFilter2D {
  late Float64List _state;
  late Float64List _P;

  final double processNoise;
  final double measurementNoise;

  KalmanFilter2D({this.processNoise = 0.1, this.measurementNoise = 1.0}) {
    _state = Float64List(4);
    _P = Float64List(16);
    _initialize();
  }

  void _initialize() {
    for (int i = 0; i < 4; i++) {
      _P[i * 4 + i] = 500.0;
    }
  }

  void predict(double dt) {
    double x = _state[0];
    double y = _state[1];
    double vx = _state[2];
    double vy = _state[3];

    _state[0] = x + vx * dt;
    _state[1] = y + vy * dt;

    double dt2 = dt * dt;
    _P[0] += processNoise * dt2;
    _P[5] += processNoise * dt2;
    _P[10] += processNoise * dt;
    _P[15] += processNoise * dt;
  }

  void update(double measurementX, double measurementY) {
    double Sx = _P[0] + measurementNoise;
    double Sy = _P[5] + measurementNoise;

    double Kx = _P[0] / Sx;
    double Ky = _P[5] / Sy;

    double innovationX = measurementX - _state[0];
    double innovationY = measurementY - _state[1];

    _state[0] += Kx * innovationX;
    _state[1] += Ky * innovationY;
    _state[2] += Kx * innovationX / 0.033;
    _state[3] += Ky * innovationY / 0.033;

    _P[0] *= (1 - Kx);
    _P[5] *= (1 - Ky);
    _P[10] *= (1 - Kx);
    _P[15] *= (1 - Ky);
  }

  Offset getPosition() => Offset(_state[0], _state[1]);
  Offset getVelocity() => Offset(_state[2], _state[3]);

  void setPosition(Offset pos) {
    _state[0] = pos.dx;
    _state[1] = pos.dy;
  }

  double getUncertainty() {
    return math.sqrt(_P[0] + _P[5]);
  }

  void reset() {
    _state.fillRange(0, 4, 0.0);
    _P.fillRange(0, 16, 0.0);
    _initialize();
  }

  void resetWithState(double x, double y, double vx, double vy) {
    _state[0] = x;
    _state[1] = y;
    _state[2] = vx;
    _state[3] = vy;
    _initialize();
  }
}

class KalmanFilterAngle {
  double _angle = 0.0;
  double _angularVelocity = 0.0;
  double _Pangle = 500.0;
  double _Pvelocity = 500.0;

  final double processNoise;
  final double measurementNoise;

  KalmanFilterAngle({this.processNoise = 0.05, this.measurementNoise = 3.0});

  void predict(double dt) {
    _angle += _angularVelocity * dt;
    if (_angle < 0) _angle += 360;
    if (_angle >= 360) _angle -= 360;

    _Pangle += processNoise * dt * dt;
    _Pvelocity += processNoise * dt;
  }

  void update(double measurement) {
    double S = _Pangle + measurementNoise;
    double K = _Pangle / S;

    double innovation = measurement - _angle;
    if (innovation > 180) innovation -= 360;
    if (innovation < -180) innovation += 360;

    _angle += K * innovation;
    _angularVelocity += K * innovation / 0.033;

    if (_angle < 0) _angle += 360;
    if (_angle >= 360) _angle -= 360;

    _Pangle *= (1 - K);
  }

  double getAngle() => _angle;
  double getAngularVelocity() => _angularVelocity;

  void reset(double initialAngle) {
    _angle = initialAngle;
    _angularVelocity = 0.0;
    _Pangle = 500.0;
    _Pvelocity = 500.0;
  }
}
